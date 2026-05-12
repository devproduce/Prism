import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:prism/models/notification_model.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class LocalNotificationStore {
  static const String _key = 'local_recent_notifications';
  static const int _maxLimit = 10;

  static Future<void> saveNotification(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    
    // We treat the FCM message as a NotificationModel
    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    final data = message.data;
    
    // Build JSON representation
    final notifJson = {
      'id': message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'type': data['type'] ?? 'unknown',
      'message': body.isNotEmpty ? body : title,
      'title': title,
      'user_id': data['sender_id'],
      'username': data['sender_username'],
      // FCM doesn't pass profile_pic_id but we can pass it if we add it, otherwise null
      'resource_id': data['resource_id'],
      'created_at': data['timestamp'] ?? DateTime.now().toIso8601String(),
      'is_read': false,
      'route': data['route'],
      'route_tab': data['route_tab'],
      'metadata': data,
    };

    List<String> rawNotifications = prefs.getStringList(_key) ?? [];
    
    // Add explicitly at the beginning
    rawNotifications.insert(0, jsonEncode(notifJson));
    
    // Keep only last 10
    if (rawNotifications.length > _maxLimit) {
      rawNotifications = rawNotifications.sublist(0, _maxLimit);
    }
    
    await prefs.setStringList(_key, rawNotifications);
  }

  static Future<List<NotificationModel>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawStrings = prefs.getStringList(_key) ?? [];
    
    final List<NotificationModel> result = [];
    for (String raw in rawStrings) {
      try {
        final decoded = jsonDecode(raw);
        result.add(NotificationModel.fromJson(decoded));
      } catch (e) {
        // Skip corrupted entries
      }
    }
    return result;
  }
  
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
