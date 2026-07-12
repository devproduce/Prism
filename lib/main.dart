import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:provider/provider.dart';
import 'package:prism/screens/onboarding_screen.dart';
import 'package:prism/screens/splash_screen.dart';
import 'package:prism/screens/settings_screen.dart';
import 'package:prism/screens/edit_profile_screen.dart';
import 'package:prism/screens/blocked_users_screen.dart';
import 'package:prism/screens/help_support_screen.dart';
import 'package:prism/screens/share_upload_screen.dart';
import 'package:prism/utils/activity_feed_refresh.dart';
import 'package:prism/services/fcm_navigation_service.dart';
import 'package:prism/services/background_share_handler.dart';
import 'package:prism/screens/privacy_policy_screen.dart';
import 'package:prism/screens/about_screen.dart';
import 'package:prism/screens/feedback_screen.dart';
import 'package:prism/screens/processing_screen.dart';
import 'package:prism/theme/theme_data.dart';
import 'package:prism/providers/auth_provider.dart';
import 'package:prism/providers/gallery_provider.dart';
import 'package:prism/providers/profile_provider.dart';
import 'package:prism/providers/friends_provider.dart';
import 'package:prism/providers/activity_feed_provider.dart';
import 'package:prism/providers/sharing_provider.dart';
import 'package:prism/providers/theme_provider.dart';
import 'package:prism/services/auth_backend_capabilities.dart';
import 'package:prism/services/notification_service.dart';
import 'package:prism/services/local_notification_service.dart';
import 'package:prism/services/share_handler_service.dart';
import 'package:prism/screens/confirm_sharing_screen.dart';
import 'package:prism/providers/local_gallery_provider.dart';

