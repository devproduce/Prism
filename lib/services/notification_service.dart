import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:prism/api/api_client.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:prism/services/local_notification_store.dart';
import 'package:prism/utils/activity_feed_refresh.dart';

// Must be top-level pragmas to operate in Dart Isolates!
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background FCM: ${message.messageId}');
  await LocalNotificationStore.saveNotification(message);
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifs = FlutterLocalNotificationsPlugin();
  static final ApiClient _apiClient = ApiClient();

  static Future<void> initialize() async {
    await Firebase.initializeApp();
    
    // Request permission (Android 13+ & iOS)
    await _messaging.requestPermission();

    // Foreground manual bridging (FCM doesn't pop system tray in foreground)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    
    await _localNotifs.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // Create a high importance channel for FCM (Android)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // name
      description: 'This channel is used for important push notifications.',
      importance: Importance.high,
    );

    final androidPlugin = _localNotifs.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);

    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      await LocalNotificationStore.saveNotification(msg);
      await ActivityFeedRefresh.refreshFromPush();
      if (msg.notification != null) {
        _localNotifs.show(
          msg.hashCode,
          msg.notification!.title,
          msg.notification!.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
          ),
          payload: jsonEncode(msg.data),
        );
      }
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  static Future<String?> getStableDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor;
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // Unique ID for Android hardware/build
    }
    return null;
  }

  static Future<void> registerDeviceToken(String userId) async {
    try {
      final token = await _messaging.getToken();
      final deviceId = await getStableDeviceId(); 

      if (token != null && deviceId != null) {
        await _apiClient.registerDeviceToken(
          deviceId: deviceId,
          fcmToken: token,
          platform: Platform.isIOS ? 'ios' : 'android',
        );
        debugPrint('FCM token registered successfully');
      }

      // Handle intra-app token rotations automatically
      _messaging.onTokenRefresh.listen((newToken) async {
        if (deviceId != null) {
          await _apiClient.registerDeviceToken(
            deviceId: deviceId,
            fcmToken: newToken,
            platform: Platform.isIOS ? 'ios' : 'android',
          );
          debugPrint('FCM token refreshed and registered');
        }
      });
    } catch (e) {
      debugPrint('Error registering device token: $e');
    }
  }
}
