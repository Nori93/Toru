import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Database service for local storage using SQLite
/// Handles all database operations for memories, notes, appointments, and chat history
class DatabaseService {
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  /// Initialize the database
  Future<void> initialize() async {
    await database;
  }
  
  /// Initialize database for desktop platforms (Windows, Linux)
  Future<void> initializeDesktop() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }
  
  Future<Database> _initDatabase() async {
    String path;
    
    if (kIsWeb) {
      // Web doesn't support SQLite, would need alternative
      throw UnsupportedError('SQLite not supported on web');
    } else if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      path = join(directory.path, 'toru_database.db');
    } else {
      // Desktop platforms
      final directory = await getApplicationSupportDirectory();
      path = join(directory.path, 'toru_database.db');
    }
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }
  
  /// Create database schema
  Future<void> _createDatabase(Database db, int version) async {
    // Chat messages table
    await db.execute('''
      CREATE TABLE chat_messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        context_used TEXT
      )
    ''');
    
    // Memories table - stores facts, notes, and information
    await db.execute('''
      CREATE TABLE memories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        embedding TEXT,
        tags TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        importance INTEGER DEFAULT 5
      )
    ''');
    
    // Appointments table
    await db.execute('''
      CREATE TABLE appointments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        location TEXT,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        reminder_time INTEGER,
        created_at INTEGER NOT NULL,
        is_recurring INTEGER DEFAULT 0,
        recurrence_pattern TEXT
      )
    ''');
    
    // Reminders/Alarms table
    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        time INTEGER NOT NULL,
        is_recurring INTEGER DEFAULT 0,
        recurrence_pattern TEXT,
        is_active INTEGER DEFAULT 1,
        category TEXT,
        created_at INTEGER NOT NULL,
        last_triggered INTEGER
      )
    ''');
    
    // Saved routes table
    await db.execute('''
      CREATE TABLE saved_routes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_location TEXT NOT NULL,
        end_location TEXT NOT NULL,
        waypoints TEXT,
        distance REAL,
        duration INTEGER,
        created_at INTEGER NOT NULL,
        last_used INTEGER
      )
    ''');
    
    // Sync queue table for offline-first sync
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        synced INTEGER DEFAULT 0
      )
    ''');
    
    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_chat_timestamp ON chat_messages(timestamp)');
    await db.execute('CREATE INDEX idx_memories_created ON memories(created_at)');
    await db.execute('CREATE INDEX idx_appointments_start ON appointments(start_time)');
    await db.execute('CREATE INDEX idx_reminders_time ON reminders(time)');
    await db.execute('CREATE INDEX idx_sync_queue_synced ON sync_queue(synced)');
  }
  
  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
    if (oldVersion < newVersion) {
      // Add migration logic as needed
    }
  }
  
  // ==================== Chat Messages ====================
  
  Future<int> insertChatMessage(Map<String, dynamic> message) async {
    final db = await database;
    return await db.insert('chat_messages', message);
  }
  
  Future<List<Map<String, dynamic>>> getChatHistory({int limit = 50}) async {
    final db = await database;
    return await db.query(
      'chat_messages',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }
  
  Future<void> clearChatHistory() async {
    final db = await database;
    await db.delete('chat_messages');
  }
  
  // ==================== Memories ====================
  
  Future<int> insertMemory(Map<String, dynamic> memory) async {
    final db = await database;
    return await db.insert('memories', memory);
  }
  
  Future<List<Map<String, dynamic>>> getAllMemories() async {
    final db = await database;
    return await db.query('memories', orderBy: 'created_at DESC');
  }
  
  Future<List<Map<String, dynamic>>> searchMemories(String query) async {
    final db = await database;
    return await db.query(
      'memories',
      where: 'title LIKE ? OR content LIKE ? OR tags LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'importance DESC, created_at DESC',
    );
  }
  
  Future<int> updateMemory(int id, Map<String, dynamic> memory) async {
    final db = await database;
    return await db.update(
      'memories',
      memory,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<int> deleteMemory(int id) async {
    final db = await database;
    return await db.delete('memories', where: 'id = ?', whereArgs: [id]);
  }
  
  // ==================== Appointments ====================
  
  Future<int> insertAppointment(Map<String, dynamic> appointment) async {
    final db = await database;
    return await db.insert('appointments', appointment);
  }
  
  Future<List<Map<String, dynamic>>> getUpcomingAppointments() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.query(
      'appointments',
      where: 'start_time >= ?',
      whereArgs: [now],
      orderBy: 'start_time ASC',
    );
  }
  
  Future<List<Map<String, dynamic>>> getAppointmentsByDate(DateTime date) async {
    final db = await database;
    final startOfDay = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59).millisecondsSinceEpoch;
    
    return await db.query(
      'appointments',
      where: 'start_time BETWEEN ? AND ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'start_time ASC',
    );
  }
  
  Future<int> updateAppointment(int id, Map<String, dynamic> appointment) async {
    final db = await database;
    return await db.update(
      'appointments',
      appointment,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<int> deleteAppointment(int id) async {
    final db = await database;
    return await db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }
  
  // ==================== Reminders ====================
  
  Future<int> insertReminder(Map<String, dynamic> reminder) async {
    final db = await database;
    return await db.insert('reminders', reminder);
  }
  
  Future<List<Map<String, dynamic>>> getActiveReminders() async {
    final db = await database;
    return await db.query(
      'reminders',
      where: 'is_active = 1',
      orderBy: 'time ASC',
    );
  }
  
  Future<List<Map<String, dynamic>>> getRemindersDue() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.query(
      'reminders',
      where: 'is_active = 1 AND time <= ?',
      whereArgs: [now],
      orderBy: 'time ASC',
    );
  }
  
  Future<int> updateReminder(int id, Map<String, dynamic> reminder) async {
    final db = await database;
    return await db.update(
      'reminders',
      reminder,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<int> deleteReminder(int id) async {
    final db = await database;
    return await db.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }
  
  // ==================== Saved Routes ====================
  
  Future<int> insertRoute(Map<String, dynamic> route) async {
    final db = await database;
    return await db.insert('saved_routes', route);
  }
  
  Future<List<Map<String, dynamic>>> getSavedRoutes() async {
    final db = await database;
    return await db.query('saved_routes', orderBy: 'last_used DESC');
  }
  
  Future<int> updateRoute(int id, Map<String, dynamic> route) async {
    final db = await database;
    return await db.update(
      'saved_routes',
      route,
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<int> deleteRoute(int id) async {
    final db = await database;
    return await db.delete('saved_routes', where: 'id = ?', whereArgs: [id]);
  }
  
  // ==================== Sync Queue ====================
  
  Future<int> addToSyncQueue(Map<String, dynamic> syncItem) async {
    final db = await database;
    return await db.insert('sync_queue', syncItem);
  }
  
  Future<List<Map<String, dynamic>>> getPendingSyncItems() async {
    final db = await database;
    return await db.query(
      'sync_queue',
      where: 'synced = 0',
      orderBy: 'created_at ASC',
    );
  }
  
  Future<int> markSyncItemComplete(int id) async {
    final db = await database;
    return await db.update(
      'sync_queue',
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> clearSyncQueue() async {
    final db = await database;
    await db.delete('sync_queue', where: 'synced = 1');
  }
  
  // ==================== Utility Methods ====================
  
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
  
  Future<void> deleteDatabase() async {
    String path;
    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      path = join(directory.path, 'toru_database.db');
    } else {
      final directory = await getApplicationSupportDirectory();
      path = join(directory.path, 'toru_database.db');
    }
    await databaseFactory.deleteDatabase(path);
  }
}
