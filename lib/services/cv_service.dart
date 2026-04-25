import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CvService {
  static const String wsUrl = 'ws://cv.prismapp.in/ws/register_multi_views';

  WebSocketChannel? _channel;
  final _statusController = StreamController<CvFeedback>.broadcast();
  bool _isConnected = false;

  Stream<CvFeedback> get statusStream => _statusController.stream;
  bool get isConnected => _isConnected;

  /// Connect to the CV service WebSocket
  Future<void> connect() async {
    try {
      debugPrint('📡 [CV SERVICE] Connecting to: $wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _isConnected = true;
      debugPrint(
        '✓ [CV SERVICE] WebSocket channel created, listening for messages...',
      );

      // Listen to messages from server
      _channel!.stream.listen(
        (message) {
          debugPrint('📥 [CV SERVICE] Received message from server');
          debugPrint('📦 [CV SERVICE] RAW: $message'); // Log raw response
          try {
            final data = jsonDecode(message as String);
            debugPrint('📦 [CV SERVICE] PARSED JSON: $data'); // Log parsed JSON
            final feedback = CvFeedback.fromJson(data);
            _statusController.add(feedback);
            debugPrint(
              '✓ [CV SERVICE] Feedback: status=${feedback.status}, message="${feedback.message}", indices=${feedback.capturedIndices}',
            );

            if (feedback.status == 'completed') {
              debugPrint(
                '🎉 [CV SERVICE] Multi-view capture completed! FaceIds: ${feedback.faceIds}',
              );
            }
          } catch (e) {
            debugPrint('❌ [CV SERVICE] Error parsing feedback: $e');
          }
        },
        onError: (error, stackTrace) {
          debugPrint('❌ [CV SERVICE] WebSocket error: $error');
          debugPrint('❌ [CV SERVICE] Stack trace: $stackTrace');
          
          if (error is WebSocketChannelException) {
            debugPrint('❌ [CV SERVICE] Inner exception: ${error.inner}');
          }
          
          // Also check if the URL itself might be wrong (ws:// vs wss://)
          debugPrint('❌ [CV SERVICE] Failed to connect to URL: $wsUrl');
          
          _isConnected = false;
          _statusController.addError(error);
        },
        onDone: () {
          debugPrint('⚠️ [CV SERVICE] WebSocket connection closed. Close Code: ${_channel?.closeCode}, Close Reason: ${_channel?.closeReason}');
          _isConnected = false;
        },
      );

      debugPrint(
        '✓ [CV SERVICE] Connection setup complete, ready to send frames',
      );
    } catch (e) {
      debugPrint('❌ [CV SERVICE] Failed to connect: $e');
      _isConnected = false;
      rethrow;
    }
  }

  /// Send a frame to the CV service
  void sendFrame(Uint8List frameBytes) {
    if (!_isConnected || _channel == null) {
      debugPrint(
        '⚠️ [CV SERVICE] Cannot send frame: not connected (isConnected=$_isConnected, channel=${_channel != null})',
      );
      return;
    }

    try {
      debugPrint(
        '📤 [CV SERVICE] Sending ${frameBytes.length} bytes as binary...',
      );
      // Send as binary blob (not base64) - matching web app behavior
      _channel!.sink.add(frameBytes);
      debugPrint('✓ [CV SERVICE] Binary frame sent successfully');
    } catch (e) {
      debugPrint('❌ [CV SERVICE] Error sending frame: $e');
    }
  }

  /// Close the WebSocket connection
  void close() {
    debugPrint('Closing CV service connection');
    _channel?.sink.close();
    _isConnected = false;
  }

  void dispose() {
    close();
    _statusController.close();
  }
}

/// Feedback from the CV service
class CvFeedback {
  final String status; // "processing" or "completed"
  final String message;
  final PoseData? currentPose;
  final List<int> capturedIndices;
  final List<String>? faceIds; // Only present when status == "completed"

  CvFeedback({
    required this.status,
    required this.message,
    this.currentPose,
    required this.capturedIndices,
    this.faceIds,
  });

  factory CvFeedback.fromJson(Map<String, dynamic> json) {
    // Handle grid_index at root level OR inside current_pose
    PoseData? poseData;
    if (json['current_pose'] != null) {
      poseData = PoseData.fromJson(
        json['current_pose'] as Map<String, dynamic>,
      );
    } else if (json['grid_index'] != null) {
      // Server sends grid_index at root level without full pose data
      poseData = PoseData(
        pitch: 0.0,
        yaw: 0.0,
        roll: 0.0,
        gridIndex: json['grid_index'] as int,
      );
    }

    return CvFeedback(
      status: json['status'] as String? ?? 'processing',
      message: json['message'] as String? ?? '',
      currentPose: poseData,
      capturedIndices:
          (json['captured_indices'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      faceIds: json['backend_data']?['face_ids'] != null
          ? (json['backend_data']['face_ids'] as List<dynamic>)
                .map((e) => e as String)
                .toList()
          : null,
    );
  }
}

/// Pose data from CV service
class PoseData {
  final double pitch;
  final double yaw;
  final double roll;
  final int gridIndex;

  PoseData({
    required this.pitch,
    required this.yaw,
    required this.roll,
    required this.gridIndex,
  });

  factory PoseData.fromJson(Map<String, dynamic> json) {
    return PoseData(
      pitch: (json['pitch'] as num).toDouble(),
      yaw: (json['yaw'] as num).toDouble(),
      roll: (json['roll'] as num).toDouble(),
      gridIndex: json['grid_index'] as int,
    );
  }
}
