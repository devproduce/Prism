import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:prism/services/cv_service.dart';
import 'package:prism/theme/colors.dart';
import 'package:prism/widgets/face_scan_grid.dart';

class MultiViewCaptureScreen extends StatefulWidget {
  const MultiViewCaptureScreen({super.key});

  @override
  State<MultiViewCaptureScreen> createState() => _MultiViewCaptureScreenState();
}

class _MultiViewCaptureScreenState extends State<MultiViewCaptureScreen> {
  CameraController? _cameraController;
  late CvService _cvService;

  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isCapturing = false; // Flag to prevent concurrent captures
  String _message = 'Initializing camera...';
  List<int> _capturedIndices = [];
  int? _currentGridIndex;
  bool _isComplete = false;
  List<String>? _faceIds;

  Timer? _frameSendTimer;

  @override
  void initState() {
    super.initState();
    _cvService = CvService();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Get available cameras
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _message = 'No camera found';
        });
        return;
      }

      // Use front camera for face capture
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
        _message = 'Connecting to CV service...';
      });

      // Connect to CV service
      await _connectToCvService();
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      setState(() {
        _message = 'Camera error: ${e.toString()}';
      });
    }
  }

  Future<void> _connectToCvService() async {
    try {
      await _cvService.connect();

      // Listen to CV feedback
      _cvService.statusStream.listen(
        (feedback) {
          if (!mounted) return;

          setState(() {
            _message = feedback.message;
            _capturedIndices = feedback.capturedIndices;
            _currentGridIndex = feedback.currentPose?.gridIndex;

            if (feedback.status == 'completed') {
              _isComplete = true;
              _faceIds = feedback.faceIds;
              _stopFrameSending();
              _cameraController?.dispose();
            }
          });
        },
        onError: (error) {
          debugPrint('CV Service error: $error');
          setState(() {
            _message = 'Connection error';
          });
        },
      );

      if (!mounted) return;

      setState(() {
        _message = 'Align your face in the center';
      });

      // Start sending frames
      _startFrameSending();
    } catch (e) {
      debugPrint('Error connecting to CV service: $e');
      setState(() {
        _message = 'Failed to connect: ${e.toString()}';
      });
    }
  }

  void _startFrameSending() {
    _isProcessing = true;
    // Send frames at ~5 FPS (200ms interval) to prevent camera overload
    // This gives camera sufficient time to complete each capture
    _frameSendTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _sendFrame();
    });
  }

  void _stopFrameSending() {
    _frameSendTimer?.cancel();
    _frameSendTimer = null;
    _isProcessing = false;
  }

  Future<void> _sendFrame() async {
    // Check if camera is ready and no capture is in progress
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        !_isProcessing ||
        _isComplete ||
        _isCapturing) {
      // Prevent concurrent captures
      return;
    }

    try {
      _isCapturing = true; // Mark capture as in progress
      debugPrint('🎥 Attempting to capture frame...');

      final image = await _cameraController!.takePicture();
      debugPrint('✓ Frame captured, size: ${await image.length()} bytes');
      final bytes = await image.readAsBytes();

      // Optionally compress/resize the image before sending
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage != null) {
        // Resize to reasonable size (e.g., 640x480) to reduce bandwidth
        final resized = img.copyResize(decodedImage, width: 640);
        final jpeg = img.encodeJpg(resized, quality: 80);
        debugPrint('📤 Sending ${jpeg.length} bytes to CV service...');
        _cvService.sendFrame(Uint8List.fromList(jpeg));
      } else {
        // Send original if decoding fails
        _cvService.sendFrame(Uint8List.fromList(bytes));
      }
    } catch (e) {
      debugPrint('❌ Error in _sendFrame: $e');
    } finally {
      _isCapturing = false; // Release the flag
    }
  }

  void _handleComplete() {
    if (_faceIds != null && _faceIds!.isNotEmpty) {
      // Return face IDs to previous screen
      Navigator.of(context).pop(_faceIds);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No face IDs received. Please try again.'),
          backgroundColor: PrismColors.destructiveRed,
        ),
      );
    }
  }

  void _retakeScan() {
    setState(() {
      _isComplete = false;
      _faceIds = null;
      _capturedIndices = [];
      _currentGridIndex = null;
      _message = 'Align your face in the center';
    });

    _cvService.close();
    _cvService = CvService();
    _connectToCvService();
    _initializeCamera();
  }

  @override
  void dispose() {
    _stopFrameSending();
    _cameraController?.dispose();
    _cvService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      appBar: AppBar(
        backgroundColor: PrismColors.voidBlack,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Face ID Setup',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: _isComplete ? _buildCompletionView() : _buildCaptureView(),
      ),
    );
  }

  Widget _buildCaptureView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Camera preview
        if (_isInitialized && _cameraController != null)
          Center(
            child: AspectRatio(
              aspectRatio: _cameraController!.value.aspectRatio,
              child: CameraPreview(_cameraController!),
            ),
          )
        else
          Center(
            child: CircularProgressIndicator(color: PrismColors.prismYellow),
          ),

        // Semi-transparent overlay
        Container(color: Colors.black.withOpacity(0.3)),

        // 3x3 Grid overlay
        if (_isInitialized)
          FaceScanGrid(
            capturedIndices: _capturedIndices,
            currentGridIndex: _currentGridIndex,
            message: _message,
          ),
      ],
    );
  }

  Widget _buildCompletionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: PrismColors.successGreen),
            const SizedBox(height: 24),
            const Text(
              'Face ID Setup Complete!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Captured ${_capturedIndices.length}/9 angles',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PrismColors.prismYellow,
                  foregroundColor: PrismColors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _retakeScan,
              child: const Text(
                'Retake Scan',
                style: TextStyle(color: PrismColors.prismYellow, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
