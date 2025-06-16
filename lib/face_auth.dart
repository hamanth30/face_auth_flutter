import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:geolocator/geolocator.dart';
import 'face_utils.dart';
import 'face_auth_service.dart';
import 'auth_service.dart';

class FaceAuthScreen extends StatefulWidget {
  final bool isRegistration;
  final String userId;

  const FaceAuthScreen({
    super.key,
    required this.isRegistration,
    required this.userId,
  });

  @override
  State<FaceAuthScreen> createState() => _FaceAuthScreenState();
}

class _FaceAuthScreenState extends State<FaceAuthScreen> {
  late CameraController _cameraController;
  late FaceDetector _faceDetector;
  bool _isInitialized = false;
  bool _isDetecting = false;
  List<Face> _faces = [];
  CameraLensDirection _direction = CameraLensDirection.front;
  String? _errorMessage;
  bool _isEmulator = false;
  bool _isProcessing = false;
  bool _isSuccess = false;
  String? _statusMessage;

  final FaceAuthService _faceAuthService = FaceAuthService();

  bool? _locationAuthenticated;
  String _locationMessage = '';

  static const double officeLat = 12.9716; // Replace with your office latitude
  static const double officeLng = 77.5946; // Replace with your office longitude
  static const double allowedDistance = 50; // meters

  @override
  void initState() {
    super.initState();
    _checkIfEmulator();
    _initializeFaceDetector();
    _checkLocation();
    _initializeCamera();
  }

  void _checkIfEmulator() {
    _isEmulator =
        kDebugMode && (defaultTargetPlatform == TargetPlatform.android);
  }

  @override
  void dispose() {
    if (_isInitialized) {
      _cameraController.dispose();
    }
    _faceDetector.close();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      setState(() {
        _errorMessage = null;
        _isInitialized = false;
      });

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras found on this device');
      }

      final camera = await FaceUtils.getCamera(_direction);
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController.initialize();

      if (_isEmulator) {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _cameraController.startImageStream(_processCameraImage);

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize camera: ${e.toString()}';
          _isInitialized = false;
        });
      }
    }
  }

  void _initializeFaceDetector() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.1,
        enableLandmarks: true,
        enableContours: false,
        enableClassification: false,
      ),
    );
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isDetecting || _isProcessing) return;
    _isDetecting = true;

    try {
      final rotation = FaceUtils.getImageRotation(_direction);
      final inputImage = FaceUtils.buildInputImage(image, rotation);
      final faces = await _faceDetector.processImage(inputImage);

      if (mounted) {
        setState(() => _faces = faces);
      }

      // If we have exactly one face and we're not already processing
      if (faces.length == 1 && !_isProcessing) {
        _handleFaceDetection(faces.first);
      }
    } catch (e) {
      debugPrint('Error processing image: $e');
      if (!_isEmulator) {
        setState(() {
          _errorMessage = 'Face detection error: ${e.toString()}';
        });
      }
    } finally {
      _isDetecting = false;
    }
  }

  Future<void> _handleFaceDetection(Face face) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = widget.isRegistration
          ? 'Registering your face...'
          : 'Verifying your face...';
    });

    try {
      if (widget.isRegistration) {
        // Registration flow
        await _faceAuthService.registerFace(widget.userId, face);
        setState(() {
          _isSuccess = true;
          _statusMessage = 'Face registered successfully!';
        });
        await Future.delayed(const Duration(seconds: 2));
        Navigator.of(context).pop(true);
      } else {
        // Verification flow
        final isVerified = await _faceAuthService.verifyFace(
          widget.userId,
          face,
        );
        setState(() {
          _isSuccess = isVerified;
          _statusMessage = isVerified
              ? 'Face verified successfully!'
              : 'Face verification failed';
        });

        if (isVerified) {
          await Future.delayed(const Duration(seconds: 2));
          Navigator.of(context).pop(true);
        } else {
          await Future.delayed(const Duration(seconds: 2));
          setState(() {
            _isProcessing = false;
            _statusMessage = null;
          });
        }
      }
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _statusMessage = 'Error: ${e.toString()}';
      });
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _isProcessing = false;
        _statusMessage = null;
      });
    }
  }

  Future<void> _toggleCamera() async {
    setState(() {
      _direction = _direction == CameraLensDirection.front
          ? CameraLensDirection.back
          : CameraLensDirection.front;
      _isInitialized = false;
      _faces = [];
      _errorMessage = null;
    });

    if (_isInitialized) {
      await _cameraController.dispose();
    }
    await _initializeCamera();
  }

  Future<void> _checkLocation() async {
    setState(() {
      _locationAuthenticated = null;
      _locationMessage = 'Checking location...';
    });

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationAuthenticated = false;
        _locationMessage = 'Location services are disabled.';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _locationAuthenticated = false;
          _locationMessage = 'Location permission denied.';
        });
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _locationAuthenticated = false;
        _locationMessage = 'Location permission permanently denied.';
      });
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    double distance = Geolocator.distanceBetween(
      officeLat,
      officeLng,
      position.latitude,
      position.longitude,
    );

    if (distance <= allowedDistance) {
      setState(() {
        _locationAuthenticated = true;
        _locationMessage = 'Location authenticated!';
      });
    } else {
      setState(() {
        _locationAuthenticated = false;
        _locationMessage = 'You are not within the office range.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isRegistration ? 'Register Face' : 'Verify Face'),
        actions: [
          if (_isInitialized)
            IconButton(
              icon: const Icon(Icons.cameraswitch),
              onPressed: _toggleCamera,
            ),
        ],
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_locationMessage),
              const SizedBox(width: 8),
              if (_locationAuthenticated == true)
                const Icon(Icons.check_circle, color: Colors.green)
              else if (_locationAuthenticated == false)
                const Icon(Icons.cancel, color: Colors.red),
            ],
          ),
          Expanded(
            child: _locationAuthenticated == true
                ? _buildBody()
                : Center(
                    child: Text(
                      'Face authentication is disabled until you are at the office.',
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Camera Error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeCamera,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Initializing camera...'),
          ],
        ),
      );
    }

    return Stack(
      children: [
        CameraPreview(_cameraController),
        _buildFaceBoxes(),
        _buildFaceCounter(),
        if (_statusMessage != null) _buildStatusOverlay(),
      ],
    );
  }

  Widget _buildStatusOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSuccess ? Icons.check_circle : Icons.error,
              color: _isSuccess ? Colors.green : Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!_isSuccess && !widget.isRegistration) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isProcessing = false;
                    _statusMessage = null;
                  });
                },
                child: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFaceBoxes() {
    if (_faces.isEmpty) {
      return const Center(
        child: Text(
          'No faces detected',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            backgroundColor: Colors.black54,
          ),
        ),
      );
    }

    return CustomPaint(
      painter: FacePainter(_faces, _cameraController.value.previewSize!),
    );
  }

  Widget _buildFaceCounter() {
    return Positioned(
      top: 16,
      left: 16,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Faces: ${_faces.length}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;

  FacePainter(this.faces, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.green;

    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    for (final face in faces) {
      canvas.drawRect(
        Rect.fromLTRB(
          face.boundingBox.left * scaleX,
          face.boundingBox.top * scaleY,
          face.boundingBox.right * scaleX,
          face.boundingBox.bottom * scaleY,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.faces != faces || oldDelegate.imageSize != imageSize;
  }
}
