import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mibondiuy/models/bus_stop.dart';
import 'package:mibondiuy/services/bus_stop_service.dart';

class BusStopDataScreen extends StatefulWidget {
  final VoidCallback? onRefreshBusStops;
  final bool isRefreshingBusStops;

  const BusStopDataScreen({
    super.key,
    this.onRefreshBusStops,
    this.isRefreshingBusStops = false,
  });

  @override
  State<BusStopDataScreen> createState() => _BusStopDataScreenState();
}

class _BusStopDataScreenState extends State<BusStopDataScreen> {
  bool _isDeletingCache = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Stop Data'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Data Management Section
          _buildSectionHeader('Data Management'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: widget.isRefreshingBusStops
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  title: const Text('Refresh Metadata'),
                  subtitle: const Text('Update bus stop data from server'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: widget.isRefreshingBusStops ? null : widget.onRefreshBusStops,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: _isDeletingCache
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                  title: const Text('Delete Cache'),
                  subtitle: const Text('Clear all cached bus stop data'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _isDeletingCache ? null : () => _showDeleteCacheDialog(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Bus Stop Viewer Section
          _buildSectionHeader('Bus Stop Viewer'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.list),
              title: const Text('View All Bus Stops'),
              subtitle: const Text('Browse cached bus stops with sorting options'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _navigateToBusStopViewer(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  void _showDeleteCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Cache'),
        content: const Text(
          'This will delete all cached bus stop data and bus line information. '
          'You will need to refresh the data to use the app again.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteCache();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCache() async {
    setState(() {
      _isDeletingCache = true;
    });

    try {
      await BusStopService.clearBusStopsCache();
      await BusStopService.clearAllBusStopLinesCache();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting cache: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingCache = false;
        });
      }
    }
  }

  void _navigateToBusStopViewer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BusStopViewerScreen(),
      ),
    );
  }
}

class BusStopViewerScreen extends StatefulWidget {
  const BusStopViewerScreen({super.key});

  @override
  State<BusStopViewerScreen> createState() => _BusStopViewerScreenState();
}

enum SortOption { byNumber, byNumberOfLines, byAddress }

class _BusStopViewerScreenState extends State<BusStopViewerScreen> {
  List<BusStop> _busStops = [];
  Map<String, List<BusLine>> _busStopLines = {};
  bool _isLoading = true;
  String _error = '';
  SortOption _currentSort = SortOption.byNumber;

  @override
  void initState() {
    super.initState();
    _loadBusStops();
  }

  Future<void> _loadBusStops() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      // Load bus stops from cache ONLY - no API calls
      final busStops = await _getCachedBusStopsOnly();

      // Load lines for each bus stop from cache ONLY - no API calls
      Map<String, List<BusLine>> lines = {};
      for (final busStop in busStops) {
        final busLines = await _getCachedBusStopLinesOnly(busStop.id);
        lines[busStop.id] = busLines;
      }

      setState(() {
        _busStops = busStops;
        _busStopLines = lines;
        _isLoading = false;
      });

      _sortBusStops();
    } catch (e) {
      setState(() {
        _error = 'Error loading cached bus stops: $e';
        _isLoading = false;
      });
    }
  }

  /// Gets bus stops from local cache only - never makes API calls
  Future<List<BusStop>> _getCachedBusStopsOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('bus_stops_cache');

      if (cachedData != null) {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        return jsonList.map((json) => BusStop.fromJson(json)).toList();
      }
    } catch (e) {
      // If there's an error reading cache, return empty list
      print('Error reading bus stops cache: $e');
    }

    return [];
  }

  /// Gets lines for a specific bus stop from local cache only - never makes API calls
  Future<List<BusLine>> _getCachedBusStopLinesOnly(String busStopId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'bus_stop_lines_cache_$busStopId';
      final cachedData = prefs.getString(cacheKey);

      if (cachedData != null) {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        return jsonList.map((json) => BusLine.fromJson(json)).toList();
      }
    } catch (e) {
      // If there's an error reading cache, return empty list
      print('Error reading bus stop lines cache for $busStopId: $e');
    }

    return [];
  }

  void _sortBusStops() {
    setState(() {
      switch (_currentSort) {
        case SortOption.byNumber:
          _busStops.sort((a, b) {
            final aNum = int.tryParse(a.code) ?? 0;
            final bNum = int.tryParse(b.code) ?? 0;
            return aNum.compareTo(bNum);
          });
          break;
        case SortOption.byNumberOfLines:
          _busStops.sort((a, b) {
            final aLines = _busStopLines[a.id]?.length ?? 0;
            final bLines = _busStopLines[b.id]?.length ?? 0;
            return bLines.compareTo(aLines); // Descending order
          });
          break;
        case SortOption.byAddress:
          _busStops.sort((a, b) {
            final aAddress = a.address ?? a.name;
            final bAddress = b.address ?? b.name;
            return aAddress.compareTo(bAddress);
          });
          break;
      }
    });
  }

  String _getSortOptionName(SortOption option) {
    switch (option) {
      case SortOption.byNumber:
        return 'By Number';
      case SortOption.byNumberOfLines:
        return 'By Number of Lines';
      case SortOption.byAddress:
        return 'By Address';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Stop Viewer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (SortOption option) {
              setState(() {
                _currentSort = option;
              });
              _sortBusStops();
            },
            itemBuilder: (context) => SortOption.values.map((option) {
              return PopupMenuItem<SortOption>(
                value: option,
                child: Row(
                  children: [
                    if (_currentSort == option) const Icon(Icons.check, size: 16) else const SizedBox(width: 16),
                    const SizedBox(width: 8),
                    Text(_getSortOptionName(option)),
                  ],
                ),
              );
            }).toList(),
            tooltip: 'Sort options',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading bus stops...'),
          ],
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loadBusStops,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_busStops.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bus_alert, size: 64),
            SizedBox(height: 16),
            Text(
              'No bus stops found in cache',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Try refreshing the bus stop data from the settings',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Sort indicator
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              const Icon(Icons.sort, size: 16),
              const SizedBox(width: 8),
              Text(
                'Sorted ${_getSortOptionName(_currentSort)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Text(
                '${_busStops.length} bus stops',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _busStops.length,
            itemBuilder: (context, index) {
              final busStop = _busStops[index];
              final lines = _busStopLines[busStop.id] ?? [];

              return _buildBusStopTile(busStop, lines);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBusStopTile(BusStop busStop, List<BusLine> lines) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            busStop.code,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(busStop.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (busStop.address != null && busStop.address != busStop.name)
              Text(
                busStop.address!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            Text(
              '${lines.length} lines',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: lines.isEmpty ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.primary,
                    fontWeight: lines.isEmpty ? null : FontWeight.w500,
                  ),
            ),
          ],
        ),
        trailing: lines.isEmpty ? null : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: lines.isEmpty ? null : () => _showBusStopDetails(busStop, lines),
      ),
    );
  }

  void _showBusStopDetails(BusStop busStop, List<BusLine> lines) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            child: Text(
                              busStop.code,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  busStop.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                if (busStop.address != null && busStop.address != busStop.name)
                                  Text(
                                    busStop.address!,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Bus Lines (${lines.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Lines list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: lines.length,
                    itemBuilder: (context, index) {
                      final line = lines[index];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              line.line,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        title: Text('Line ${line.line}'),
                        subtitle: Text('Line ID: ${line.lineId}'),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
