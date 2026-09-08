import 'dart:typed_data';
import 'package:billbuddy/core/utils/result.dart';

/// Contract for persisting receipt images to device storage.
///
/// Split as an interface because there's a concrete, near-term reason to
/// expect a second implementation: once cloud sync ships, receipt images
/// will also need to live in cloud storage (Firebase Storage), and the
/// app will likely want both — save locally first for instant access,
/// upload in the background. Two real strategies, so the interface earns
/// its place per ARCHITECTURE.md's abstraction rule.
abstract class ImageStorageService {
  /// Saves image bytes under a stable name derived from [receiptId] and
  /// returns the path it was saved to.
  Future<Result<String>> saveReceiptImage({
    required String receiptId,
    required Uint8List imageBytes,
  });

  Future<Result<List<String>>> saveReceiptImages({
    required String receiptId,
    required List<Uint8List> imageBytes,
  });

  /// Deletes a previously saved receipt image, if it exists.
  Future<Result<void>> deleteReceiptImage(String imagePath);
}
