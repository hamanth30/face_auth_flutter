import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class FaceAuthService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Store face embeddings for a user
  Future<void> registerFace(String userId, Face face) async {
    try {
      // Convert face data to JSON
      final faceData = _faceToJson(face);
      
      // Store in Firebase Storage
      await _storage.ref('face_data/$userId.json').putString(faceData);
    } catch (e) {
      throw Exception('Failed to register face: $e');
    }
  }

  // Verify face against stored embeddings
  Future<bool> verifyFace(String userId, Face face) async {
    try {
      // Get stored face data
      final ref = _storage.ref('face_data/$userId.json');
      final data = await ref.getData();
      if (data == null) return false;
      
      final faceData = utf8.decode(data);
      final storedFace = _jsonToFace(faceData);
      return _compareFaces(storedFace, face);
    } catch (e) {
      return false;
    }
  }

  // Helper methods
  String _faceToJson(Face face) {
    return jsonEncode({
      'width': face.boundingBox.width,
      'height': face.boundingBox.height,
      'left': face.boundingBox.left,
      'top': face.boundingBox.top,
    });
  }

  Face _jsonToFace(String json) {
    final data = jsonDecode(json);
    return Face(
      boundingBox: Rect.fromLTWH(
        data['left'],
        data['top'],
        data['width'],
        data['height'],
      ),
      trackingId: null,
      landmarks: {},
      contours: {},
      headEulerAngleX: 0,
      headEulerAngleY: 0,
      headEulerAngleZ: 0,
      leftEyeOpenProbability: 0,
      rightEyeOpenProbability: 0,
      smilingProbability: 0,
    );
  }

  bool _compareFaces(Face storedFace, Face currentFace) {
    final storedArea = storedFace.boundingBox.width * storedFace.boundingBox.height;
    final currentArea = currentFace.boundingBox.width * currentFace.boundingBox.height;
    return (currentArea - storedArea).abs() / storedArea < 0.2;
  }
}