import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:prism/services/cv_service.dart';
import 'package:prism/theme/colors.dart';

import 'package:flutter_animate/flutter_animate.dart';

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
  bool _isCapturing = false;
  String _message = 'Initializing camera...';
  List<int> _capturedIndices = []; // Still useful for raw feedback

  bool _isComplete = false;
  List<String>? _faceIds; // Face IDs from backend
  final Map<int, Uint8List> _capturedFrames = {}; // Store local frames for display
  final bool _isSaving = false;

  // 3-View Progress Tracking (Simplified)
  // We assume the server guides the user: Center -> Left -> Right (or similar)
  // We'll trust the server's "capturedIndices" or "message" to guide the user.
  // But for UI, we want to show 3 clear steps.
  // Let's assume indices 0, 1, 2 correspond to Left, Center, Right or similar.
  // We'll visualize progress based on count of captured views.

  Timer? _frameSendTimer;

  @override
  void initState() {
    super.initState();
    _cvService = CvService();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _message = 'No camera found');
        return;
      }

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

      await _connectToCvService();
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      setState(() => _message = 'Camera error: ${e.toString()}');
    }
  }

  Future<void> _connectToCvService() async {
    try {
      await _cvService.connect();

      _cvService.statusStream.listen(
        (feedback) {
          if (!mounted) return;

          setState(() {
            _message = feedback.message;

            // Check for new captures to save frame
            for (final index in feedback.capturedIndices) {
              if (!_capturedFrames.containsKey(index) &&
                  _lastSentFrame != null) {
                // Approximate: Valid enough for UI feedback
                _capturedFrames[index] = _lastSentFrame!;
              }
            }

            _capturedIndices = feedback.capturedIndices;

            if (feedback.status == 'completed') {
              // Capture remaining frames if missing (e.g. fast completion)
              // This is tricky without the video stream.
              // We'll rely on what we have or show placeholders.
              _isComplete = true;
              _faceIds = feedback.faceIds;
              _message = 'Face scan complete!';
              _stopFrameSending();
            }
          });
        },
        onError: (error) {
          debugPrint('CV Service error: $error');
          setState(() => _message = 'Connection error');
        },
      );

      if (!mounted) return;

      setState(() => _message = 'Align your face in the center');
      _startFrameSending();
    } catch (e) {
      debugPrint('Error connecting to CV service: $e');
      setState(() => _message = 'Failed to connect: ${e.toString()}');
    }
  }

  void _startFrameSending() {
    _isProcessing = true;
    // Send frames at ~3 FPS to prevent camera overload
    _frameSendTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      _sendFrame();
    });
  }

  void _stopFrameSending() {
    _frameSendTimer?.cancel();
    _frameSendTimer = null;
    _isProcessing = false;
  }

  Future<void> _sendFrame() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        !_isProcessing ||
        _isComplete ||
        _isCapturing) {
      return;
    }

    try {
      _isCapturing = true;
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();

      // Optimize image size for bandwidth
      // Optimize image size for bandwidth
      final decodedImage = img.decodeImage(bytes);
      if (decodedImage != null) {
        final resized = img.copyResize(decodedImage, width: 640);
        final jpeg = img.encodeJpg(resized, quality: 80);
        _cvService.sendFrame(Uint8List.fromList(jpeg));

        // Store frame for potential display (Approximation: store every frame?? No, too heavy)
        // Better strategy: Store the *last* frame sent for each *potential* index if we could?
        // Actually, we can just save the last frame sent to a temp variable.
        // If the *next* feedback says "captured index X", we assign that temp frame to X.
        // This requires careful sync.
        // For now, let's just update the "last sent frame"
        _lastSentFrame = Uint8List.fromList(jpeg);
      } else {
        _cvService.sendFrame(Uint8List.fromList(bytes));
        _lastSentFrame = Uint8List.fromList(bytes);
      }
    } catch (e) {
      debugPrint('Error sending frame: $e');
    } finally {
      _isCapturing = false;
    }
  }

  Future<void> _handleComplete() async {
    if (_faceIds != null && _faceIds!.isNotEmpty) {
      String? imagePath;
      try {
        // Save a captured frame to use as profile picture
        if (_capturedFrames.isNotEmpty) {
          // Prefer center frame (index 1) or just first available
          final key = _capturedFrames.containsKey(1)
              ? 1
              : _capturedFrames.keys.first;
          final bytes = _capturedFrames[key];

          if (bytes != null) {
            final tempDir = await getTemporaryDirectory();
            final file = File(
              '${tempDir.path}/face_capture_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            await file.writeAsBytes(bytes);
            imagePath = file.path;
          }
        }
      } catch (e) {
        debugPrint('Error saving face capture image: $e');
      }

      if (mounted) {
        Navigator.of(
          context,
        ).pop({'faceIds': _faceIds, 'imagePath': imagePath});
      }
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

      _capturedFrames.clear(); // Clear local frames
      _lastSentFrame = null;
      _message = 'Align your face in the center';
    });

    _cvService.close();
    _cvService = CvService();
    _connectToCvService();
    _initializeCamera();
  }

  Uint8List? _lastSentFrame;

  @override
  void dispose() {
    _stopFrameSending();
    _cameraController?.dispose();
    _cvService.dispose();
    super.dispose();
  }

  // Update check logic to save frame if index increased
  // This needs to be in the listener, but we can't easily access _lastSentFrame there due to async gap?
  // Actually we can.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrismColors.voidBlack,
      // Minimal app bar just for close
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [PrismColors.voidBlack, Color(0xFF1A1A1A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Header
              Text(
                _isComplete ? 'Scan Complete' : 'Face ID Setup',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete a quick face scan to continue',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),

              const Spacer(),

              // Main Content (Containerized like Modal)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: PrismColors.surfaceGray.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tutorial / Progress Grid (Top of card)
                    if (!_isComplete) ...[
                      _buildStepIndicator(),
                      const SizedBox(height: 24),
                    ],

                    // Camera / Results Area
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                        minHeight: 250,
                      ),
                      child: AspectRatio(
                        aspectRatio: 3 / 4, // Typical camera aspect ratio
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isComplete
                                  ? PrismColors.successGreen.withOpacity(0.3)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: _isComplete
                              ? _buildCapturedGrid()
                              : _buildCameraFeed(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Status Message
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isComplete)
                          Icon(
                            Icons.auto_awesome,
                            color: PrismColors.successGreen,
                            size: 20,
                          )
                        else if (_isProcessing)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: PrismColors.prismYellow,
                            ),
                          ),

                        const SizedBox(width: 8),
                        Text(
                          _message,
                          style: TextStyle(
                            color: _isComplete
                                ? PrismColors.successGreen
                                : Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Actions
                    // Actions
                    if (_isComplete)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _retakeScan,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Retake'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: Colors.white.withOpacity(0.2),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _handleComplete, // "Save & Continue"
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check, size: 18),
                            label: const Text('Save & Continue'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PrismColors.prismYellow,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Complete all 3 positions to continue',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    // Determine current step based on captured count
    final stepIndex = _capturedIndices.length.clamp(0, 2);

    final instructions = [
      "Look Straight Ahead",
      "Turn Head Slightly Left",
      "Turn Head Slightly Right",
    ];

    final icons = [Icons.face, Icons.turn_left, Icons.turn_right];

    return Column(
      children: [
        Icon(icons[stepIndex], size: 32, color: PrismColors.prismYellow)
            .animate(key: ValueKey('icon_$stepIndex'))
            .scale(duration: 300.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 8),
        Text(
              instructions[stepIndex],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            )
            .animate(key: ValueKey('text_$stepIndex'))
            .fadeIn()
            .moveY(begin: 5, end: 0),
      ],
    );
  }

  Widget _buildCameraFeed() {
    if (!_isInitialized || _cameraController == null) {
      return const Center(
        child: CircularProgressIndicator(color: PrismColors.prismYellow),
      );
    }

    return Stack(
      fit: StackFit.loose,
      alignment: Alignment.center,
      children: [
        // Camera Preview centered and scaled to show FULL FOV (contain)
        Center(child: CameraPreview(_cameraController!)),

        // Face Guide Circle
        Center(
          child: Container(
            width: 200,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(
                color: PrismColors.prismYellow.withOpacity(0.5),
                width: 3,
              ),
              borderRadius: BorderRadius.circular(120),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCapturedGrid() {
    if (_capturedFrames.isEmpty) {
      // Fallback if no frames were saved (shouldn't happen with logic above)
      return const Center(
        child: Text(
          "No frames captured locally",
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Row(
      children: List.generate(3, (index) {
        final frame = _capturedFrames[index];
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index < 2 ? 8.0 : 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: PrismColors.successGreen.withOpacity(0.3),
                width: 2,
              ),
              color: Colors.black54,
            ),
            clipBehavior: Clip.hardEdge,
            child: frame != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      // Blurred Background (Zoomed to cover)
                      Image.memory(
                        frame,
                        fit: BoxFit.cover,
                        color: Colors.black.withOpacity(0.6),
                        colorBlendMode: BlendMode.darken,
                      ),
                      // Foreground Image (Contained to show full face)
                      Center(child: Image.memory(frame, fit: BoxFit.contain)),
                    ],
                  )
                : const Center(
                    child: Icon(Icons.check, color: PrismColors.successGreen),
                  ),
          ),
        );
      }),
    );
  }
}
