import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class FaceAuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Store face embeddings for a user in Firestore
  Future<void> registerFace(String userId, Face face) async {
    try {
      final faceData = _faceToJson(face);
      await _firestore.collection('face_data').doc(userId).set({
        'face': faceData,
      });
    } catch (e) {
      throw Exception('Failed to register face: $e');
    }
  }

  // Verify face against stored embeddings in Firestore
  Future<bool> verifyFace(String userId, Face face) async {
    try {
      final doc = await _firestore.collection('face_data').doc(userId).get();
      if (!doc.exists) return false;
      final faceData = doc.data()!['face'];
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
    final storedArea =
        storedFace.boundingBox.width * storedFace.boundingBox.height;
    final currentArea =
        currentFace.boundingBox.width * currentFace.boundingBox.height;
    return (currentArea - storedArea).abs() / storedArea < 0.2;
  }
}
