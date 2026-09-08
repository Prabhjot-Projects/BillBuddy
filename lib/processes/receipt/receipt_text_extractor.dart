import 'dart:typed_data';
import 'package:billbuddy/core/utils/result.dart';
import 'receipt_validator.dart';
import 'package:billbuddy/services/ocr/ocr_service.dart';

/// Orchestrates OCR extraction + validation. This is a `processes/` class
/// (not `services/`) because it depends inward on our own OcrService and
/// ReceiptValidator — it composes internal app code rather than talking
/// to an external SDK directly.
class ReceiptTextExtractor {
  final OcrService ocrService;
  final ReceiptValidator receiptValidator;

  ReceiptTextExtractor({
    required this.ocrService,
    required this.receiptValidator,
  });

  /// Extracts text via OCR, then validates it looks receipt-like.
  /// Returns Result so a failure at either stage is explicit and
  /// carries a user-facing reason — nothing gets coerced into a string
  /// that could be mistaken for real OCR output.
  Future<Result<String>> call(Uint8List imageBytes) async {
    return callMany([imageBytes]);
  }

  /// Extracts multiple receipt pages in order and presents them as one
  /// normalized document to the parser.
  Future<Result<String>> callMany(List<Uint8List> imageBytesList) async {
    if (imageBytesList.isEmpty) {
      return Result.failure(
        const AppFailure(
          type: FailureType.emptyText,
          message: 'No receipt pages were selected.',
        ),
      );
    }

    final pageTexts = <String>[];
    for (final imageBytes in imageBytesList) {
      final ocrResult = await ocrService.extractText(imageBytes);
      if (ocrResult.isFailure) {
        return ocrResult;
      }
      final text = ocrResult.valueOrNull;
      if (text != null && text.trim().isNotEmpty) {
        pageTexts.add(text.trim());
      }
    }

    final combinedText = pageTexts.join('\n');
    if (combinedText.trim().isEmpty) {
      return Result.failure(
        const AppFailure(
          type: FailureType.emptyText,
          message:
              'No text was detected in the receipt pages. Try better lighting '
              'or retake the photos.',
        ),
      );
    }

    if (!receiptValidator.formatValidator(combinedText)) {
      return Result.failure(
        const AppFailure(
          type: FailureType.invalidReceiptFormat,
          message:
              'This doesn\'t look like a receipt. Try retaking the photo '
              'with the receipt filling more of the frame.',
        ),
      );
    }
    return Result.success(combinedText);
  }
}
