import 'dart:typed_data';
import 'package:billbuddy/core/utils/result.dart';
import 'package:billbuddy/data/entities/receipt.dart';
import 'receipt_repository.dart';
import 'receipt_text_extractor.dart';
import 'package:billbuddy/services/ai/receipt_parser.dart';
import '../../services/storage/local/image_storage_service.dart';
import 'receipt_image_repository.dart';

/// Runs the full pipeline from raw image bytes to a saved draft Receipt:
/// OCR -> validate -> AI parse -> save image -> save draft.
///
/// Extracted from ScanScreen so both the camera flow (ScanScreen) and
/// the gallery-upload flow (UploadScreen) execute identical logic —
/// before this existed, the only way to add upload_screen would have
/// been to either duplicate ~80 lines of orchestration or make one
/// screen call into the other's State class, both of which are worse
/// than a shared process both screens depend on.
///
/// Lives in `processes/` (not `services/`) because it has zero direct
/// external-technology dependency of its own — it only composes other
/// internal processes/services (ReceiptTextExtractor, ReceiptParser,
/// ImageStorageService, ReceiptRepository), which is exactly the
/// services-vs-processes tie-breaker rule from ARCHITECTURE.md.
class ReceiptScanPipeline {
  final ReceiptTextExtractor textExtractor;
  final ReceiptParser parser;
  final ImageStorageService imageStorage;
  final ReceiptRepository receiptRepository;
  final ReceiptImageRepository receiptImageRepository;

  ReceiptScanPipeline({
    required this.textExtractor,
    required this.parser,
    required this.imageStorage,
    required this.receiptRepository,
    required this.receiptImageRepository,
  });

  /// [onNonFatalWarning] lets the caller show a lightweight message for
  /// failures that don't stop the pipeline (currently just "image
  /// couldn't be saved") without this class needing to know about
  /// SnackBars or any other UI concept — it stays UI-framework-agnostic,
  /// consistent with everything else in processes/.
  Future<Result<Receipt>> run(
    Uint8List imageBytes, {
    void Function(String message)? onNonFatalWarning,
  }) async {
    // flatMapAsync chains each step, short-circuiting to the first
    // failure automatically — this replaces what would otherwise be
    // repeated "if isFailure, cast and return" blocks (the same unsafe
    // pattern fixed earlier in ScanScreen) with a single composable
    // pipeline that can never accidentally cast the wrong branch.
    return runMany([imageBytes], onNonFatalWarning: onNonFatalWarning);
  }

  Future<Result<Receipt>> runMany(
    List<Uint8List> imageBytesList, {
    void Function(String message)? onNonFatalWarning,
  }) async {
    final textResult = await textExtractor.callMany(imageBytesList);

    return textResult.flatMapAsync((extractedText) async {
      final parseResult = await parser.parse(extractedText);

      return parseResult.flatMapAsync((receipt) async {
        final imageSaveResult = await imageStorage.saveReceiptImages(
          receiptId: receipt.id,
          imageBytes: imageBytesList,
        );

        final receiptWithImage = imageSaveResult.fold(
          onSuccess: (paths) => receipt.copyWith(imagePath: paths.first),
          onFailure: (failure) {
            onNonFatalWarning?.call(
              'Receipt saved, but the photo could not be stored.',
            );
            return receipt;
          },
        );

        final draftSaveResult = await receiptRepository.saveDraft(
          receiptWithImage,
        );
        if (draftSaveResult.isFailure) {
          return Result.failure(
            draftSaveResult.fold(
              onSuccess: (_) => throw StateError('Unexpected success'),
              onFailure: (failure) => failure,
            ),
          );
        }

        final paths = imageSaveResult.valueOrNull;
        if (paths != null) {
          final pagesResult = await receiptImageRepository.savePages(
            receiptId: receipt.id,
            imagePaths: paths,
          );
          if (pagesResult.isFailure) {
            return Result.failure(
              pagesResult.fold(
                onSuccess: (_) => throw StateError('Unexpected success'),
                onFailure: (failure) => failure,
              ),
            );
          }
        }
        return Result.success(receiptWithImage);
      });
    });
  }
}
