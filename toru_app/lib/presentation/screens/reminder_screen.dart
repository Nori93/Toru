import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/reminder_viewmodel.dart';
import 'package:intl/intl.dart';

/// Reminder screen for managing alarms and reminders
class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  String _selectedFilter = 'all';
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
        actions: [
          PopupMenuButton<String>(
            initialValue: _selectedFilter,
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'work', child: Text('Work')),
              const PopupMenuItem(value: 'exercise', child: Text('Exercise')),
              const PopupMenuItem(value: 'health', child: Text('Health')),
              const PopupMenuItem(value: 'personal', child: Text('Personal')),
            ],
          ),
        ],
      ),
      body: Consumer<ReminderViewModel>(
        builder: (context, reminderVM, child) {
          if (reminderVM.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final reminders = _selectedFilter == 'all'
              ? reminderVM.activeReminders
              : reminderVM.getRemindersByCategory(_selectedFilter);
          
          if (reminders.isEmpty) {
            return _buildEmptyState(context);
          }
          
          return RefreshIndicator(
            onRefresh: () => reminderVM.loadReminders(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: reminders.length,
              itemBuilder: (context, index) {
                final reminder = reminders[index];
                return _buildReminderCard(context, reminder, reminderVM);
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddReminderDialog(context),
        icon: const Icon(Icons.add_alarm),
        label: const Text('Add Reminder'),
      ),
    );
  }
  
  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.alarm_off,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Reminders',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Create reminders for your tasks and appointments',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildReminderCard(
    BuildContext context,
    Reminder reminder,
    ReminderViewModel reminderVM,
  ) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isOverdue = reminder.time.isBefore(now);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showReminderDetails(context, reminder, reminderVM),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Category icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getCategoryColor(reminder.category).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getCategoryIcon(reminder.category),
                  color: _getCategoryColor(reminder.category),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Reminder details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (reminder.description.isNotEmpty)
                      Text(
                        reminder.description,
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: isOverdue
                              ? theme.colorScheme.error
                              : theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDateTime(reminder.time),
                          style: TextStyle(
                            fontSize: 12,
                            color: isOverdue
                                ? theme.colorScheme.error
                                : theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        if (reminder.isRecurring) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.repeat,
                            size: 14,
                            color: theme.colorScheme.secondary,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Active toggle
              Switch(
                value: reminder.isActive,
                onChanged: (value) {
                  reminderVM.toggleReminder(reminder.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (dateDay == today) {
      return 'Today at ${DateFormat('HH:mm').format(dateTime)}';
    } else if (dateDay == tomorrow) {
      return 'Tomorrow at ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('MMM d, HH:mm').format(dateTime);
    }
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
  
  void _showAddReminderDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    String selectedCategory = 'general';
    bool isRecurring = false;
    String recurrencePattern = 'daily';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Reminder'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('General')),
                    DropdownMenuItem(value: 'work', child: Text('Work')),
                    DropdownMenuItem(value: 'exercise', child: Text('Exercise')),
                    DropdownMenuItem(value: 'health', child: Text('Health')),
                    DropdownMenuItem(value: 'personal', child: Text('Personal')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedCategory = value!);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date'),
                  subtitle: Text(DateFormat('MMM d, y').format(selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Time'),
                  subtitle: Text(selectedTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) {
                      setState(() => selectedTime = time);
                    }
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Recurring'),
                  value: isRecurring,
                  onChanged: (value) {
                    setState(() => isRecurring = value!);
                  },
                ),
                if (isRecurring)
                  DropdownButtonFormField<String>(
                    value: recurrencePattern,
                    decoration: const InputDecoration(labelText: 'Repeat'),
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(
                        value: 'weekly:monday',
                        child: Text('Every Monday'),
                      ),
                      DropdownMenuItem(
                        value: 'weekly:tuesday',
                        child: Text('Every Tuesday'),
                      ),
                      DropdownMenuItem(
                        value: 'weekly:wednesday',
                        child: Text('Every Wednesday'),
                      ),
                      DropdownMenuItem(
                        value: 'weekly:thursday',
                        child: Text('Every Thursday'),
                      ),
                      DropdownMenuItem(
                        value: 'weekly:friday',
                        child: Text('Every Friday'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => recurrencePattern = value!);
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final dateTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  selectedTime.hour,
                  selectedTime.minute,
                );
                
                context.read<ReminderViewModel>().addReminder(
                      title: titleController.text,
                      description: descriptionController.text,
                      time: dateTime,
                      isRecurring: isRecurring,
                      recurrencePattern: isRecurring ? recurrencePattern : null,
                      category: selectedCategory,
                    );
                
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showReminderDetails(
    BuildContext context,
    Reminder reminder,
    ReminderViewModel reminderVM,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(reminder.title),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (reminder.description.isNotEmpty) ...[
              Text(reminder.description),
              const SizedBox(height: 12),
            ],
            Text('Time: ${_formatDateTime(reminder.time)}'),
            const SizedBox(height: 8),
            Text('Category: ${reminder.category}'),
            if (reminder.isRecurring) ...[
              const SizedBox(height: 8),
              Text('Recurring: ${reminder.recurrencePattern}'),
            ],
            const SizedBox(height: 8),
            Text('Status: ${reminder.isActive ? 'Active' : 'Inactive'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              reminderVM.deleteReminder(reminder.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
