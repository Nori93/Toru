import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/memory_viewmodel.dart';
import 'package:intl/intl.dart';

/// Memory screen for managing notes, facts, and stored information
class MemoryScreen extends StatefulWidget {
  const MemoryScreen({super.key});

  @override
  State<MemoryScreen> createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterDialog(context);
            },
          ),
        ],
      ),
      body: Consumer<MemoryViewModel>(
        builder: (context, memoryVM, child) {
          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search memories...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: memoryVM.searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              memoryVM.clearSearch();
                            },
                          )
                        : null,
                  ),
                  onChanged: (query) {
                    if (query.isEmpty) {
                      memoryVM.clearSearch();
                    } else {
                      memoryVM.searchMemories(query);
                    }
                  },
                ),
              ),
              
              // Memories list
              Expanded(
                child: memoryVM.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : memoryVM.memories.isEmpty
                        ? _buildEmptyState(context)
                        : RefreshIndicator(
                            onRefresh: () => memoryVM.loadMemories(),
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: memoryVM.memories.length,
                              itemBuilder: (context, index) {
                                final memory = memoryVM.memories[index];
                                return _buildMemoryCard(context, memory, memoryVM);
                              },
                            ),
                          ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMemoryDialog(context),
        child: const Icon(Icons.add),
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
              Icons.lightbulb_outline,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No Memories Yet',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Store notes, facts, and important information here',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddMemoryDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add Memory'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMemoryCard(
    BuildContext context,
    Memory memory,
    MemoryViewModel memoryVM,
  ) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showMemoryDetails(context, memory, memoryVM),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getTypeColor(memory.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      memory.type.toUpperCase(),
                      style: TextStyle(
                        color: _getTypeColor(memory.type),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: List.generate(
                      5,
                      (index) => Icon(
                        index < (memory.importance ~/ 2)
                            ? Icons.star
                            : Icons.star_border,
                        size: 14,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                memory.title,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                memory.content,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (memory.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: memory.tags.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#$tag',
                        style: TextStyle(
                          color: theme.colorScheme.secondary,
                          fontSize: 11,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Created ${DateFormat('MMM d, y').format(memory.createdAt)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'note':
        return Colors.blue;
      case 'fact':
        return Colors.green;
      case 'appointment':
        return Colors.purple;
      case 'idea':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
  
  void _showAddMemoryDialog(BuildContext context) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final tagsController = TextEditingController();
    String selectedType = 'note';
    int importance = 5;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Memory'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(value: 'note', child: Text('Note')),
                    DropdownMenuItem(value: 'fact', child: Text('Fact')),
                    DropdownMenuItem(value: 'idea', child: Text('Idea')),
                    DropdownMenuItem(value: 'appointment', child: Text('Appointment')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedType = value!);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(labelText: 'Content'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma separated)',
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Importance: ${importance}/10'),
                    Slider(
                      value: importance.toDouble(),
                      min: 1,
                      max: 10,
                      divisions: 9,
                      onChanged: (value) {
                        setState(() => importance = value.toInt());
                      },
                    ),
                  ],
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
                final tags = tagsController.text
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                
                context.read<MemoryViewModel>().addMemory(
                      type: selectedType,
                      title: titleController.text,
                      content: contentController.text,
                      tags: tags,
                      importance: importance,
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
  
  void _showMemoryDetails(
    BuildContext context,
    Memory memory,
    MemoryViewModel memoryVM,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(memory.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Type: ${memory.type}'),
              const SizedBox(height: 8),
              Text(memory.content),
              if (memory.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Tags: ${memory.tags.join(', ')}'),
              ],
              const SizedBox(height: 12),
              Text(
                'Created: ${DateFormat('MMM d, y HH:mm').format(memory.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              memoryVM.deleteMemory(memory.id);
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
  
  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Memories'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All'),
              onTap: () {
                context.read<MemoryViewModel>().loadMemories();
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Notes'),
              onTap: () {
                // Filter by type
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Facts'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('Appointments'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
