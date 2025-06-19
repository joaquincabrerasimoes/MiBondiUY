import 'package:flutter/material.dart';
import 'package:mibondiuy/models/bus_stop.dart';
import 'package:mibondiuy/services/bus_stop_service.dart';

class BusStopTabbedContent extends StatefulWidget {
  final BusStop busStop;
  final Function(BusStop)? onBusStopMarkerTapped;
  final Function(List<BusLine>)? onBusStopLinesLoaded;
  final Function(List<UpcomingBus>)? onBusStopLiveLinesLoaded;

  const BusStopTabbedContent({
    super.key,
    required this.busStop,
    this.onBusStopMarkerTapped,
    this.onBusStopLinesLoaded,
    this.onBusStopLiveLinesLoaded,
  });

  @override
  State<BusStopTabbedContent> createState() => _BusStopTabbedContentState();
}

class _BusStopTabbedContentState extends State<BusStopTabbedContent>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<BusLine> _busLines = [];
  List<UpcomingBus> _upcomingBuses = [];
  Set<String> _selectedLines = <String>{};
  bool _linesLoading = true;
  bool _upcomingLoading = false;
  String? _linesError;
  String? _upcomingError;
  bool _hasLoadedUpcoming = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadBusLines();
  }

  @override
  void didUpdateWidget(BusStopTabbedContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload lines if the bus stop changed
    if (oldWidget.busStop.id != widget.busStop.id) {
      _loadBusLines();
      // Reset upcoming data since it's for a different bus stop
      setState(() {
        _upcomingBuses = [];
        _hasLoadedUpcoming = false;
        _upcomingError = null;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && !_hasLoadedUpcoming) {
      _loadUpcomingBuses();
    }
  }

  Future<void> _loadBusLines() async {
    setState(() {
      _linesLoading = true;
      _linesError = null;
    });

    try {
      final lines = await BusStopService.getBusStopLines(widget.busStop.id);
      setState(() {
        _busLines = lines;
        _selectedLines = lines.map((line) => line.line).toSet();
        _linesLoading = false;
      });
    } catch (e) {
      setState(() {
        _linesError = e.toString();
        _linesLoading = false;
      });
    }
  }

  Future<void> _loadUpcomingBuses() async {
    if (_selectedLines.isEmpty) return;

    setState(() {
      _upcomingLoading = true;
      _upcomingError = null;
      _hasLoadedUpcoming = true;
    });

    try {
      final upcoming = await BusStopService.getUpcomingBuses(
        widget.busStop.id,
        _selectedLines.toList(),
      );
      setState(() {
        _upcomingBuses = upcoming;
        _upcomingLoading = false;
      });
    } catch (e) {
      setState(() {
        _upcomingError = e.toString();
        _upcomingLoading = false;
      });
    }
  }

  void _showLineFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.filter_list,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Filter Lines',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                _selectedLines =
                                    _busLines.map((line) => line.line).toSet();
                              });
                              setState(() {});
                            },
                            child: const Text('Select All'),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                _selectedLines.clear();
                              });
                              setState(() {});
                            },
                            child: const Text('Clear All'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Lines list
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: _busLines.length,
                        itemBuilder: (context, index) {
                          final line = _busLines[index];
                          final isSelected = _selectedLines.contains(line.line);
                          return CheckboxListTile(
                            title: Text(line.line),
                            value: isSelected,
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  _selectedLines.add(line.line);
                                } else {
                                  _selectedLines.remove(line.line);
                                }
                              });
                              setState(() {});
                            },
                          );
                        },
                      ),
                    ),
                    // Bottom buttons
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                // Reload upcoming buses if we're on that tab
                                if (_tabController.index == 1) {
                                  _loadUpcomingBuses();
                                }
                              },
                              child: const Text('Apply'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Lines'),
            Tab(text: 'Upcoming'),
          ],
        ),
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLinesTab(),
              _buildUpcomingTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLinesTab() {
    if (_linesLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_linesError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading lines',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _linesError!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadBusLines,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_busLines.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bus_alert_outlined,
              size: 48,
            ),
            SizedBox(height: 16),
            Text('No lines found for this bus stop'),
          ],
        ),
      );
    }

    widget.onBusStopLinesLoaded?.call(_busLines);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildInfoRow(context, 'Stop Code', widget.busStop.code),
        if (widget.busStop.address != null &&
            widget.busStop.address!.isNotEmpty)
          _buildInfoRow(context, 'Address', widget.busStop.address!),
        _buildInfoRow(context, 'Coordinates',
            '${widget.busStop.latitude.toStringAsFixed(6)}, ${widget.busStop.longitude.toStringAsFixed(6)}'),
        const SizedBox(height: 16),
        Text(
          'Lines serving this stop:',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _busLines
              .map((line) => Chip(
                    label: Text(line.line),
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildUpcomingTab() {
    return Column(
      children: [
        // Filter and Refresh Controls
        if (_busLines.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showLineFilterModal(),
                    icon: const Icon(Icons.filter_list),
                    label: Text(
                      _selectedLines.isEmpty
                          ? 'Filter by lines'
                          : '${_selectedLines.length} lines selected',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  onPressed: _hasLoadedUpcoming ? _loadUpcomingBuses : null,
                  icon: _upcomingLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  tooltip: 'Refresh upcoming buses',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        // Upcoming buses content
        Expanded(
          child: _buildUpcomingContent(),
        ),
      ],
    );
  }

  Widget _buildUpcomingContent() {
    if (_upcomingLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_upcomingError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading upcoming buses',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _upcomingError!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUpcomingBuses,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!_hasLoadedUpcoming) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 48,
            ),
            SizedBox(height: 16),
            Text('Switch to this tab to load upcoming buses'),
          ],
        ),
      );
    }

    if (_selectedLines.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 48,
            ),
            SizedBox(height: 16),
            Text('Select at least one line to see upcoming buses'),
          ],
        ),
      );
    }

    if (_upcomingBuses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.schedule_outlined,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text('No upcoming buses found'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUpcomingBuses,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    widget.onBusStopLiveLinesLoaded?.call(_upcomingBuses);

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _upcomingBuses.length,
      itemBuilder: (context, index) {
        final bus = _upcomingBuses[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  bus.line,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            title: Text(
              bus.destination,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('${bus.origin} → ${bus.destination}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  bus.formattedEta,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: bus.eta <= 60
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
