import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

// Top-level global function required for handling background messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling background message: ${message.messageId}");
}

/// Top-level handler for notification taps when the app was fully terminated.
@pragma('vm:entry-point')
void _onBackgroundNotificationTap(NotificationResponse response) {
  debugPrint('Background notification tap (cold-launch): ${response.payload}');
}

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Callback invoked when the user taps a local notification.
  /// Set this in main.dart to handle navigation (e.g., open duplicates page).
  static void Function(String payload)? onNotificationTap;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
  );

  static const AndroidNotificationChannel _duplicateChannel =
      AndroidNotificationChannel(
    'duplicate_scan_channel',
    'Duplicate Scan Results',
    description: 'Notifies you when a background duplicate photo scan is complete.',
    importance: Importance.defaultImportance,
  );

  static const AndroidNotificationChannel _memoriesChannel =
      AndroidNotificationChannel(
    'memories_channel',
    'On This Day Memories',
    description: 'Daily memories from your photo library — photos from this day in past years.',
    importance: Importance.defaultImportance,
  );

  static Future<void> initialize() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("Local notification tapped: ${response.payload}");
          if (response.payload != null && response.payload!.isNotEmpty) {
            onNotificationTap?.call(response.payload!);
          }
        },
        onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
      );

      final platform = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (platform != null) {
        await platform.createNotificationChannel(_channel);
        await platform.createNotificationChannel(_duplicateChannel);
        await platform.createNotificationChannel(_memoriesChannel);
      }

      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          _localNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                icon: android.smallIcon ?? '@mipmap/ic_launcher',
              ),
            ),
            payload: message.data.toString(),
          );
        }
      });

      debugPrint("NotificationService successfully initialized.");
    } catch (e) {
      debugPrint("NotificationService initialization failed: $e");
    }
  }

  static Future<void> requestPermissions() async {
    try {
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('Notification permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint("Error requesting notification permissions: $e");
    }
  }

  static Future<String?> getFCMToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      debugPrint("FCM Token: $token");
      return token;
    } catch (e) {
      debugPrint("Error fetching FCM token: $e");
      return null;
    }
  }

  /// Shows a local notification when a background duplicate scan completes.
  /// Uses fixed ID 42 so repeated scans replace (not stack) old notifications.
  static Future<void> showDuplicateFoundNotification(int count) async {
    final String body = count == 1
        ? 'Found 1 group of duplicate photos. Tap to review and free up space.'
        : 'Found $count groups of duplicate photos. Tap to review and free up space.';

    await _localNotificationsPlugin.show(
      42,
      'Duplicate Photos Found',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'duplicate_scan_channel',
          'Duplicate Scan Results',
          channelDescription:
              'Notifies you when a background duplicate photo scan is complete.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: 'open_duplicates',
    );
  }

  /// Shows an "On This Day" memories notification.
  ///
  /// [year] is the year the photos were taken.
  /// [count] is how many photos were found on this day in that year.
  /// [isoDate] is the full ISO date string (e.g. "2022-07-23") used as the
  /// tap payload so the app can open the gallery filtered to that exact date.
  ///
  /// Uses fixed ID 43 so only one memories notification exists at a time.
  static Future<void> showMemoriesNotification({
    required int year,
    required int count,
    required String isoDate,
  }) async {
    final yearsAgo = DateTime.now().year - year;
    final String yearsAgoText = yearsAgo == 1 ? '1 year ago' : '$yearsAgo years ago';
    final String title = '📸 A memory from $yearsAgoText';
    final String body = count == 1
        ? 'You had 1 photo on this day in $year — tap to relive it.'
        : 'You had $count photos on this day in $year — tap to relive them.';

    await _localNotificationsPlugin.show(
      43, // Fixed ID: replaces previous memories notification (no stacking)
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'memories_channel',
          'On This Day Memories',
          channelDescription:
              'Daily memories from your photo library — photos from this day in past years.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: 'open_memories:$isoDate',
    );

    debugPrint('[Memories] Notification shown: $count photos from $year ($isoDate)');
  }
}

