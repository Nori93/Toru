import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import 'core/services/database_service.dart';
import 'core/services/ai_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';
import 'presentation/viewmodels/chat_viewmodel.dart';
import 'presentation/viewmodels/memory_viewmodel.dart';
import 'presentation/viewmodels/reminder_viewmodel.dart';
import 'presentation/screens/home_screen.dart';
import 'core/constants/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize core services
  final databaseService = DatabaseService();
  await databaseService.initialize();
  
  final aiService = AIService();
  await aiService.initialize();
  
  final notificationService = NotificationService();
  await notificationService.initialize();
  
  final syncService = SyncService();
  
  // Initialize platform-specific settings
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
    // Desktop-specific initialization
    await databaseService.initializeDesktop();
  }
  
  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: databaseService),
        Provider<AIService>.value(value: aiService),
        Provider<NotificationService>.value(value: notificationService),
        Provider<SyncService>.value(value: syncService),
        ChangeNotifierProvider(
          create: (context) => ChatViewModel(
            aiService: aiService,
            databaseService: databaseService,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => MemoryViewModel(
            databaseService: databaseService,
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ReminderViewModel(
            databaseService: databaseService,
            notificationService: notificationService,
          ),
        ),
      ],
      child: const ToruApp(),
    ),
  );
}

class ToruApp extends StatelessWidget {
  const ToruApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toru - AI Assistant',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
