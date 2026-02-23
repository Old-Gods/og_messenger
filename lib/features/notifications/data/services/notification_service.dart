import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service for managing local notifications
class NotificationService {
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionGranted = false;

  NotificationService._();

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // macOS initialization settings
    const macosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macosSettings,
    );

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    _initialized = true;
  }

  /// Request notification permissions (iOS/macOS)
  Future<bool> requestPermissions() async {
    if (!_initialized) await initialize();

    if (Platform.isIOS || Platform.isMacOS) {
      final result = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      _permissionGranted = result ?? false;
      return _permissionGranted;
    } else if (Platform.isAndroid) {
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      final granted = await androidImplementation
          ?.requestNotificationsPermission();
      _permissionGranted = granted ?? false;
      return _permissionGranted;
    }

    return false;
  }

  /// Show a notification for a join request
  Future<void> showJoinRequestNotification({
    required String requesterName,
    required String roomName,
    required String requestId,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'join_requests',
      'Join Requests',
      channelDescription: 'Room join request notifications',
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const macosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: macosDetails,
    );

    await _plugin.show(
      id: requestId.hashCode,
      title: '🔔 Join Request',
      body: '$requesterName wants to join $roomName',
      notificationDetails: notificationDetails,
      payload: requestId,
    );
  }

  /// Show a notification when join request is accepted
  Future<void> showJoinAcceptedNotification({
    required String roomName,
    required String roomId,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'join_accepted',
      'Join Accepted',
      channelDescription: 'Room join accepted notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const macosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: macosDetails,
    );

    await _plugin.show(
      id: roomId.hashCode,
      title: '✅ Welcome!',
      body: 'You\'ve been accepted into $roomName. Tap to view in My Rooms.',
      notificationDetails: notificationDetails,
      payload: roomId,
    );
  }

  /// Show a notification for a new message
  Future<void> showMessageNotification({
    required String senderName,
    required String messageContent,
    required String messageId,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'messages',
      'Messages',
      channelDescription: 'New message notifications',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const macosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: macosDetails,
    );

    await _plugin.show(
      id: messageId.hashCode, // Use message ID hash as notification ID
      title: senderName,
      body: messageContent,
      notificationDetails: notificationDetails,
      payload: messageId,
    );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    // TODO: Navigate to chat with specific message
    // This will be implemented when navigation is set up
  }

  /// Create a notification channel for a room (Android)
  /// TODO: Implement per-room notification channels in Step 18
  Future<void> createRoomChannel(String roomId, String roomName) async {
    if (!_initialized) await initialize();
    
    if (Platform.isAndroid) {
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      
      await androidImplementation?.createNotificationChannel(
        AndroidNotificationChannel(
          'room_$roomId',
          'Room: $roomName',
          description: 'Messages from $roomName',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Delete a notification channel for a room (Android)
  /// TODO: Implement per-room notification cleanup in Step 18
  Future<void> deleteRoomChannel(String roomId) async {
    if (Platform.isAndroid) {
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      
      await androidImplementation?.deleteNotificationChannel(channelId: 'room_$roomId');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Cancel a specific notification
  Future<void> cancel(int id) async {
    await _plugin.cancel(id: id);
  }

  /// Check if notifications are enabled
  bool get areNotificationsEnabled => _permissionGranted;
}
