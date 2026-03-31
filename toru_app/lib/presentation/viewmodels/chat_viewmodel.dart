import 'package:flutter/foundation.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/database_service.dart';

/// ViewModel for chat screen
/// Manages chat state and AI interactions
class ChatViewModel extends ChangeNotifier {
  final AIService _aiService;
  final DatabaseService _databaseService;
  
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String _error = '';
  
  ChatViewModel({
    required AIService aiService,
    required DatabaseService databaseService,
  })  : _aiService = aiService,
        _databaseService = databaseService {
    _loadChatHistory();
  }
  
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _isLoading;
  String get error => _error;
  
  /// Load chat history from database
  Future<void> _loadChatHistory() async {
    try {
      final history = await _databaseService.getChatHistory(limit: 50);
      
      _messages.clear();
      for (var msg in history.reversed) {
        _messages.add(ChatMessage(
          id: msg['id'] as int,
          role: msg['role'] as String,
          content: msg['content'] as String,
          timestamp: DateTime.fromMillisecondsSinceEpoch(msg['timestamp'] as int),
        ));
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading chat history: $e');
    }
  }
  
  /// Send a message to the AI
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty) return;
    
    // Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch,
      role: 'user',
      content: content.trim(),
      timestamp: DateTime.now(),
    );
    
    _messages.add(userMessage);
    _isLoading = true;
    _error = '';
    notifyListeners();
    
    // Save user message to database
    await _databaseService.insertChatMessage({
      'role': 'user',
      'content': content.trim(),
      'timestamp': userMessage.timestamp.millisecondsSinceEpoch,
    });
    
    try {
      // Check if the message contains appointment/reminder information
      final extractedInfo = await _aiService.extractInformation(content);
      
      // Get relevant memories for context
      final memories = await _databaseService.getAllMemories();
      final relevantMemories = await _aiService.findRelevantMemories(
        content,
        memories,
      );
      
      // Generate AI response
      final response = await _aiService.generateResponse(
        content,
        context: relevantMemories,
      );
      
      // Add AI message
      final aiMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch,
        role: 'assistant',
        content: response,
        timestamp: DateTime.now(),
      );
      
      _messages.add(aiMessage);
      
      // Save AI message to database
      await _databaseService.insertChatMessage({
        'role': 'assistant',
        'content': response,
        'timestamp': aiMessage.timestamp.millisecondsSinceEpoch,
        'context_used': relevantMemories.join('|'),
      });
      
      // Handle extracted information (appointments, reminders, etc.)
      await _handleExtractedInformation(extractedInfo, content);
      
    } catch (e) {
      _error = 'Failed to get response: $e';
      debugPrint('Error sending message: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Handle extracted information from user input
  Future<void> _handleExtractedInformation(
    Map<String, dynamic> info,
    String originalText,
  ) async {
    final type = info['type'] as String?;
    
    if (type == 'appointment' && info['time_text'] != null) {
      // Save as memory for now
      await _databaseService.insertMemory({
        'type': 'appointment',
        'title': 'Appointment',
        'content': originalText,
        'tags': 'appointment',
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'importance': 8,
      });
    }
  }
  
  /// Clear chat history
  Future<void> clearHistory() async {
    try {
      await _databaseService.clearChatHistory();
      _messages.clear();
      _aiService.clearContext();
      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear history: $e';
      debugPrint('Error clearing history: $e');
    }
  }
  
  /// Regenerate last AI response
  Future<void> regenerateLastResponse() async {
    if (_messages.length < 2) return;
    
    // Remove last AI message
    if (_messages.last.role == 'assistant') {
      _messages.removeLast();
    }
    
    // Get last user message
    final lastUserMessage = _messages.lastWhere(
      (msg) => msg.role == 'user',
      orElse: () => _messages.last,
    );
    
    // Resend
    await sendMessage(lastUserMessage.content);
  }
}

/// Chat message model
class ChatMessage {
  final int id;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime timestamp;
  
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });
  
  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}
