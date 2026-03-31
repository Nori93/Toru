import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/reminder_viewmodel.dart';
import 'package:intl/intl.dart';

/// Dashboard screen showing today's schedule and overview
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderViewModel>().loadReminders();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final greeting = _getGreeting();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              // Trigger sync
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Syncing data...')),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<ReminderViewModel>().loadReminders();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('EEEE, MMMM d, y').format(now),
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildQuickStat(
                            context,
                            icon: Icons.wb_sunny,
                            label: 'Morning',
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 16),
                          _buildQuickStat(
                            context,
                            icon: Icons.check_circle,
                            label: 'Ready',
                            color: Colors.green,
                          ),
                          const SizedBox(width: 16),
                          _buildQuickStat(
                            context,
                            icon: Icons.battery_full,
                            label: 'Offline',
                            color: Colors.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Today's Reminders Section
              Text(
                'Today\'s Schedule',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              
              Consumer<ReminderViewModel>(
                builder: (context, reminderVM, child) {
                  final upcoming = reminderVM.getUpcomingReminders();
                  
                  if (reminderVM.isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  
                  if (upcoming.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.event_available,
                              size: 48,
                              color: theme.colorScheme.secondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No reminders for today',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enjoy your free time!',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  return Column(
                    children: upcoming.map((reminder) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getCategoryColor(reminder.category),
                            child: Icon(
                              _getCategoryIcon(reminder.category),
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text(reminder.title),
                          subtitle: Text(
                            '${reminder.formattedTime}${reminder.description.isNotEmpty ? ' • ${reminder.description}' : ''}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.done),
                            onPressed: () {
                              // Mark as done
                              reminderVM.toggleReminder(reminder.id);
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              
              const SizedBox(height: 24),
              
              // Quick Actions
              Text(
                'Quick Actions',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context,
                      icon: Icons.chat_bubble,
                      label: 'Chat with Toru',
                      color: Colors.blue,
                      onTap: () {
                        // Navigate to chat
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      icon: Icons.add_alarm,
                      label: 'Add Reminder',
                      color: Colors.purple,
                      onTap: () {
                        // Navigate to add reminder
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context,
                      icon: Icons.note_add,
                      label: 'New Note',
                      color: Colors.green,
                      onTap: () {
                        // Navigate to new note
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      icon: Icons.directions,
                      label: 'Navigation',
                      color: Colors.orange,
                      onTap: () {
                        // Navigate to transport
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning! 🌅';
    if (hour < 17) return 'Good Afternoon! ☀️';
    if (hour < 21) return 'Good Evening! 🌆';
    return 'Good Night! 🌙';
  }
  
  Widget _buildQuickStat(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return Colors.blue;
      case 'exercise':
        return Colors.green;
      case 'health':
        return Colors.red;
      case 'personal':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return Icons.work;
      case 'exercise':
        return Icons.fitness_center;
      case 'health':
        return Icons.local_hospital;
      case 'personal':
        return Icons.person;
      default:
        return Icons.alarm;
    }
  }
}
