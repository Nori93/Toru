import 'package:flutter/foundation.dart';
import '../../core/services/database_service.dart';
import '../../core/services/notification_service.dart';

/// ViewModel for reminders and alarms
/// Manages scheduled notifications and recurring reminders
class ReminderViewModel extends ChangeNotifier {
  final DatabaseService _databaseService;
  final NotificationService _notificationService;
  
  final List<Reminder> _reminders = [];
  bool _isLoading = false;
  String _error = '';
  
  ReminderViewModel({
    required DatabaseService databaseService,
    required NotificationService notificationService,
  })  : _databaseService = databaseService,
        _notificationService = notificationService {
    loadReminders();
  }
  
  List<Reminder> get reminders => List.unmodifiable(_reminders);
  List<Reminder> get activeReminders => 
      _reminders.where((r) => r.isActive).toList();
  bool get isLoading => _isLoading;
  String get error => _error;
  
  /// Load all reminders from database
  Future<void> loadReminders() async {
    _isLoading = true;
    _error = '';
    notifyListeners();
    
    try {
      final data = await _databaseService.getActiveReminders();
      
      _reminders.clear();
      for (var item in data) {
        _reminders.add(Reminder.fromMap(item));
      }
      
      debugPrint('Loaded ${_reminders.length} reminders');
    } catch (e) {
      _error = 'Failed to load reminders: $e';
      debugPrint('Error loading reminders: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Add a new reminder
  Future<void> addReminder({
    required String title,
    String? description,
    required DateTime time,
    bool isRecurring = false,
    String? recurrencePattern,
    String? category,
  }) async {
    try {
      final now = DateTime.now();
      
      final id = await _databaseService.insertReminder({
        'title': title,
        'description': description ?? '',
        'time': time.millisecondsSinceEpoch,
        'is_recurring': isRecurring ? 1 : 0,
        'recurrence_pattern': recurrencePattern ?? '',
        'is_active': 1,
        'category': category ?? 'general',
        'created_at': now.millisecondsSinceEpoch,
      });
      
      // Schedule notification
      if (isRecurring && recurrencePattern != null) {
        await _scheduleRecurringNotification(
          id: id,
          title: title,
          description: description ?? '',
          time: time,
          pattern: recurrencePattern,
        );
      } else {
        await _notificationService.scheduleNotification(
          id: id,
          title: title,
          body: description ?? 'Reminder',
          scheduledTime: time,
        );
      }
      
      await loadReminders();
      debugPrint('Added reminder: $title');
    } catch (e) {
      _error = 'Failed to add reminder: $e';
      debugPrint('Error adding reminder: $e');
      notifyListeners();
    }
  }
  
  Future<void> _scheduleRecurringNotification({
    required int id,
    required String title,
    required String description,
    required DateTime time,
    required String pattern,
  }) async {
    // Parse recurrence pattern (e.g., "daily", "weekly:monday", "monthly")
    if (pattern.toLowerCase() == 'daily') {
      await _notificationService.scheduleRecurringNotification(
        id: id,
        title: title,
        body: description,
        firstTime: time,
        interval: RepeatInterval.daily,
      );
    } else if (pattern.toLowerCase() == 'weekly') {
      await _notificationService.scheduleRecurringNotification(
        id: id,
        title: title,
        body: description,
        firstTime: time,
        interval: RepeatInterval.weekly,
      );
    } else if (pattern.startsWith('weekly:')) {
      final weekday = _parseWeekday(pattern.split(':')[1]);
      await _notificationService.scheduleWeeklyNotification(
        id: id,
        title: title,
        body: description,
        time: time,
        weekday: weekday,
      );
    }
  }
  
  int _parseWeekday(String day) {
    const weekdays = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };
    return weekdays[day.toLowerCase()] ?? 1;
  }
  
  /// Update a reminder
  Future<void> updateReminder({
    required int id,
    String? title,
    String? description,
    DateTime? time,
    bool? isActive,
  }) async {
    try {
      final reminder = _reminders.firstWhere((r) => r.id == id);
      
      final updatedData = {
        'title': title ?? reminder.title,
        'description': description ?? reminder.description,
        'time': (time ?? reminder.time).millisecondsSinceEpoch,
        'is_active': (isActive ?? reminder.isActive) ? 1 : 0,
      };
      
      await _databaseService.updateReminder(id, updatedData);
      
      // Update notification
      if (isActive == false) {
        await _notificationService.cancelNotification(id);
      } else if (time != null) {
        await _notificationService.cancelNotification(id);
        await _notificationService.scheduleNotification(
          id: id,
          title: title ?? reminder.title,
          body: description ?? reminder.description,
          scheduledTime: time,
        );
      }
      
      await loadReminders();
      debugPrint('Updated reminder: $id');
    } catch (e) {
      _error = 'Failed to update reminder: $e';
      debugPrint('Error updating reminder: $e');
      notifyListeners();
    }
  }
  
  /// Delete a reminder
  Future<void> deleteReminder(int id) async {
    try {
      await _databaseService.deleteReminder(id);
      await _notificationService.cancelNotification(id);
      
      _reminders.removeWhere((r) => r.id == id);
      notifyListeners();
      
      debugPrint('Deleted reminder: $id');
    } catch (e) {
      _error = 'Failed to delete reminder: $e';
      debugPrint('Error deleting reminder: $e');
      notifyListeners();
    }
  }
  
  /// Toggle reminder active state
  Future<void> toggleReminder(int id) async {
    try {
      final reminder = _reminders.firstWhere((r) => r.id == id);
      await updateReminder(id: id, isActive: !reminder.isActive);
    } catch (e) {
      _error = 'Failed to toggle reminder: $e';
      debugPrint('Error toggling reminder: $e');
      notifyListeners();
    }
  }
  
  /// Get reminders by category
  List<Reminder> getRemindersByCategory(String category) {
    return _reminders.where((r) => r.category == category).toList();
  }
  
  /// Get upcoming reminders (next 24 hours)
  List<Reminder> getUpcomingReminders() {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    
    return _reminders
        .where((r) => r.isActive && r.time.isAfter(now) && r.time.isBefore(tomorrow))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }
}

/// Reminder model
class Reminder {
  final int id;
  final String title;
  final String description;
  final DateTime time;
  final bool isRecurring;
  final String recurrencePattern;
  final bool isActive;
  final String category;
  final DateTime createdAt;
  
  Reminder({
    required this.id,
    required this.title,
    required this.description,
    required this.time,
    required this.isRecurring,
    required this.recurrencePattern,
    required this.isActive,
    required this.category,
    required this.createdAt,
  });
  
  factory Reminder.fromMap(Map<String, dynamic> map) {
    return Reminder(
      id: map['id'] as int,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      time: DateTime.fromMillisecondsSinceEpoch(map['time'] as int),
      isRecurring: (map['is_recurring'] as int?) == 1,
      recurrencePattern: map['recurrence_pattern'] as String? ?? '',
      isActive: (map['is_active'] as int?) == 1,
      category: map['category'] as String? ?? 'general',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'time': time.millisecondsSinceEpoch,
      'is_recurring': isRecurring ? 1 : 0,
      'recurrence_pattern': recurrencePattern,
      'is_active': isActive ? 1 : 0,
      'category': category,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }
  
  String get formattedTime {
    final hour = time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }
}
