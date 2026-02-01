import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class LocalNotificationService {
  static final LocalNotificationService _instance =
      LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // External notification response handler (can be set by main.dart)
  void Function(NotificationResponse)? onDidReceiveNotificationResponse;

  // Channels
  static const String _uploadChannelId = 'upload_channel';
  static const String _uploadChannelName = 'Upload Progress';
  static const String _uploadChannelDesc =
      'Shows upload progress during media sharing';

  // High-priority channel for completion notifications (heads-up display)
  static const String _completionChannelId = 'completion_channel';
  static const String _completionChannelName = 'Share Complete';
  static const String _completionChannelDesc =
      'Notifies when shared media is ready for review';

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Call external handler if set
        if (onDidReceiveNotificationResponse != null) {
          onDidReceiveNotificationResponse!(response);
          return;
        }

        // Fallback handler
        if (response.payload != null &&
            response.payload!.startsWith('REVIEW_READY:')) {
          final batchId = response.payload!.substring('REVIEW_READY:'.length);
          if (navigatorKey.currentState != null) {
            navigatorKey.currentState!.pushNamed(
              '/confirm_share',
              arguments: {'batchId': batchId},
            );
          }
        }
      },
    );

    // Check if app was launched by notification
    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await _flutterLocalNotificationsPlugin
            .getNotificationAppLaunchDetails();

    if (notificationAppLaunchDetails != null &&
        notificationAppLaunchDetails.didNotificationLaunchApp &&
        notificationAppLaunchDetails.notificationResponse?.payload != null) {
      final payload =
          notificationAppLaunchDetails.notificationResponse!.payload!;

      // Parse batch ID from payload if it's a review notification
      if (payload.startsWith('REVIEW_READY:')) {
        final batchId = payload.substring('REVIEW_READY:'.length);
        debugPrint('📱 App launched from notification with batch ID: $batchId');
        // Store for later navigation (will be handled by main.dart)
      }
    }

    final androidPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    // Create low-priority channel for progress updates (no sound)
    const AndroidNotificationChannel uploadChannel = AndroidNotificationChannel(
      _uploadChannelId,
      _uploadChannelName,
      description: _uploadChannelDesc,
      importance: Importance.low, // Low to avoid sound spam during upload
      showBadge: false,
      playSound: false,
      enableVibration: false,
    );
    await androidPlugin?.createNotificationChannel(uploadChannel);

    // Create high-priority channel for completion (heads-up with sound)
    const AndroidNotificationChannel completionChannel =
        AndroidNotificationChannel(
          _completionChannelId,
          _completionChannelName,
          description: _completionChannelDesc,
          importance: Importance.high, // High for heads-up display
          showBadge: true,
          playSound: true, // Play notification sound
          enableVibration: true, // Enable vibration
        );
    await androidPlugin?.createNotificationChannel(completionChannel);
  }

  Future<void> showProgressNotification({
    required int id,
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _uploadChannelId,
          _uploadChannelName,
          channelDescription: _uploadChannelDesc,
          importance: Importance.low,
          priority: Priority.low,
          onlyAlertOnce: true,
          showProgress: true,
          maxProgress: maxProgress,
          progress: progress,
          ongoing: true, // Prevent dismissal while uploading
          autoCancel: false,
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> showCompletionNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    // Use high-priority completion channel for heads-up notification
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _completionChannelId, // Use completion channel for heads-up
          _completionChannelName,
          channelDescription: _completionChannelDesc,
          importance: Importance.high, // Required for heads-up display
          priority: Priority.high,
          onlyAlertOnce: false,
          showProgress: false,
          ongoing: false,
          autoCancel: true,
          playSound: true, // Enable sound
          enableVibration: true, // Enable vibration
          fullScreenIntent: true, // Maximum visibility
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Show error notification with high priority
  Future<void> showErrorNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          _completionChannelId, // Use completion channel for visibility
          _completionChannelName,
          channelDescription: _completionChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          onlyAlertOnce: false,
          showProgress: false,
          ongoing: false,
          autoCancel: true,
          playSound: true,
          enableVibration: true,
          color: const Color(0xFFE53935), // Red color for error
        );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
    );
  }

  Future<void> cancel(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }
}
