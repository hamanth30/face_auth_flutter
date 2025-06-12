import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

class FaceUtils {
  FaceUtils._();

  static Future<CameraDescription> getCamera(CameraLensDirection direction) async {
    try {
      final cameras = await availableCameras();
      
      // Debug print to see available cameras
      debugPrint('Available cameras: ${cameras.length}');
      for (var camera in cameras) {
        debugPrint('Camera: ${camera.name}, Direction: ${camera.lensDirection}');
      }
      
      // Try to find the requested camera direction
      try {
        return cameras.firstWhere(
          (camera) => camera.lensDirection == direction,
        );
      } catch (e) {
        // If requested direction not found, return any available camera
        if (cameras.isNotEmpty) {
          debugPrint('Requested camera direction not found, using first available camera');
          return cameras.first;
        } else {
          throw Exception('No cameras available on this device');
        }
      }
    } catch (e) {
      debugPrint('Error getting cameras: $e');
      throw Exception('Failed to access cameras: $e');
    }
  }

  static InputImage buildInputImage(CameraImage image, InputImageRotation rotation) {
    // Handle different image formats properly
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) {
      throw Exception('Unsupported image format: ${image.format.raw}');
    }
    
    final metadata = InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: image.planes.first.bytesPerRow,
    );

    // For better compatibility, handle different formats
    Uint8List bytes;
    if (image.format.group == ImageFormatGroup.yuv420) {
      bytes = _concatenatePlanes(image.planes);
    } else if (image.format.group == ImageFormatGroup.bgra8888) {
      bytes = image.planes.first.bytes;
    } else {
      bytes = _concatenatePlanes(image.planes);
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: metadata,
    );
  }

  static Uint8List _concatenatePlanes(List<Plane> planes) {
    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  // Helper method to get proper rotation based on device orientation and camera direction
  static InputImageRotation getImageRotation(CameraLensDirection direction) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return InputImageRotation.rotation90deg;
    }
    
    // For Android
    switch (direction) {
      case CameraLensDirection.front:
        return InputImageRotation.rotation270deg;
      case CameraLensDirection.back:
      case CameraLensDirection.external:
        return InputImageRotation.rotation90deg;
    }
  }
}