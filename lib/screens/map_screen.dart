import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mibondiuy/models/bus.dart';
import 'package:mibondiuy/models/bus_stop.dart';
import 'package:mibondiuy/models/company.dart';
import 'package:mibondiuy/services/bus_service.dart';
import 'package:mibondiuy/services/bus_stop_service.dart';
import 'package:mibondiuy/services/logging_service.dart';
import 'package:mibondiuy/services/theme_service.dart' as theme_service;
import 'package:mibondiuy/utils/marker_clustering.dart';
import 'package:mibondiuy/widgets/bus_stop_tabbed_content.dart';
import 'package:mibondiuy/widgets/filter_drawer.dart';
import 'package:mibondiuy/widgets/adaptive_filter_panel.dart';
import 'package:mibondiuy/widgets/platform_map.dart';
import 'package:mibondiuy/widgets/refresh_countdown.dart';
import 'package:mibondiuy/screens/about_screen.dart';
import 'package:mibondiuy/screens/settings_screen.dart';

class MapScreen extends StatefulWidget {
  final theme_service.ThemeService? themeService;

  const MapScreen({super.key, this.themeService});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String _customCompanyColorsCacheKey = 'custom_company_colors';

  List<Bus> _buses = [];
  List<BusStop> _busStops = [];
  Timer? _refreshTimer;
  bool _isLoading = false;
  bool _isLoadingBusStops = false;
  int _refreshIntervalSeconds = 10;

  // Filter settings
  int _selectedSubsystem = -1;
  int _selectedCompany = -1;
  Set<int> _selectedCompanies = Company.companies.map((c) => c.code).toSet();
  List<String> _selectedLines = [];

  // Bus stop info panel settings
  bool _showBusStopPanel = false;
  BusStop? _selectedBusStop;

  // Settings
  bool _alwaysShowAllBusStops = true;
  bool _alwaysShowAllBuses = true;
  Map<int, Color> _customCompanyColors = {};

  // Montevideo coordinates - updated to user's preferred center
  static const ll.LatLng _initialCenter = ll.LatLng(-34.881179, -56.180883);
  static const double _initialZoom = 12.0;

  // Map controller callback
  Function(ll.LatLng, double)? _centerMapCallback;

  @override
  void initState() {
    super.initState();
    _loadCustomCompanyColors();
    _loadBuses();
    _loadBusStops();
    _startPeriodicRefresh();
  }

  /// Loads custom company colors from SharedPreferences
  Future<void> _loadCustomCompanyColors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorData = prefs.getString(_customCompanyColorsCacheKey);

