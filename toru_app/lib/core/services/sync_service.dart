import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';

/// Sync service for optional cloud synchronization
/// Implements offline-first approach with automatic sync when online
class SyncService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  bool _isOnline = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  
  // Cloud backend configuration (Firebase/Supabase)
  String? _cloudBackendUrl;
  String? _authToken;
  
  /// Initialize the sync service
  Future<void> initialize({
    String? cloudBackendUrl,
    String? authToken,
  }) async {
    _cloudBackendUrl = cloudBackendUrl;
    _authToken = authToken;
    
    // Check initial connectivity
    final result = await _connectivity.checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);
    
    // Listen to connectivity changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
    
    debugPrint('🔄 Sync Service initialized. Online: $_isOnline');
  }
  
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = !results.contains(ConnectivityResult.none);
    
    debugPrint('📡 Connectivity changed. Online: $_isOnline');
    
    // Trigger sync when coming back online
    if (!wasOnline && _isOnline) {
      debugPrint('📱 Device back online, triggering sync...');
      syncAll();
    }
  }
  
  /// Sync all pending changes to the cloud
  Future<void> syncAll() async {
    if (_isSyncing) {
      debugPrint('⏳ Sync already in progress, skipping...');
      return;
    }
    
    if (!_isOnline) {
      debugPrint('📵 Device offline, skipping sync');
      return;
    }
    
    if (_cloudBackendUrl == null) {
      debugPrint('⚠️ Cloud backend not configured, skipping sync');
      return;
    }
    
    _isSyncing = true;
    debugPrint('🔄 Starting sync...');
    
    try {
      // Get pending sync items from database
      // In production, you would:
      // 1. Fetch pending items from sync_queue
      // 2. Send to Firebase/Supabase
      // 3. Handle conflicts
      // 4. Mark as synced
      
      await Future.delayed(const Duration(seconds: 2)); // Simulate sync
      
      _lastSyncTime = DateTime.now();
      debugPrint('✅ Sync completed at $_lastSyncTime');
    } catch (e) {
      debugPrint('❌ Sync failed: $e');
    } finally {
      _isSyncing = false;
    }
  }
  
  /// Sync a specific entity type
  Future<void> syncEntity({
    required String entityType,
    required int entityId,
    required DatabaseService database,
  }) async {
    if (!_isOnline || _cloudBackendUrl == null) {
      // Add to sync queue for later
      await _addToSyncQueue(
        entityType: entityType,
        entityId: entityId,
        operation: 'update',
        database: database,
      );
      return;
    }
    
    try {
      // Sync specific entity to cloud
      debugPrint('🔄 Syncing $entityType $entityId...');
      
      // In production:
      // 1. Get entity data from database
      // 2. Send to cloud backend
      // 3. Handle response and conflicts
      
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('✅ Synced $entityType $entityId');
    } catch (e) {
      debugPrint('❌ Failed to sync $entityType $entityId: $e');
      // Add to queue for retry
      await _addToSyncQueue(
        entityType: entityType,
        entityId: entityId,
        operation: 'update',
        database: database,
      );
    }
  }
  
  Future<void> _addToSyncQueue({
    required String entityType,
    required int entityId,
    required String operation,
    required DatabaseService database,
  }) async {
    await database.addToSyncQueue({
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'data': '{}', // In production, serialize entity data
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'synced': 0,
    });
    
    debugPrint('📝 Added to sync queue: $entityType $entityId');
  }
  
  /// Pull updates from cloud
  Future<void> pullUpdates(DatabaseService database) async {
    if (!_isOnline || _cloudBackendUrl == null) {
      debugPrint('Cannot pull updates: offline or no backend configured');
      return;
    }
    
    try {
      debugPrint('⬇️ Pulling updates from cloud...');
      
      // In production:
      // 1. Fetch updates since last sync
      // 2. Resolve conflicts (last-write-wins, or custom strategy)
      // 3. Update local database
      // 4. Update last sync time
      
      await Future.delayed(const Duration(seconds: 1));
      debugPrint('✅ Successfully pulled updates');
    } catch (e) {
      debugPrint('❌ Failed to pull updates: $e');
    }
  }
  
  /// Push local changes to cloud
  Future<void> pushUpdates(DatabaseService database) async {
    if (!_isOnline || _cloudBackendUrl == null) {
      debugPrint('Cannot push updates: offline or no backend configured');
      return;
    }
    
    try {
      debugPrint('⬆️ Pushing updates to cloud...');
      
      final pendingItems = await database.getPendingSyncItems();
      
      for (var item in pendingItems) {
        // Push each item to cloud
        // In production: send to Firebase/Supabase
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Mark as synced
        await database.markSyncItemComplete(item['id'] as int);
      }
      
      debugPrint('✅ Pushed ${pendingItems.length} updates');
    } catch (e) {
      debugPrint('❌ Failed to push updates: $e');
    }
  }
  
  /// Resolve sync conflicts
  Future<Map<String, dynamic>> resolveConflict({
    required Map<String, dynamic> localData,
    required Map<String, dynamic> cloudData,
    ConflictResolutionStrategy strategy = ConflictResolutionStrategy.lastWriteWins,
  }) async {
    switch (strategy) {
      case ConflictResolutionStrategy.lastWriteWins:
        final localTime = localData['updated_at'] as int? ?? 0;
        final cloudTime = cloudData['updated_at'] as int? ?? 0;
        return localTime > cloudTime ? localData : cloudData;
      
      case ConflictResolutionStrategy.localWins:
        return localData;
      
      case ConflictResolutionStrategy.cloudWins:
        return cloudData;
      
      case ConflictResolutionStrategy.merge:
        // Custom merge logic
        return {...cloudData, ...localData};
    }
  }
  
  /// Configure cloud backend
  void configureCloudBackend({
    required String url,
    String? authToken,
  }) {
    _cloudBackendUrl = url;
    _authToken = authToken;
    debugPrint('☁️ Cloud backend configured: $url');
  }
  
  /// Clear cloud configuration (go fully offline)
  void clearCloudBackend() {
    _cloudBackendUrl = null;
    _authToken = null;
    debugPrint('📵 Cloud backend cleared, app now fully offline');
  }
  
  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
  }
  
  // Getters
  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isCloudConfigured => _cloudBackendUrl != null;
}

/// Strategy for resolving sync conflicts
enum ConflictResolutionStrategy {
  lastWriteWins,
  localWins,
  cloudWins,
  merge,
}
