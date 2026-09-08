import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/data/entities/receipt_event.dart';
import 'package:billbuddy/processes/receipt/receipt_repository.dart';
import 'package:billbuddy/processes/receipt/receipt_event_repository.dart';
import 'package:billbuddy/presentation/widgets/receipt_image_view.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'item_assignment_screen.dart';

/// Lets the user correct OCR/AI mistakes before a draft receipt is
/// confirmed. This is the one place in the app where the parsed data
/// actually gets human review — everything before this screen is
/// automated and can be wrong.
///
/// Validation rule (explicit product decision, not a default): a
/// confirmed receipt must be fully specified. Merchant, date, subtotal,
/// tax, and total are all required, and every item needs a name and a
/// price. Quantity is the one exception — it defaults to 1 when left
/// blank, since "one of this item" is a safe, common assumption that
/// doesn't need the user to type it every time. Nothing else gets a
/// silent default: a missing price or a missing total is a real gap
/// the user needs to notice and fix, not something the app should paper
/// over, since it directly feeds the split-calculation logic later.
class ReviewScreen extends StatefulWidget {
  final Receipt receipt;

  const ReviewScreen({super.key, required this.receipt});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

/// One row's worth of controllers for an editable item.
class _EditableItemRow {
  final String id;
  final TextEditingController nameController;
  final TextEditingController quantityController;
  final TextEditingController priceController;

  _EditableItemRow({
    required this.id,
    required String name,
    required double? quantity,
    required double? price,
  }) : nameController = TextEditingController(text: name),
       quantityController = TextEditingController(
         text: quantity?.toString() ?? '',
       ),
       priceController = TextEditingController(text: price?.toString() ?? '');

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    priceController.dispose();
  }
}

class _ReviewScreenState extends State<ReviewScreen> {
  static const _uuid = Uuid();

  late final ReceiptRepository _repository;
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _merchantController;
  late final TextEditingController _subtotalController;
  late final TextEditingController _taxController;
  late final TextEditingController _totalController;
  DateTime? _date;

  // Only show the date's "Required" error after a real save attempt —
  // matches how TextFormField validators only paint errors once
  // Form.validate() runs, rather than accusing the user of an error
  // the moment the screen opens.
  bool _dateTouched = false;

  final List<_EditableItemRow> _itemRows = [];

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repository = getIt<ReceiptRepository>();

    final receipt = widget.receipt;
    _merchantController = TextEditingController(
      text: receipt.merchantName ?? '',
    );
    _subtotalController = TextEditingController(
      text: receipt.subtotal?.toString() ?? '',
    );
    _taxController = TextEditingController(text: receipt.tax?.toString() ?? '');
    _totalController = TextEditingController(
      text: receipt.total?.toString() ?? '',
    );
    _date = receipt.date;

    for (final item in receipt.items) {
      final row = _EditableItemRow(
        id: item.id,
        name: item.name,
        quantity: item.quantity,
        price: item.price,
      );
      _attachRecalcListeners(row);
      _itemRows.add(row);
    }

    // Tax changes affect Total even when no item changed, so it needs
    // its own listener into the same recalculation.
    _taxController.addListener(_recalculateTotals);