      if (colorData != null) {
        final Map<String, dynamic> colorMap = {};
        // Parse the stored string as a simple format: "companyCode:colorValue,companyCode:colorValue"
        final pairs = colorData.split(',');
        for (final pair in pairs) {
          if (pair.contains(':')) {
            final parts = pair.split(':');
            if (parts.length == 2) {
              final companyCode = int.tryParse(parts[0]);
              final colorValue = int.tryParse(parts[1]);
              if (companyCode != null && colorValue != null) {
                colorMap[companyCode.toString()] = colorValue;
              }
            }
          }
        }

        // Convert to Map<int, Color>
        final customColors = <int, Color>{};
        colorMap.forEach((key, value) {
          final companyCode = int.tryParse(key);
          if (companyCode != null && value is int) {
            customColors[companyCode] = Color(value);
          }
        });

        setState(() {
          _customCompanyColors = customColors;
        });
      }
    } catch (e) {
      logger.error('Error loading custom company colors', e);
    }
  }

  /// Saves custom company colors to SharedPreferences
  Future<void> _saveCustomCompanyColors() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_customCompanyColors.isEmpty) {
        await prefs.remove(_customCompanyColorsCacheKey);
      } else {
        // Convert Map<int, Color> to string format: "companyCode:colorValue,companyCode:colorValue"
        final colorPairs = _customCompanyColors.entries.map((entry) => '${entry.key}:${entry.value.toARGB32()}').join(',');

        await prefs.setString(_customCompanyColorsCacheKey, colorPairs);
      }
    } catch (e) {
      logger.error('Error saving custom company colors', e);
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(seconds: _refreshIntervalSeconds), (timer) {
      _loadBuses();
    });
  }

  Future<void> _loadBuses() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final buses = await BusService.getBuses(
        subsistema: _selectedSubsystem,
        empresa: _selectedCompany,
        lineas: _selectedLines.isNotEmpty ? _selectedLines : null,
      );

      // Filter out buses with 0,0 coordinates and count them
      final filteredBuses = buses.where((bus) {
        return bus.latitude != 0.0 || bus.longitude != 0.0;
      }).toList();

      final zeroBusesCount = buses.length - filteredBuses.length;
      if (zeroBusesCount > 0) {
        logger.trace('🚌 Filtered out $zeroBusesCount buses with coordinates (0, 0)');
      }

      setState(() {
        _buses = filteredBuses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading buses: $e')),
        );
      }
    }
  }

  Future<void> _loadBusStops() async {
    if (_isLoadingBusStops) return;

    setState(() {
      _isLoadingBusStops = true;
    });

    try {
      final busStops = await BusStopService.getBusStops();

      // Filter out bus stops with 0,0 coordinates and count them
      final filteredBusStops = busStops.where((busStop) {
        return busStop.latitude != 0.0 || busStop.longitude != 0.0;
      }).toList();

      final zeroBusStopsCount = busStops.length - filteredBusStops.length;
      if (zeroBusStopsCount > 0) {
        logger.trace('🚏 Filtered out $zeroBusStopsCount bus stops with coordinates (0, 0)');
      }

      setState(() {
        _busStops = filteredBusStops;
        _isLoadingBusStops = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingBusStops = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bus stops: $e')),
        );
      }
    }
  }

  Future<void> _refreshBusStops() async {
    if (_isLoadingBusStops) return;

    setState(() {
      _isLoadingBusStops = true;
    });

    try {
      final busStops = await BusStopService.refreshBusStops();

      // Filter out bus stops with 0,0 coordinates and count them
      final filteredBusStops = busStops.where((busStop) {
        return busStop.latitude != 0.0 || busStop.longitude != 0.0;
      }).toList();

      final zeroBusStopsCount = busStops.length - filteredBusStops.length;
      if (zeroBusStopsCount > 0) {
        logger.trace('🚏 Filtered out $zeroBusStopsCount bus stops with coordinates (0, 0) during refresh');
      }

      setState(() {
        _busStops = filteredBusStops;
        _isLoadingBusStops = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bus stops refreshed successfully')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingBusStops = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing bus stops: $e')),
        );
      }
    }
  }

  void _centerMap() {
    _centerMapCallback?.call(_initialCenter, _initialZoom);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Map centered to default location'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showBusInfo(Bus bus) {
    final company = Company.getByCode(bus.codigoEmpresa);
    final companyColor = Company.getColorByCode(bus.codigoEmpresa, customColors: _customCompanyColors);

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
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: companyColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Line ${bus.linea}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Content
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildInfoRow('Route', bus.sublinea),
                      _buildInfoRow('Destination', bus.destinoDesc),
                      _buildInfoRow('Company', company?.name ?? 'Unknown'),
                      _buildInfoRow('Subsystem', bus.subsistemaDesc),
                      _buildInfoRow('Type', bus.tipoLineaDesc),
                      _buildInfoRow('Bus Number', bus.codigoBus.toString()),
                      _buildInfoRow('Speed', '${bus.velocidad} km/h'),
                      _buildInfoRow('Coordinates', '${bus.latitude.toStringAsFixed(6)}, ${bus.longitude.toStringAsFixed(6)}'),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showBusStopInfo(BusStop busStop) {
    setState(() {
      _selectedBusStop = busStop;
      _showBusStopPanel = true;
    });
  }

  void _hideBusStopInfo() {
    setState(() {
      _showBusStopPanel = false;
      _selectedBusStop = null;
    });
  }

  void _showClusterInfo(BusCluster cluster) {
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
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.directions_bus_filled,
                        color: Theme.of(context).colorScheme.primary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${cluster.count} Buses in Area',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Content
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: cluster.buses.length,
                    itemBuilder: (context, index) {
                      final bus = cluster.buses[index];
                      final company = Company.getByCode(bus.codigoEmpresa);
                      final companyColor = Company.getColorByCode(bus.codigoEmpresa, customColors: _customCompanyColors);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: ListTile(
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: companyColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                bus.linea,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          title: Text('Line ${bus.linea}'),
                          subtitle: Text(company?.name ?? 'Unknown Company'),
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          onTap: () {
                            //Navigator.of(context).pop();
                            _showBusInfo(bus);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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

  void _applyFilters({int? subsystem, int? company, Set<int>? companies, List<String>? lines}) {
    setState(() {
      if (subsystem != null) _selectedSubsystem = subsystem;
      if (company != null) _selectedCompany = company;
      if (companies != null) _selectedCompanies = companies;
      if (lines != null) _selectedLines = lines;
    });
    _loadBuses();
  }

  void _onRefreshIntervalChanged(int newInterval) {
    setState(() {
      _refreshIntervalSeconds = newInterval;
    });
    _startPeriodicRefresh();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          themeService: widget.themeService,
          onRefreshBusStops: _refreshBusStops,
          isRefreshingBusStops: _isLoadingBusStops,
          alwaysShowAllBusStops: _alwaysShowAllBusStops,
          alwaysShowAllBuses: _alwaysShowAllBuses,
          onAlwaysShowAllBusStopsChanged: (value) {
            setState(() {
              _alwaysShowAllBusStops = value;
            });
          },
          onAlwaysShowAllBusesChanged: (value) {
            setState(() {
              _alwaysShowAllBuses = value;
            });
          },
          customCompanyColors: _customCompanyColors,
          onCompanyColorChanged: (companyCode, color) {
            setState(() {
              _customCompanyColors[companyCode] = color;
            });
            _saveCustomCompanyColors();
          },
        ),
      ),
    );
  }

  List<BusStop> get _filteredBusStops {
    if (_alwaysShowAllBusStops || !_showBusStopPanel || _selectedBusStop == null) {
      return _busStops;
    }
    // Only show the selected bus stop
    return [_selectedBusStop!];
  }

  List<Bus> get _filteredBusesForDisplay {
    var filteredBuses = _buses.where((bus) {
      // Apply company filter
      if (_selectedCompanies.isNotEmpty && !_selectedCompanies.contains(bus.codigoEmpresa)) {
        return false;
      }
      // Apply line filter
      if (_selectedLines.isNotEmpty && !_selectedLines.contains(bus.linea)) {
        return false;
      }
      return true;
    }).toList();

    // Apply "always show all buses" filter
    if (!_alwaysShowAllBuses && _showBusStopPanel && _selectedBusStop != null) {
      // Only show buses that go through the selected bus stop
      final selectedBusStopLines = _selectedBusStop!.lines?.map((line) => line.line).toSet() ?? <String>{};
      filteredBuses = filteredBuses.where((bus) => selectedBusStopLines.contains(bus.linea)).toList();
    }

    return filteredBuses;
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const AboutScreen(),
              ),
            );
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text('MiBondiUY'),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Center Map',
            onPressed: _centerMap,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      drawer: !isLandscape
          ? FilterDrawer(
              selectedSubsystem: _selectedSubsystem,
              selectedCompany: _selectedCompany,
              selectedCompanies: _selectedCompanies,
              selectedLines: _selectedLines,
              customCompanyColors: _customCompanyColors,
              onFiltersChanged: _applyFilters,
            )
          : null,
      body: Stack(
        children: [
          // Map fills entire background
          PlatformMap(
            initialCenter: _initialCenter,
            initialZoom: _initialZoom,
            buses: _filteredBusesForDisplay,
            busStops: _filteredBusStops,
            selectedCompanies: _selectedCompanies,
            selectedLines: _selectedLines,
            selectedBusStop: _showBusStopPanel ? _selectedBusStop : null,
            customCompanyColors: _customCompanyColors,
            onBusMarkerTapped: _showBusInfo,
            onClusterMarkerTapped: _showClusterInfo,
            onBusStopMarkerTapped: _showBusStopInfo,
            onMapReady: (centerCallback) {
              _centerMapCallback = centerCallback;
            },
          ),
          // Filter panel overlays the map in landscape mode
          if (isLandscape)
            Positioned(
              left: 16,
              top: 16,
              bottom: 16,
              child: AdaptiveFilterPanel(
                selectedSubsystem: _selectedSubsystem,
                selectedCompany: _selectedCompany,
                selectedCompanies: _selectedCompanies,
                selectedLines: _selectedLines,
                customCompanyColors: _customCompanyColors,
                onFiltersChanged: _applyFilters,
              ),
            ),
          // Bus stop info panel
          if (_showBusStopPanel && _selectedBusStop != null)
            Positioned(
              right: isLandscape ? 16 : 16,
              top: isLandscape ? 16 : null,
              bottom: isLandscape ? 16 : 16,
              left: isLandscape ? null : 16,
              width: isLandscape ? 350 : null,
              height: isLandscape ? null : 400,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header with close button
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.directions_bus_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedBusStop!.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  'Stop ${_selectedBusStop!.code}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: _hideBusStopInfo,
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                    // Content using BusStopTabbedContent
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                        child: BusStopTabbedContent(
                          busStop: _selectedBusStop!,
                          onBusStopMarkerTapped: _showBusStopInfo,
                          onBusStopLinesLoaded: (lines) {
                            _selectedBusStop!.lines = lines;
                          },
                          onBusStopLiveLinesLoaded: (upcomingBuses) {
                            _selectedBusStop!.upcomingBuses = upcomingBuses;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading)
            const Positioned(
              top: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Loading buses...'),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 16,
            left: isLandscape ? 330 : 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Buses shown: ${_filteredBusesForDisplay.length}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Bus stops: ${_filteredBusStops.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Refresh countdown in bottom right (moves when bus stop panel is open)
          Positioned(
            bottom: _showBusStopPanel && !isLandscape ? 420 : 16, // Move up in portrait when panel is open
            right: _showBusStopPanel && isLandscape ? 382 : 16, // Move left in landscape when panel is open
            child: RefreshCountdown(
              refreshIntervalSeconds: _refreshIntervalSeconds,
              onRefresh: _loadBuses,
              onIntervalChanged: _onRefreshIntervalChanged,
            ),
          ),
        ],
      ),
    );
  }
}
