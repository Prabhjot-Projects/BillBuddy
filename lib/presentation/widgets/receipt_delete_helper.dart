import 'package:billbuddy/app/di/service_locator.dart';
import 'package:billbuddy/data/entities/receipt.dart';
import 'package:billbuddy/processes/receipt/receipt_repository.dart';
import 'package:billbuddy/processes/receipt/receipt_event_repository.dart';
import 'package:billbuddy/data/entities/receipt_event.dart';
import 'package:billbuddy/services/storage/local/image_storage_service.dart';
import 'package:billbuddy/processes/receipt/receipt_image_repository.dart';
import 'package:billbuddy/services/currency/currency_controller.dart';
import 'package:flutter/material.dart';

/// Shared delete flow for receipt list screens (Pending and Recent).
/// Extracted rather than duplicated because both screens need the exact
/// same three steps in the exact same order: confirm with the user,
/// delete the DB row, then clean up the saved image file. Keeping this
/// in one place means a future change to any of those three steps (e.g.
/// a different confirmation message, or adding an "undo" snackbar) only
/// needs to happen once.
///
/// Returns true if the receipt was deleted, false if the user cancelled
/// or deletion failed — callers use this to decide whether to refresh
/// their list.
Future<bool> confirmAndDeleteReceipt(
  BuildContext context,
  Receipt receipt,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete receipt?'),
      content: Text(
        'This will permanently delete the receipt from '
        '${receipt.merchantName ?? "this merchant"}. This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed != true) return false;

  final repository = getIt<ReceiptRepository>();
  final imageRepository = getIt<ReceiptImageRepository>();
  final pagePaths =
      (await imageRepository.getPages(receipt.id)).valueOrNull ??
      const <String>[];
  final result = await repository.delete(receipt.id);

  if (!context.mounted) return false;

  return result.fold(
    onSuccess: (_) {
      // Image cleanup happens after the DB delete succeeds, not before —
      // if the DB delete failed, we want the image to still exist so
      // the receipt (which is still in the database) isn't left
      // pointing at a missing file. Deleting the DB row first and the
      // file second means the only possible inconsistency is a leaked
      // orphan file (recoverable, harmless) rather than a receipt
      // record with a broken image reference (visibly broken to the
      // user, worse).
      final imagePath = receipt.imagePath;
      if (imagePath != null) {
        getIt<ImageStorageService>().deleteReceiptImage(imagePath);
        // Not awaited/checked further: a failed image cleanup here is a
        // minor disk-space leak, not something worth blocking or
        // erroring the user's delete action over.
      }
      for (final path in pagePaths) {
        if (path != imagePath) {
          getIt<ImageStorageService>().deleteReceiptImage(path);
        }
      }
      getIt<ReceiptEventRepository>().add(
        ReceiptEvent(
          receiptId: receipt.id,
          eventType: 'deleted',
          summary:
              'Deleted ${receipt.merchantName ?? 'receipt'} · '
              '${getIt<CurrencyController>().format(receipt.total, fallback: 'amount unavailable')}',
          createdAt: DateTime.now(),
        ),
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Receipt deleted.')));
      return true;
    },
    onFailure: (failure) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      return false;
    },
  );
}
