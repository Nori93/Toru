import 'package:flutter/foundation.dart';
import '../../core/services/database_service.dart';

/// ViewModel for memory management
/// Handles notes, facts, and stored information
class MemoryViewModel extends ChangeNotifier {
  final DatabaseService _databaseService;
  
  final List<Memory> _memories = [];
  bool _isLoading = false;
  String _error = '';
  String _searchQuery = '';
  
  MemoryViewModel({
    required DatabaseService databaseService,
  }) : _databaseService = databaseService {
    loadMemories();
  }
  
  List<Memory> get memories => List.unmodifiable(_memories);
  bool get isLoading => _isLoading;
  String get error => _error;
  String get searchQuery => _searchQuery;
  
  /// Load all memories from database
  Future<void> loadMemories() async {
    _isLoading = true;
    _error = '';
    notifyListeners();
    
    try {
      final data = await _databaseService.getAllMemories();
      
      _memories.clear();
      for (var item in data) {
        _memories.add(Memory.fromMap(item));
      }
      
      debugPrint('Loaded ${_memories.length} memories');
    } catch (e) {
      _error = 'Failed to load memories: $e';
      debugPrint('Error loading memories: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Search memories
  Future<void> searchMemories(String query) async {
    _searchQuery = query;
    
    if (query.trim().isEmpty) {
      await loadMemories();
      return;
    }
    
    _isLoading = true;
    _error = '';
    notifyListeners();
    
    try {
      final data = await _databaseService.searchMemories(query);
      
      _memories.clear();
      for (var item in data) {
        _memories.add(Memory.fromMap(item));
      }
      
      debugPrint('Found ${_memories.length} memories matching "$query"');
    } catch (e) {
      _error = 'Failed to search memories: $e';
      debugPrint('Error searching memories: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Add a new memory
  Future<void> addMemory({
    required String type,
    required String title,
    required String content,
    List<String>? tags,
    int importance = 5,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      final id = await _databaseService.insertMemory({
        'type': type,
        'title': title,
        'content': content,
        'tags': tags?.join(',') ?? '',
        'created_at': now,
        'updated_at': now,
        'importance': importance,
      });
      
      // Reload memories
      await loadMemories();
      
      debugPrint('Added memory: $title');
    } catch (e) {
      _error = 'Failed to add memory: $e';
      debugPrint('Error adding memory: $e');
      notifyListeners();
    }
  }
  
  /// Update a memory
  Future<void> updateMemory({
    required int id,
    String? title,
    String? content,
    List<String>? tags,
    int? importance,
  }) async {
    try {
      final memory = _memories.firstWhere((m) => m.id == id);
      
      final updatedData = {
        'title': title ?? memory.title,
        'content': content ?? memory.content,
        'tags': (tags ?? memory.tags).join(','),
        'importance': importance ?? memory.importance,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      };
      
      await _databaseService.updateMemory(id, updatedData);
      await loadMemories();
      
      debugPrint('Updated memory: $id');
    } catch (e) {
      _error = 'Failed to update memory: $e';
      debugPrint('Error updating memory: $e');
      notifyListeners();
    }
  }
  
  /// Delete a memory
  Future<void> deleteMemory(int id) async {
    try {
      await _databaseService.deleteMemory(id);
      _memories.removeWhere((m) => m.id == id);
      notifyListeners();
      
      debugPrint('Deleted memory: $id');
    } catch (e) {
      _error = 'Failed to delete memory: $e';
      debugPrint('Error deleting memory: $e');
      notifyListeners();
    }
  }
  
  /// Get memories by type
  List<Memory> getMemoriesByType(String type) {
    return _memories.where((m) => m.type == type).toList();
  }
  
  /// Get memories by tag
  List<Memory> getMemoriesByTag(String tag) {
    return _memories.where((m) => m.tags.contains(tag)).toList();
  }
  
  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    loadMemories();
  }
}

/// Memory model
class Memory {
  final int id;
  final String type;
  final String title;
  final String content;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int importance;
  
  Memory({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.importance,
  });
  
  factory Memory.fromMap(Map<String, dynamic> map) {
    return Memory(
      id: map['id'] as int,
      type: map['type'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      tags: (map['tags'] as String?)?.split(',').where((t) => t.isNotEmpty).toList() ?? [],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      importance: map['importance'] as int? ?? 5,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'content': content,
      'tags': tags.join(','),
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'importance': importance,
    };
  }
}
