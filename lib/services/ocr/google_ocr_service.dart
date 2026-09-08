import 'dart:io';
import 'dart:typed_data';
import '../../core/utils/result.dart';
import 'ocr_service.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

class GoogleOcrService implements OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();

  @override
  Future<Result<String>> extractText(Uint8List imageByte) async {
    File? tempFile;

    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
      tempFile = File(tempPath);
      await tempFile.writeAsBytes(imageByte);

      final inputImage = InputImage.fromFilePath(tempPath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // ML Kit doesn't throw when it finds nothing — it just returns an
      // empty string. That's a legitimate "failure" for our purposes
      // (bad lighting, blurry photo, no text in frame) and the caller
      // needs to know so it can prompt a retake instead of sending
      // empty text to Gemini.
      final normalizedText = _normalizeText(recognizedText.text);
      if (normalizedText.isEmpty) {
        return Result.failure(
          const AppFailure(
            type: FailureType.emptyText,
            message:
                'No text was detected in the photo. Try retaking it with '
                'better lighting or holding the camera steadier.',
          ),
        );
      }

      return Result.success(normalizedText);
    } on FileSystemException catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.storageError,
          message: 'Could not save the photo for processing.',
          cause: e,
        ),
      );
    } catch (e) {
      return Result.failure(
        AppFailure(
          type: FailureType.ocrFailed,
          message: 'Text recognition failed unexpectedly.',
          cause: e,
        ),
      );
    } finally {
      // Always clean up the temp file, success or failure — otherwise
      // every scan leaks a JPEG into the temp directory.
      if (tempFile != null && await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _textRecognizer.close();
  }

  String _normalizeText(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .join('\n')
        .trim();
  }
}
