import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Transport/Navigation screen
/// Shows maps when online, saved routes when offline
class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  bool _isOnline = false;
  
  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }
  
  Future<void> _checkConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _isOnline = !result.contains(ConnectivityResult.none);
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transport'),
        actions: [
          IconButton(
            icon: Icon(
              _isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: _isOnline ? Colors.green : Colors.grey,
            ),
            onPressed: _checkConnectivity,
          ),
        ],
      ),
      body: _isOnline ? _buildOnlineView(context) : _buildOfflineView(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRouteDialog(context),
        child: const Icon(Icons.add_location),
      ),
    );
  }
  
  Widget _buildOnlineView(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        // Map placeholder
        Expanded(
          child: Container(
            color: theme.colorScheme.surfaceVariant,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map,
                    size: 80,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Online Map View',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Google Maps integration would appear here',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Integrate Google Maps
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Map integration coming soon!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Get Directions'),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Quick actions
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  context,
                  icon: Icons.near_me,
                  label: 'Current Location',
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  context,
                  icon: Icons.search,
                  label: 'Search Places',
                  onTap: () {},
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildOfflineView(BuildContext context) {
    final theme = Theme.of(context);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Offline indicator
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Offline Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Showing saved routes only',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Saved Routes',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          
          // Sample saved routes
          _buildSavedRouteCard(
            context,
            from: 'Home',
            to: 'Work',
            distance: '5.2 km',
            duration: '15 min',
            icon: Icons.work,
          ),
          _buildSavedRouteCard(
            context,
            from: 'Home',
            to: 'Gym',
            distance: '2.1 km',
            duration: '8 min',
            icon: Icons.fitness_center,
          ),
          _buildSavedRouteCard(
            context,
            from: 'Work',
            to: 'Market',
            distance: '3.5 km',
            duration: '12 min',
            icon: Icons.shopping_cart,
          ),
          
          const SizedBox(height: 24),
          
          // Offline map info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Offline Maps',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Download offline maps for your area to navigate without internet connection.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Offline maps feature coming soon!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Download Maps'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
  
  Widget _buildSavedRouteCard(
    BuildContext context, {
    required String from,
    required String to,
    required String distance,
    required String duration,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening route: $from to $to')),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: theme.colorScheme.secondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          from,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          to,
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.straighten,
                          size: 14,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distance,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          duration,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showAddRouteDialog(BuildContext context) {
    final fromController = TextEditingController();
    final toController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Route'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: fromController,
              decoration: const InputDecoration(
                labelText: 'From',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: toController,
              decoration: const InputDecoration(
                labelText: 'To',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Save route to database
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Route saved!')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
