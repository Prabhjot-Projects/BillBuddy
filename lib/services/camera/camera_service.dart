import 'dart:typed_data';
import 'package:billbuddy/services/camera/camera.dart';
import 'package:camera/camera.dart';

class CameraService implements Camera {
  CameraController? _controller;

  @override
  // Whether the camera is currently initialized.
  bool get isInitialized => _controller?.value.isInitialized ?? false;

  @override
  CameraController? get controller => _controller;

  @override
  Future<void> initialize() async {
    await _controller?.dispose();
    _controller = null;

    // List all available cameras.
    final cameras = await availableCameras();

    // Asks for back camera out of available cameras.
    final camera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );

    _controller = CameraController(camera, ResolutionPreset.high);

    await _controller!.initialize();
  }

  @override
  // Take photo and return Uint8List.
  Future<Uint8List> takePhoto() async {
    // Check if the camera is initialized.
    if (!isInitialized) {
      throw Exception('Camera is not initialized.');
    }

    // Store the picture into the file.
    final XFile file = await _controller!.takePicture();

    return await file.readAsBytes();
  }

  @override
  // Switch Between Front & Back camera.
  Future<void> switchCamera() async {
    if (!isInitialized) return;

    final cameras = await availableCameras();
    final currentDirection = _controller!.description.lensDirection;

    final switchedCamera = cameras.firstWhere(
      (camera) => camera.lensDirection != currentDirection,
    );

    await _controller?.dispose();

    _controller = CameraController(switchedCamera, ResolutionPreset.high);

    await _controller!.initialize();
  }

  @override
  // Release the camera resources.
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
  }
}
