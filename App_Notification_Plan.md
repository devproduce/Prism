# Mobile (Flutter) FCM Integration Plan

Complete guide for implementing push notifications in the Prism Flutter app via Firebase Cloud Messaging (HTTP v1).

---

> [!NOTE]
> **Backend Ready**  
> The FastAPI backend and Next.js web application have already been fully integrated with FCM. The backend `POST /notifications/device/register` and the Firebase Admin SDK are active. Your task is solely to implement the mobile-side receiving and token registration logic.

## Overview

| Component | Technology | Purpose |
|-----------|------------|---------|
| Mobile App | Flutter + `firebase_messaging` | Receive FCM notifications (Foreground/Background handling) |

---

## Part 1: Firebase Console Setup

### Step 1: Add Android App (This is already done on the Firebase console and file shared via WhatsApp)

1. Go to [Firebase Console](https://console.firebase.google.com/) for project `prism-app`.
2. Click **Android icon** in Project Overview
3. Enter package name: `com.prism.app` (match your `android/app/build.gradle`)
4. Download `google-services.json`
5. Place file in: `flutter_app/android/app/google-services.json`

### Step 2: Add iOS App ((This is already done on the Firebase console and file shared via WhatsApp))

1. Click **iOS icon** in Project Overview
2. Enter bundle ID: `com.prism.app`
3. Download `GoogleService-Info.plist`
4. Place in: `flutter_app/ios/Runner/GoogleService-Info.plist`
5. Enable **Push Notifications** in Xcode → Signing & Capabilities

---

## Part 2: Mobile App Implementation (Flutter)

### Payload Structure Expectation
When the backend triggers a notification, the Flutter app will receive a `RemoteMessage` structured like this:

```json
{
  "notification": {
    "title": "Batch Share Uploaded",
    "body": "You shared 12 images."
  },
  "data": {
    "type": "batch_share",
    "resource_id": "uuid-of-batch",
    "click_action": "FLUTTER_NOTIFICATION_CLICK"
  }
}
```
**Action:** Use the `data.type` and `data.resource_id` to route the user to the appropriate screen when they tap the notification.

### Step 1: Add Dependencies

```yaml
dependencies:
  firebase_core: ^2.24.0
  firebase_messaging: ^14.7.0
  flutter_local_notifications: ^17.0.0
  device_info_plus: ^10.0.0 # For getting a stable device_id
```

`flutter pub get`

### Step 2: Android Native Configuration

Your project uses Kotlin Script (`.kts`) for Gradle.

Update `flutter-app/android/settings.gradle.kts` by adding the google-services plugin:

```kotlin
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.7.3" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    // Add the following line:
    id("com.google.gms.google-services") version "4.4.2" apply false
}
```

Update `flutter-app/android/app/build.gradle.kts`:

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Add the google-services plugin here:
    id("com.google.gms.google-services")
}

android {
    defaultConfig {
        // Minimum SDK 21 required for FCM. 
        // If your flutter.minSdkVersion is lower, hardcode this to 21.
        minSdk = 21 
    }
}
```

### Step 3: iOS Native Configuration

Update `flutter-app/ios/Runner/AppDelegate.swift` to match your existing structure:

```swift
import Flutter
import UIKit
import FirebaseCore // Add this
import FirebaseMessaging // Add this

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure() // Add this
    
    // Register for push notifications natively
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    application.registerForRemoteNotifications() // Add this

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### Step 4: Initialize Firebase and Foreground Notifications

Create `lib/services/notification_service.dart`:

```dart
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Must be top-level pragmas to operate in Dart Isolates!
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling background FCM: ${message.messageId}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifs = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await Firebase.initializeApp();
    
    // Request permission (Android 13+ & iOS)
    await _messaging.requestPermission();

    // Foreground manual bridging (FCM doesn't pop system tray in foreground)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifs.initialize(const InitializationSettings(android: androidSettings));

    FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
      if (msg.notification != null) {
        _localNotifs.show(
          msg.hashCode,
          msg.notification!.title,
          msg.notification!.body,
          const NotificationDetails(
            android: AndroidNotificationDetails('high_importance_channel', 'High Importance', importance: Importance.high),
          ),
          payload: jsonEncode(msg.data),
        );
      }
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }
}
```

### Step 5: Token Synchronization with Stable Device ID

```dart
// After user logs in across your Auth context:
Future<void> registerDeviceToken() async {
  final token = await FirebaseMessaging.instance.getToken();
  // Use device_info_plus to get a UUID for the hardware
  final deviceId = await getStableDeviceId(); 

  if (token != null) {
    await apiClient.post('/notifications/device/register', data: {
      'user_id': auth.user.id,
      'device_id': deviceId,
      'fcm_token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
    });
  }

  // Handle intra-app token rotations automatically
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
    apiClient.post('/notifications/device/register', data: { /* UPSERT logic on backend catches it */ });
  });
}
```

---

## Security & Deployment Considerations

> [!CAUTION]
> - FCM background execution strictly requires `_firebaseMessagingBackgroundHandler` to be isolated and explicitly defined as `@pragma('vm:entry-point')`. Do NOT try to update flutter UI inside this block.
