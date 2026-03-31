import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

/// AI Service for local LLM inference using llama.cpp
/// Provides offline AI capabilities with context memory
class AIService {
  // Simulated AI service - in production, this would use llama.cpp bindings
  // For Flutter, you would use FFI to call native llama.cpp libraries
  
  bool _isInitialized = false;
  String? _modelPath;
  final List<Map<String, String>> _conversationContext = [];
  final int _maxContextLength = 20;
  
  // Simple embedding store for semantic search
  final Map<String, List<double>> _embeddings = {};
  
  /// Initialize the AI service and load the model
  Future<void> initialize() async {
    try {
      debugPrint('🤖 Initializing AI Service...');
      
      // Get the models directory path
      _modelPath = await _getModelPath();
      
      // In production, you would:
      // 1. Load llama.cpp model from assets or downloaded location
      // 2. Initialize the model with llama_cpp_dart bindings
      // 3. Set up tokenizer and context
      
      // Example pseudo-code for actual implementation:
      // _llamaContext = await LlamaCpp.initialize(
      //   modelPath: _modelPath,
      //   contextSize: 2048,
      //   numThreads: 4,
      // );
      
      _isInitialized = true;
      debugPrint('✅ AI Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize AI Service: $e');
      rethrow;
    }
  }
  
  Future<String> _getModelPath() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      return join(directory.path, 'models', 'toru-model.gguf');
    } else {
      final directory = await getApplicationSupportDirectory();
      return join(directory.path, 'models', 'toru-model.gguf');
    }
  }
  
  /// Generate a response from the AI model
  /// This is where you'd call llama.cpp to generate text
  Future<String> generateResponse(String prompt, {List<String>? context}) async {
    if (!_isInitialized) {
      throw StateError('AI Service not initialized');
    }
    
    try {
      // Build the full prompt with context
      final fullPrompt = _buildPromptWithContext(prompt, context);
      
      // In production, this would call llama.cpp:
      // final response = await _llamaContext.generate(
      //   prompt: fullPrompt,
      //   maxTokens: 256,
      //   temperature: 0.7,
      //   topP: 0.9,
      // );
      
      // For now, return a simulated response
      final response = await _simulateAIResponse(fullPrompt);
      
      // Store in conversation context
      _conversationContext.add({'role': 'user', 'content': prompt});
      _conversationContext.add({'role': 'assistant', 'content': response});
      
      // Keep context manageable
      if (_conversationContext.length > _maxContextLength) {
        _conversationContext.removeRange(0, 2);
      }
      
      return response;
    } catch (e) {
      debugPrint('❌ Error generating AI response: $e');
      return 'Sorry, I encountered an error processing your request.';
    }
  }
  
  String _buildPromptWithContext(String prompt, List<String>? additionalContext) {
    final buffer = StringBuffer();
    
    // System prompt
    buffer.writeln('You are Toru, a helpful and energetic AI assistant.');
    buffer.writeln('You help users with their daily tasks, appointments, and questions.');
    buffer.writeln();
    
    // Add memory context if provided
    if (additionalContext != null && additionalContext.isNotEmpty) {
      buffer.writeln('Relevant memories:');
      for (var context in additionalContext) {
        buffer.writeln('- $context');
      }
      buffer.writeln();
    }
    
    // Add recent conversation history
    if (_conversationContext.isNotEmpty) {
      buffer.writeln('Recent conversation:');
      for (var message in _conversationContext.take(10)) {
        buffer.writeln('${message['role']}: ${message['content']}');
      }
      buffer.writeln();
    }
    
    // Current prompt
    buffer.writeln('User: $prompt');
    buffer.writeln('Assistant:');
    
    return buffer.toString();
  }
  
  /// Simulate AI response (placeholder for actual llama.cpp inference)
  Future<String> _simulateAIResponse(String prompt) async {
    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Simple pattern matching for demo purposes
    final lowerPrompt = prompt.toLowerCase();
    
    if (lowerPrompt.contains('appointment') || lowerPrompt.contains('meeting')) {
      if (lowerPrompt.contains('when') || lowerPrompt.contains('what time')) {
        return "I can help you check your appointments. Let me look that up for you.";
      } else if (lowerPrompt.contains('remember') || lowerPrompt.contains('save')) {
        return "I've saved that appointment information. I'll help you remember it!";
      }
    }
    
    if (lowerPrompt.contains('remind') || lowerPrompt.contains('alarm')) {
      return "I can set up a reminder for you. Just tell me when you'd like to be reminded!";
    }
    
    if (lowerPrompt.contains('hello') || lowerPrompt.contains('hi')) {
      return "Hi there! I'm Toru, your AI assistant. How can I help you today?";
    }
    
    if (lowerPrompt.contains('help')) {
      return "I can help you with:\n- Managing appointments and reminders\n- Answering questions\n- Taking notes\n- Finding routes and navigation\nWhat would you like to do?";
    }
    
    return "I understand your question. As an offline AI assistant, I'm here to help you with your tasks and queries!";
  }
  
  /// Extract important information from user input
  /// This helps identify appointments, reminders, etc.
  Future<Map<String, dynamic>> extractInformation(String text) async {
    final result = <String, dynamic>{};
    
    // Simple extraction logic (in production, use NER models)
    final lowerText = text.toLowerCase();
    
    // Extract appointment/reminder type
    if (lowerText.contains('doctor') || lowerText.contains('appointment')) {
      result['type'] = 'appointment';
    } else if (lowerText.contains('meeting')) {
      result['type'] = 'meeting';
    } else if (lowerText.contains('reminder') || lowerText.contains('remind')) {
      result['type'] = 'reminder';
    }
    
    // Extract time information (simplified)
    final timePatterns = [
      RegExp(r'(\d{1,2}):(\d{2})\s*(am|pm)?', caseSensitive: false),
      RegExp(r'(monday|tuesday|wednesday|thursday|friday|saturday|sunday)', caseSensitive: false),
      RegExp(r'(tomorrow|today|tonight)', caseSensitive: false),
    ];
    
    for (var pattern in timePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        result['time_text'] = match.group(0);
        break;
      }
    }
    
    result['raw_text'] = text;
    return result;
  }
  
  /// Generate embeddings for semantic search
  /// In production, use a proper embedding model
  Future<List<double>> generateEmbedding(String text) async {
    // Placeholder: In production, use sentence transformers or similar
    // For now, create a simple hash-based embedding
    
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    final embedding = List<double>.filled(384, 0.0); // Standard embedding dimension
    
    for (var i = 0; i < words.length && i < embedding.length; i++) {
      final hash = words[i].hashCode.abs() % 1000 / 1000.0;
      embedding[i] = hash;
    }
    
    return embedding;
  }
  
  /// Calculate cosine similarity between two embeddings
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (var i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    if (normA == 0 || normB == 0) return 0.0;
    
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
  
  double sqrt(double x) {
    return x < 0 ? 0 : x == 0 ? 0 : _sqrtHelper(x, x / 2);
  }
  
  double _sqrtHelper(double n, double guess) {
    final nextGuess = (guess + n / guess) / 2;
    if ((nextGuess - guess).abs() < 0.0001) return nextGuess;
    return _sqrtHelper(n, nextGuess);
  }
  
  /// Find relevant memories using semantic search
  Future<List<String>> findRelevantMemories(
    String query,
    List<Map<String, dynamic>> memories,
  ) async {
    if (memories.isEmpty) return [];
    
    final queryEmbedding = await generateEmbedding(query);
    final results = <({String content, double similarity})>[];
    
    for (var memory in memories) {
      final content = memory['content'] as String;
      
      // Use stored embedding or generate new one
      List<double> embedding;
      if (memory['embedding'] != null) {
        // Parse stored embedding (in production, store as binary)
        embedding = (memory['embedding'] as String)
            .split(',')
            .map((e) => double.tryParse(e) ?? 0.0)
            .toList();
      } else {
        embedding = await generateEmbedding(content);
      }
      
      final similarity = cosineSimilarity(queryEmbedding, embedding);
      results.add((content: content, similarity: similarity));
    }
    
    // Sort by similarity and return top results
    results.sort((a, b) => b.similarity.compareTo(a.similarity));
    return results.take(5).map((r) => r.content).toList();
  }
  
  /// Clear conversation context
  void clearContext() {
    _conversationContext.clear();
  }
  
  /// Get current conversation context
  List<Map<String, String>> getContext() {
    return List.unmodifiable(_conversationContext);
  }
  
  bool get isInitialized => _isInitialized;
}
