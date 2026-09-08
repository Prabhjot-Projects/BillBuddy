import 'package:flutter/services.dart';

import '../../core/utils/result.dart';
import 'ocr_service.dart';

/// Uses the operating system's on-device OCR implementation.
///
/// The iOS implementation is backed by Apple Vision through the method
/// channel registered in Runner/AppDelegate.swift. This service is selected
/// only on iOS; Android continues to use Google ML Kit.
class NativeOcrService implements OcrService {
  static const _channel = MethodChannel('billbuddy/native_ocr');

  @override
  Future<Result<String>> extractText(Uint8List imageBytes) async {
    try {
      final text = await _channel.invokeMethod<String>(
        'recognizeText',
        imageBytes,
      );

      final normalizedText = _normalizeText(text);
      if (normalizedText.isEmpty) {
        return Result.failure(
          const AppFailure(
            type: FailureType.emptyText,
            message:
                'No text was detected in the photo. Try retaking it with better '
                'lighting or holding the camera steadier.',
          ),
        );
      }

      return Result.success(normalizedText);
    } on PlatformException catch (error) {
      return Result.failure(
        AppFailure(
          type: FailureType.ocrFailed,
          message: 'Native text recognition failed.',
          cause: error,
        ),
      );
    } catch (error) {
      return Result.failure(
        AppFailure(
          type: FailureType.ocrFailed,
          message: 'Text recognition failed unexpectedly.',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {}

  String _normalizeText(String? text) {
    return text
            ?.replaceAll('\r\n', '\n')
            .replaceAll('\r', '\n')
            .split('\n')
            .map((line) => line.trimRight())
            .where((line) => line.isNotEmpty)
            .join('\n')
            .trim() ??
        '';
  }
}