import 'package:prism/utils/globals.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FCM notifications
  await NotificationService.initialize();
  await AuthBackendCapabilities.probe();

  // Initialize local notifications
  await LocalNotificationService().initialize(navigatorKey);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF000000),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  final ShareHandlerService _shareHandler = ShareHandlerService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupNotificationHandler();
    _setupImmediateDeepLinkListener();
    _checkPendingLocalNotificationPayload();
    _checkOfflineCompletedBatch();
  }

  Future<void> _checkOfflineCompletedBatch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('pending_review_batch_id')) {
        final pendingBatchId = prefs.getString('pending_review_batch_id');
        if (pendingBatchId != null && pendingBatchId.isNotEmpty) {
          debugPrint('📱 Found offline completed batch ID: $pendingBatchId. Routing to review...');
          await prefs.remove('pending_review_batch_id');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _navigateToRoute('/confirm_share', pendingBatchId, false);
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to check offline completed batch: $e');
    }
  }

  void _checkPendingLocalNotificationPayload() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingRaw = LocalNotificationService().pendingPayload;
      if (pendingRaw != null && pendingRaw.startsWith('REVIEW_READY:')) {
        final batchId = pendingRaw.substring('REVIEW_READY:'.length);
        LocalNotificationService().pendingPayload = null;
        debugPrint('📱 Handling stored notification launch with batch ID: $batchId');
        _navigateToRoute('/confirm_share', batchId, false);
      }
    });
  }

  void _setupNotificationHandler() {
    LocalNotificationService().onDidReceiveNotificationResponse = (response) {
      if (response.payload != null) {
        if (response.payload!.startsWith('REVIEW_READY:')) {
          final batchId = response.payload!.substring('REVIEW_READY:'.length);
          debugPrint('📱 Notification tapped with batch ID: $batchId');
          _navigateToRoute('/confirm_share', batchId, false);
        } else {
          // Handle FCM local background json payload
          try {
            final data = jsonDecode(response.payload!);
            ActivityFeedRefresh.refreshFromPush();
            FcmNavigationService.handle(data);
          } catch (e) {
            debugPrint('Failed to parse FCM payload: $e');
          }
        }
      }
    };

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 Notification tapped from background');
      ActivityFeedRefresh.refreshFromPush();
      FcmNavigationService.handle(message.data);
    });

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('📱 App launched from notification');
        Future.delayed(const Duration(milliseconds: 500), () {
          ActivityFeedRefresh.refreshFromPush();
          FcmNavigationService.handle(message.data);
        });
      }
    });
  }

  /// Setup listener for immediate deep link notifications from native.
  /// This is called when the user taps a notification and native notifies Flutter immediately.
  void _setupImmediateDeepLinkListener() {
    _shareHandler.setupDeepLinkListener((route, batchId, isProcessing) {
      debugPrint(
        '📱 Immediate deep link: route=$route, batchId=$batchId, isProcessing=$isProcessing',
      );
      _navigateToRoute(route, batchId, isProcessing);
    });
  }

  /// Navigate to the specified route immediately, removing intermediate screens.
  Future<void> _navigateToRoute(String route, String batchId, bool isProcessing) async {
    if (navigatorKey.currentState == null) {
      debugPrint('⚠️ Navigator not ready, storing deep link for later');
      return;
    }

    if (route == '/confirm_share' || route == '/processing') {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_review_batch_id');
      } catch (e) {
        debugPrint('Failed to clear pending_review_batch_id: $e');
      }
    }

    // Use pushNamedAndRemoveUntil to navigate directly without showing home first
    navigatorKey.currentState!.pushNamedAndRemoveUntil(
      route,
      (navRoute) =>
          navRoute.isFirst, // Keep only the first route (home) in stack
      arguments: {'batchId': batchId, 'isProcessing': isProcessing},
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Check for deep links and shared files when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _checkForPendingDeepLink();
      _checkForNewSharedFiles();
      ActivityFeedRefresh.refreshFromPush();
    }
  }

  /// Check for pending deep link from notification tap (fallback for cold start).
  /// This is called when app is opened from notification and native couldn't notify immediately.
  Future<void> _checkForPendingDeepLink() async {
    final deepLink = await _shareHandler.getPendingDeepLink();
    if (deepLink != null) {
      final route = deepLink['route'];
      final batchId = deepLink['batchId'];
      final isProcessing = deepLink['isProcessing'] == 'true';
      debugPrint(
        '📱 Pending deep link found: route=$route, batchId=$batchId, isProcessing=$isProcessing',
      );

      if (route != null && batchId != null) {
        // Navigate immediately without delay
        _navigateToRoute(route, batchId, isProcessing);
      }
    }
  }

  Future<void> _checkForNewSharedFiles() async {
    // Small delay to ensure the intent is processed
    await Future.delayed(const Duration(milliseconds: 300));

    final files = await _shareHandler.getSharedFiles();
    debugPrint('Lifecycle resumed - shared files: $files');

    if (files.isNotEmpty && navigatorKey.currentContext != null) {
      // Get providers from context
      final context = navigatorKey.currentContext!;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final sharingProvider = Provider.of<SharingProvider>(
        context,
        listen: false,
      );

      // Process files in background instead of navigating to UI
      await BackgroundShareHandler().checkAndProcessSharedFiles(
        authProvider: authProvider,
        sharingProvider: sharingProvider,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => GalleryProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => FriendsProvider()),
        ChangeNotifierProvider(create: (_) => ActivityFeedProvider()),
        ChangeNotifierProvider(create: (_) => SharingProvider()),
        ChangeNotifierProvider(create: (_) => LocalGalleryProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Prism',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const SplashScreen(),
            routes: {
              '/settings': (context) => const SettingsScreen(),
              '/onboarding': (context) => const OnboardingScreen(),
              '/profile': (context) => const EditProfileScreen(),
              '/blocked_users': (context) => const BlockedUsersScreen(),
              '/help_support': (context) => const HelpSupportScreen(),
              '/share': (context) => const ShareUploadScreen(),
              '/confirm_share': (context) {
                final args =
                    ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>?;
                return ConfirmSharingScreen(batchId: args?['batchId']);
              },
              '/processing': (context) {
                final args =
                    ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>?;
                return ProcessingScreen(batchId: args?['batchId']);
              },
              '/privacy_policy': (context) => const PrivacyPolicyScreen(),
              '/about': (context) => const AboutScreen(),
              '/feedback': (context) => const FeedbackScreen(),
            },
          );
        },
      ),
    );
  }
}
