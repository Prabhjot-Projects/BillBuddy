import Flutter
import UIKit
import Vision

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "billbuddy/native_ocr",
      binaryMessenger: engineBridge.binaryMessenger
    )

    channel.setMethodCallHandler { call, result in
      guard call.method == "recognizeText" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let imageBytes = call.arguments as? FlutterStandardTypedData,
            let image = UIImage(data: imageBytes.data),
            let cgImage = image.cgImage else {
        result(FlutterError(
          code: "invalid_image",
          message: "The supplied image could not be decoded.",
          details: nil
        ))
        return
      }

      let request = VNRecognizeTextRequest { request, error in
        if let error = error {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "vision_error",
              message: error.localizedDescription,
              details: nil
            ))
          }
          return
        }

        let observations = (request.results as? [VNRecognizedTextObservation] ?? [])
          .sorted {
            let verticalDelta = abs($0.boundingBox.midY - $1.boundingBox.midY)
            if verticalDelta > 0.02 {
              return $0.boundingBox.midY > $1.boundingBox.midY
            }
            return $0.boundingBox.minX < $1.boundingBox.minX
          }
        let text = observations.compactMap {
          $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }.joined(separator: "\n")
        DispatchQueue.main.async {
          result(text)
        }
      }
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true

      DispatchQueue.global(qos: .userInitiated).async {
        do {
          let handler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation),
            options: [:]
          )
          try handler.perform([request])
        } catch {
          DispatchQueue.main.async {
            result(FlutterError(
              code: "vision_error",
              message: error.localizedDescription,
              details: nil
            ))
          }
        }
      }
    }
  }
}

private extension CGImagePropertyOrientation {
  init(_ orientation: UIImage.Orientation) {
    switch orientation {
    case .up: self = .up
    case .down: self = .down
    case .left: self = .left
    case .right: self = .right
    case .upMirrored: self = .upMirrored
    case .downMirrored: self = .downMirrored
    case .leftMirrored: self = .leftMirrored
    case .rightMirrored: self = .rightMirrored
    @unknown default: self = .up
    }
  }
}
