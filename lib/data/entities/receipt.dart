/// Sentinel used by [Receipt.copyWith] and [ReceiptItem.copyWith] to
/// distinguish "caller explicitly wants this field set to null" from
/// "caller didn't pass this argument at all, leave the existing value
/// alone."
const _unset = Object();

/// A parsed receipt, ready for display, editing, and persistence.
///
/// - [groupId]: which Group this receipt's split is scoped to. Null
///   until the user starts item assignment — a receipt can be confirmed
///   and sit in Recent Bills without ever being split, if the user just
///   wanted to log it.
/// - [paidBy]: the participant (a Friend.id, or [meParticipantId]) who
///   fronted the money for this receipt — everyone else's computed
///   share is what they owe this person, not an abstract "the group."
class Receipt {
  final String id;
  final String? merchantName;
  final DateTime? date;
  final List<ReceiptItem> items;
  final double? subtotal;
  final double? tax;
  final double? total;
  final String? imagePath;
  final DateTime createdAt;
  final ReceiptStatus status;
  final String? groupId;
  final String? paidBy;

  Receipt({
    required this.id,
    this.merchantName,
    this.date,
    required this.items,
    this.subtotal,
    this.tax,
    this.total,
    this.imagePath,
    DateTime? createdAt,
    this.status = ReceiptStatus.draft,
    this.groupId,
    this.paidBy,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Whether this receipt has a persisted split configuration.
  ///
  /// Individual splits intentionally have no group id, so the payer is the
  /// shared marker for both group and individual split flows.
  bool get hasSplit => paidBy != null && items.isNotEmpty;

  Receipt copyWith({
    Object? merchantName = _unset,
    Object? date = _unset,
    List<ReceiptItem>? items,
    Object? subtotal = _unset,
    Object? tax = _unset,
    Object? total = _unset,
    Object? imagePath = _unset,
    ReceiptStatus? status,
    Object? groupId = _unset,
    Object? paidBy = _unset,
  }) {
    return Receipt(
      id: id,
      merchantName: identical(merchantName, _unset)
          ? this.merchantName
          : merchantName as String?,
      date: identical(date, _unset) ? this.date : date as DateTime?,
      items: items ?? this.items,
      subtotal: identical(subtotal, _unset)
          ? this.subtotal
          : subtotal as double?,
      tax: identical(tax, _unset) ? this.tax : tax as double?,
      total: identical(total, _unset) ? this.total : total as double?,
      imagePath: identical(imagePath, _unset)
          ? this.imagePath
          : imagePath as String?,
      createdAt: createdAt,
      status: status ?? this.status,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
      paidBy: identical(paidBy, _unset) ? this.paidBy : paidBy as String?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'merchantName': merchantName,
      'date': date?.toIso8601String(),
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'groupId': groupId,
      'paidBy': paidBy,
    };
  }

  factory Receipt.fromMap(
    Map<String, Object?> map, {
    required List<ReceiptItem> items,
  }) {
    return Receipt(
      id: map['id'] as String,
      merchantName: map['merchantName'] as String?,
      date: map['date'] != null
          ? DateTime.tryParse(map['date'] as String)
          : null,
      items: items,
      subtotal: (map['subtotal'] as num?)?.toDouble(),
      tax: (map['tax'] as num?)?.toDouble(),
      total: (map['total'] as num?)?.toDouble(),
      imagePath: map['imagePath'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      status: ReceiptStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => ReceiptStatus.draft,
      ),
      groupId: map['groupId'] as String?,
      paidBy: map['paidBy'] as String?,
    );
  }
}

enum ReceiptStatus { draft, confirmed }

class ReceiptItem {
  final String id;
  final String receiptId;
  final String name;
  final double? quantity;
  final double? price;

  ReceiptItem({
    required this.id,
    required this.receiptId,
    required this.name,
    this.quantity,
    this.price,
  });

  ReceiptItem copyWith({
    String? name,
    Object? quantity = _unset,
    Object? price = _unset,
  }) {
    return ReceiptItem(
      id: id,
      receiptId: receiptId,
      name: name ?? this.name,
      quantity: identical(quantity, _unset)
          ? this.quantity
          : quantity as double?,
      price: identical(price, _unset) ? this.price : price as double?,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'receiptId': receiptId,
      'name': name,
      'quantity': quantity,
      'price': price,
    };
  }

  factory ReceiptItem.fromMap(Map<String, Object?> map) {
    return ReceiptItem(
      id: map['id'] as String,
      receiptId: map['receiptId'] as String,
      name: map['name'] as String,
      quantity: (map['quantity'] as num?)?.toDouble(),
      price: (map['price'] as num?)?.toDouble(),
    );
  }
}
