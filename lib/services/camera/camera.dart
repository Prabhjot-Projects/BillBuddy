import 'dart:typed_data';
import 'package:camera/camera.dart';

abstract class Camera {
  // Intialize the camera.
  Future<void> initialize();

  // Take photo and return Uint8List.
  Future<Uint8List> takePhoto();

  // Switch Between Front & Back camera.
  Future<void> switchCamera();

  // Release the camera resources.
  Future<void> dispose();

  // Whether the camera is currently initialized.
  bool get isInitialized;

  // The active controller is used to render the live camera preview.
  CameraController? get controller;
}
