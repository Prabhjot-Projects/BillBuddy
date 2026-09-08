import 'dart:typed_data';
import '../../core/utils/result.dart';

// Contract for OCR services.
abstract class OcrService {
  // Receive image bytes and extract text.
  // Returns Result so callers can distinguish "OCR ran but found nothing"
  // from "OCR crashed" from "success" — all three need different UX.
  Future<Result<String>> extractText(Uint8List imageBytes);

  Future<void> dispose();
}
