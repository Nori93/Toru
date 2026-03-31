import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'memory_screen.dart';
import 'reminder_screen.dart';
import 'transport_screen.dart';
import 'dashboard_screen.dart';

/// Main home screen with bottom navigation
/// Provides access to all major features
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = const [
    DashboardScreen(),
    ChatScreen(),
    MemoryScreen(),
    ReminderScreen(),
    TransportScreen(),
  ];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            selectedIcon: Icon(Icons.lightbulb),
            label: 'Memories',
          ),
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm),
            label: 'Reminders',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_outlined),
            selectedIcon: Icon(Icons.directions),
            label: 'Transport',
          ),
        ],
      ),
    );
  }
}