    // A receipt must have at least one item row to be savable — start
    // the user with one empty row if the AI somehow produced zero.
    if (_itemRows.isEmpty) {
      _addItemRow();
    }
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _subtotalController.dispose();
    _taxController.removeListener(_recalculateTotals);
    _taxController.dispose();
    _totalController.dispose();
    for (final row in _itemRows) {
      row.quantityController.removeListener(_recalculateTotals);
      row.priceController.removeListener(_recalculateTotals);
      row.dispose();
    }
    super.dispose();
  }

  void _addItemRow() {
    setState(() {
      final row = _EditableItemRow(
        id: _uuid.v4(),
        name: '',
        quantity: null,
        price: null,
      );
      _attachRecalcListeners(row);
      _itemRows.add(row);
    });
    _recalculateTotals();
  }

  /// Wires a row's quantity/price fields so any edit triggers a
  /// recalculation of Subtotal and Total. Attached once per row (at
  /// creation) rather than rebuilt on every keystroke.
  void _attachRecalcListeners(_EditableItemRow row) {
    row.quantityController.addListener(_recalculateTotals);
    row.priceController.addListener(_recalculateTotals);
  }

  /// Recomputes Subtotal as the sum of (price × quantity) across all
  /// items, and Total as Subtotal + Tax. Both fields remain regular
  /// editable TextFormFields — this only sets an initial computed value;
  /// the user can still type over it manually afterward (e.g. to account
  /// for a discount or rounding the receipt shows but items don't add
  /// up to exactly). Items with no valid price yet are simply skipped
  /// rather than blocking the calculation — partial totals while still
  /// editing are expected and useful feedback, not an error state.
  void _recalculateTotals() {
    double subtotal = 0;
    for (final row in _itemRows) {
      final price = _parseDouble(row.priceController.text);
      if (price == null) continue;
      final quantity = _parseDouble(row.quantityController.text) ?? 1;
      subtotal += price * quantity;
    }

    final tax = _parseDouble(_taxController.text) ?? 0;

    // setState isn't needed here purely for the controller text (the
    // TextFormField already listens to its own controller), but it IS
    // needed to keep the widget tree consistent if anything else in
    // build() ever depends on these values later.
    _subtotalController.text = subtotal.toStringAsFixed(2);
    _totalController.text = (subtotal + tax).toStringAsFixed(2);
  }

  void _removeItemRow(int index) {
    // Removing the last row would leave zero items, which can never be
    // saved — block it here, at the point of the action, instead of
    // letting the user do it and only finding out at save time.
    if (_itemRows.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A receipt needs at least one item.')),
      );
      return;
    }
    setState(() {
      _itemRows[index].quantityController.removeListener(_recalculateTotals);
      _itemRows[index].priceController.removeListener(_recalculateTotals);
      _itemRows[index].dispose();
      _itemRows.removeAt(index);
    });
    _recalculateTotals();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    setState(() {
      _dateTouched = true;
      if (picked != null) _date = picked;
    });
  }

  double? _parseDouble(String text) => double.tryParse(text.trim());

  Future<void> _save({bool continueToAssignment = false}) async {
    setState(() => _dateTouched = true);

    // Form.validate() runs every TextFormField's validator and paints
    // inline errors on whichever fields fail.
    final formValid = _formKey.currentState?.validate() ?? false;
    final dateValid = _date != null;

    if (!formValid || !dateValid) return;

    setState(() => _isSaving = true);

    final items = _itemRows.map((row) {
      final quantity = _parseDouble(row.quantityController.text);
      return ReceiptItem(
        id: row.id,
        receiptId: widget.receipt.id,
        name: row.nameController.text.trim(),
        // The one field allowed to default rather than block save.
        quantity: quantity ?? 1,
        price: _parseDouble(row.priceController.text),
      );
    }).toList();

    final updatedReceipt = widget.receipt.copyWith(
      merchantName: _merchantController.text.trim(),
      date: _date,
      items: items,
      subtotal: _parseDouble(_subtotalController.text),
      tax: _parseDouble(_taxController.text),
      total: _parseDouble(_totalController.text),
    );

    final result = continueToAssignment
        ? await _repository.saveDraft(updatedReceipt)
        : await _repository.confirm(updatedReceipt);

    if (!mounted) return;
    setState(() => _isSaving = false);

    result.fold(
      onSuccess: (_) {
        if (!continueToAssignment) {
          getIt<ReceiptEventRepository>().add(
            ReceiptEvent(
              receiptId: updatedReceipt.id,
              eventType: widget.receipt.status == ReceiptStatus.confirmed
                  ? 'edited'
                  : 'confirmed',
              summary: widget.receipt.status == ReceiptStatus.confirmed
                  ? 'Receipt edited and confirmed'
                  : 'Receipt confirmed',
              createdAt: DateTime.now(),
            ),
          );
        }
        if (continueToAssignment) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ItemAssignmentScreen(receipt: updatedReceipt),
            ),
          );
        } else {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      onFailure: (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
    );
  }

  String? _requiredTextValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    return null;
  }

  String? _requiredMoneyValidator(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required';
    if (double.tryParse(value.trim()) == null) return 'Invalid number';
    return null;
  }

  /// Deliberately lenient on emptiness — blank quantity is valid and
  /// defaults to 1 — but still rejects non-numeric garbage if typed.
  String? _optionalQuantityValidator(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (double.tryParse(value.trim()) == null) return 'Invalid number';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Receipt'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _isSaving ? null : _save,
            tooltip: 'Save',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ReceiptImageView(imagePath: widget.receipt.imagePath),
            const SizedBox(height: 20),
            TextFormField(
              controller: _merchantController,
              decoration: const InputDecoration(labelText: 'Merchant *'),
              validator: _requiredTextValidator,
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Date *',
                  errorText: (_dateTouched && _date == null)
                      ? 'Required'
                      : null,
                ),
                child: Text(
                  _date != null
                      ? '${_date!.year}-${_date!.month.toString().padLeft(2, '0')}-${_date!.day.toString().padLeft(2, '0')}'
                      : 'Tap to select',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _subtotalController,
                    decoration: const InputDecoration(labelText: 'Subtotal *'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _requiredMoneyValidator,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _taxController,
                    decoration: const InputDecoration(labelText: 'Tax *'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _requiredMoneyValidator,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _totalController,
                    decoration: const InputDecoration(labelText: 'Total *'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: _requiredMoneyValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Items',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _addItemRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Add item'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._itemRows.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: row.nameController,
                        decoration: const InputDecoration(
                          labelText: 'Item name *',
                        ),
                        validator: _requiredTextValidator,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: row.quantityController,
                        decoration: const InputDecoration(labelText: 'Qty'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _optionalQuantityValidator,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: row.priceController,
                        decoration: const InputDecoration(labelText: 'Price *'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _requiredMoneyValidator,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeItemRow(index),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isSaving
                  ? null
                  : () => _save(continueToAssignment: true),
              child: const Text('Continue to split'),
            ),
          ],
        ),
      ),
    );
  }
}
