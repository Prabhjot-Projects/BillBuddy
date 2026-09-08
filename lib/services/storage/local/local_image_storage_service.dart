import 'dart:io';
import 'dart:typed_data';
import 'package:billbuddy/core/utils/result.dart';
import 'image_storage_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Saves receipt images to the app's documents directory — the correct
/// location for user-generated content that should persist across app
/// launches and NOT be cleared by the OS under storage pressure (unlike
/// the temp/cache directory, which the OS can wipe at any time).
///
/// Images are named by receiptId so the mapping from Receipt -> image
/// file is deterministic and doesn't need to be looked up — the path is
/// simply `<documents>/receipts/<receiptId>.jpg`.
class LocalImageStorageService implements ImageStorageService {
  static const _receiptsSubdir = 'receipts';

  Future<Directory> _receiptsDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(p.join(docsDir.path, _receiptsSubdir));
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }
    return receiptsDir;
  }

  @override
  Future<Result<String>> saveReceiptImage({
    required String receiptId,
    required Uint8List imageBytes,
  }) async {
    try {
      final dir = await _receiptsDirectory();
      final filePath = p.join(dir.path, '$receiptId.jpg');
      final file = File(filePath);
      await file.writeAsBytes(imageBytes, flush: true);
      return Result.success(filePath);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not save the receipt image.',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<List<String>>> saveReceiptImages({
    required String receiptId,
    required List<Uint8List> imageBytes,
  }) async {
    try {
      final dir = await _receiptsDirectory();
      await _deleteStoredPages(dir, receiptId);
      final paths = <String>[];
      for (var index = 0; index < imageBytes.length; index++) {
        final path = p.join(dir.path, '${receiptId}_page_${index + 1}.jpg');
        await File(path).writeAsBytes(imageBytes[index], flush: true);
        paths.add(path);
      }
      return Result.success(paths);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not save receipt pages.',
          cause: e,
        ),
      );
    }
  }

  Future<void> _deleteStoredPages(Directory directory, String receiptId) async {
    final prefix = '${receiptId}_page_';
    await for (final entity in directory.list()) {
      if (entity is File && p.basename(entity.path).startsWith(prefix)) {
        await entity.delete();
      }
    }
  }

  @override
  Future<Result<void>> deleteReceiptImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
      return Result.success(null);
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not delete the receipt image.',
          cause: e,
        ),
      );
    }
  }
}
