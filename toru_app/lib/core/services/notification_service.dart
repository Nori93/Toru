import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Notification service for local alarms and reminders
/// Works completely offline using platform notification systems
class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  
  /// Initialize the notification service
  Future<void> initialize() async {
    try {
      debugPrint('🔔 Initializing Notification Service...');
      
      // Initialize timezone data
      tz.initializeTimeZones();
      
      // Android initialization settings
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization settings
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      
      // Combined initialization settings
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      // Initialize the plugin
      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );
      
      // Request permissions for iOS
      if (Platform.isIOS) {
        await _requestIOSPermissions();
      }
      
      // Request permissions for Android 13+
      if (Platform.isAndroid) {
        await _requestAndroidPermissions();
      }
      
      _isInitialized = true;
      debugPrint('✅ Notification Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize Notification Service: $e');
      rethrow;
    }
  }
  
  Future<void> _requestIOSPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }
  
  Future<void> _requestAndroidPermissions() async {
    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    await androidImplementation?.requestNotificationsPermission();
    await androidImplementation?.requestExactAlarmsPermission();
  }
  
  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Notification tapped: ${response.payload}');
    // Handle notification tap - navigate to appropriate screen
    // This would be implemented with a navigation callback
  }
  
  /// Schedule a one-time notification
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
  }) async {
    if (!_isInitialized) {
      throw StateError('Notification Service not initialized');
    }
    
    try {
      const androidDetails = AndroidNotificationDetails(
        'toru_reminders',
        'Reminders',
        channelDescription: 'Reminders and alarms',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      
      debugPrint('✅ Scheduled notification: $title at $scheduledTime');
    } catch (e) {
      debugPrint('❌ Failed to schedule notification: $e');
      rethrow;
    }
  }
  
  /// Schedule a recurring notification
  Future<void> scheduleRecurringNotification({
    required int id,
    required String title,
    required String body,
    required DateTime firstTime,
    required RepeatInterval interval,
    String? payload,
  }) async {
    if (!_isInitialized) {
      throw StateError('Notification Service not initialized');
    }
    
    try {
      const androidDetails = AndroidNotificationDetails(
        'toru_recurring',
        'Recurring Reminders',
        channelDescription: 'Recurring reminders and alarms',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      // For daily reminders at specific time
      if (interval == RepeatInterval.daily) {
        await _notifications.zonedSchedule(
          id,
          title,
          body,
          _nextInstanceOfTime(firstTime),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: payload,
        );
      } else {
        // For other intervals, use periodic notifications
        await _notifications.periodicallyShow(
          id,
          title,
          body,
          _convertToRepeatInterval(interval),
          details,
          payload: payload,
        );
      }
      
      debugPrint('✅ Scheduled recurring notification: $title');
    } catch (e) {
      debugPrint('❌ Failed to schedule recurring notification: $e');
      rethrow;
    }
  }
  
  /// Get next instance of a specific time
  tz.TZDateTime _nextInstanceOfTime(DateTime time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }
  
  RepeatInterval _convertToRepeatInterval(RepeatInterval interval) {
    // Direct mapping since we're using the same enum
    return interval;
  }
  
  /// Schedule a weekly notification
  Future<void> scheduleWeeklyNotification({
    required int id,
    required String title,
    required String body,
    required DateTime time,
    required int weekday, // 1-7, Monday-Sunday
    String? payload,
  }) async {
    if (!_isInitialized) {
      throw StateError('Notification Service not initialized');
    }
    
    try {
      const androidDetails = AndroidNotificationDetails(
        'toru_weekly',
        'Weekly Reminders',
        channelDescription: 'Weekly recurring reminders',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        _nextInstanceOfWeekday(time, weekday),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: payload,
      );
      
      debugPrint('✅ Scheduled weekly notification: $title');
    } catch (e) {
      debugPrint('❌ Failed to schedule weekly notification: $e');
      rethrow;
    }
  }
  
  tz.TZDateTime _nextInstanceOfWeekday(DateTime time, int weekday) {
    var scheduledDate = _nextInstanceOfTime(time);
    
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    return scheduledDate;
  }
  
  /// Show an immediate notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      throw StateError('Notification Service not initialized');
    }
    
    try {
      const androidDetails = AndroidNotificationDetails(
        'toru_instant',
        'Instant Notifications',
        channelDescription: 'Instant notifications',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      await _notifications.show(id, title, body, details, payload: payload);
      debugPrint('✅ Showed notification: $title');
    } catch (e) {
      debugPrint('❌ Failed to show notification: $e');
    }
  }
  
  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
    debugPrint('Cancelled notification: $id');
  }
  
  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
    debugPrint('Cancelled all notifications');
  }
  
  /// Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }
  
  bool get isInitialized => _isInitialized;
}

/// Repeat interval for recurring notifications
enum RepeatInterval {
  everyMinute,
  hourly,
  daily,
  weekly,
}
