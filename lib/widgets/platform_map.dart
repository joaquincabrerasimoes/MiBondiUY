import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as ll;
import 'package:mibondiuy/models/bus.dart';
import 'package:mibondiuy/models/bus_stop.dart';
import 'package:mibondiuy/models/company.dart';
import 'package:mibondiuy/utils/marker_clustering.dart';
import 'package:mibondiuy/services/logging_service.dart';

class _PieChartPainter extends CustomPainter {
  final Map<int, int> companyDistribution;
  final double strokeWidth;
  final Map<int, Color> customCompanyColors;

  _PieChartPainter({
    required this.companyDistribution,
    this.strokeWidth = 3.0,
    this.customCompanyColors = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - strokeWidth;

    final totalBuses = companyDistribution.values.fold<int>(0, (sum, count) => sum + count);
    if (totalBuses == 0) return;

    double startAngle = -math.pi / 2; // Start from top

    // Draw pie slices
    for (final entry in companyDistribution.entries) {
      final companyCode = entry.key;
      final count = entry.value;
      final sweepAngle = (count / totalBuses) * 2 * math.pi;

      final paint = Paint()
        ..color = Company.getColorByCode(companyCode, customColors: customCompanyColors)
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Draw white border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius + strokeWidth / 2, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _PieChartPainter || oldDelegate.companyDistribution != companyDistribution || oldDelegate.customCompanyColors != customCompanyColors;
  }
}

class PlatformMap extends StatefulWidget {
  final ll.LatLng initialCenter;
  final double initialZoom;
  final List<Bus> buses;
  final List<BusStop> busStops;
  final Set<int> selectedCompanies;
  final List<String> selectedLines;
  final BusStop? selectedBusStop;
  final Map<int, Color> customCompanyColors;
  final Function(Bus) onBusMarkerTapped;
  final Function(BusCluster) onClusterMarkerTapped;
  final Function(BusStop)? onBusStopMarkerTapped;
  final Function(Function(ll.LatLng, double))? onMapReady;

  const PlatformMap({
    super.key,
    required this.initialCenter,
    required this.initialZoom,
    required this.buses,
    this.busStops = const [],
    this.selectedBusStop,
    required this.selectedCompanies,
    required this.selectedLines,
    this.customCompanyColors = const {},
    required this.onBusMarkerTapped,
    required this.onClusterMarkerTapped,
    this.onBusStopMarkerTapped,
    this.onMapReady,
  });

  @override
  State<PlatformMap> createState() => _PlatformMapState();
}

class _PlatformMapState extends State<PlatformMap> {
  fmap.MapController? _flutterMapController;
  double _currentZoom = 12.0;
  ll.LatLng _currentCenter = const ll.LatLng(-34.8941, -56.1650);

  bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  @override
  void initState() {
    super.initState();
    _currentZoom = widget.initialZoom;
    _currentCenter = widget.initialCenter;
    // Initialize controller for all platforms since we're using FlutterMap everywhere
    _flutterMapController = fmap.MapController();
  }

  void _centerMapToLocation(ll.LatLng center, double zoom) {
    logger.info('_centerMapToLocation called with: $center, zoom: $zoom');
    logger.info('Map controller is null: ${_flutterMapController == null}');

    if (_flutterMapController != null) {
      try {
        logger.info('Attempting to move map controller');
        _flutterMapController!.move(center, zoom);
        logger.info('Map controller move successful');
      } catch (e) {
        logger.error('Error moving map controller', e);
      }
    } else {
      logger.warning('Map controller is null, cannot move map');
    }

    setState(() {
      _currentCenter = center;
      _currentZoom = zoom;
      logger.info('Updated state: center=$_currentCenter, zoom=$_currentZoom');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) {
      return _buildFlutterMap();
    } else {
      //return _buildGoogleMap();
      return _buildFlutterMap();
    }
  }

  Widget _buildFlutterMap() {
    Widget toReturn = fmap.FlutterMap(
      mapController: _flutterMapController,
      options: fmap.MapOptions(
        initialCenter: widget.initialCenter,
        initialZoom: widget.initialZoom,
        minZoom: 3.0,
        maxZoom: 18.0,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture) {
            setState(() {
              _currentZoom = position.zoom;
              _currentCenter = position.center;
            });
          }
        },
        onMapReady: () {
          logger.info('FlutterMap is ready, controller available: ${_flutterMapController != null}');
          // Provide the center function to the parent widget now that the map is ready
          widget.onMapReady?.call(_centerMapToLocation);
        },
      ),
      children: [
        if (Theme.of(context).brightness == Brightness.light)
          fmap.TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.joaquincabrerasimoes.MiBondiUY',
            maxNativeZoom: 19,
          )
        else
          ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              -0.2126, -0.7152, -0.0722, 0, 255, // Red channel
              -0.2126, -0.7152, -0.0722, 0, 255, // Green channel
              -0.2126, -0.7152, -0.0722, 0, 255, // Blue channel
              0, 0, 0, 1, 0, // Alpha channel
            ]),
            child: fmap.TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.joaquincabrerasimoes.MiBondiUY',
              maxNativeZoom: 19,
            ),
          ),
        // Bus stops layer (rendered first, so buses appear on top)
        fmap.MarkerLayer(
          markers: _buildBusStopMarkers(),
        ),
        // Bus markers layer
        fmap.MarkerLayer(
          markers: _buildClusteredMarkers(),
        ),
      ],
    );

    return toReturn;
  }

  List<fmap.Marker> _buildBusStopMarkers() {
    // Only show bus stops when zoomed in enough to avoid clutter
    if (_currentZoom < 16.0) {
      return [];
    }

    // Calculate visible bounds based on current camera position and screen size
    final screenSize = MediaQuery.of(context).size;
    final visibleBounds = MarkerClustering.calculateVisibleBounds(_currentCenter, _currentZoom, screenSize);

    // Apply viewport culling - only show bus stops in visible area
    final visibleBusStops = widget.busStops.where((busStop) {
      return busStop.latitude >= visibleBounds.south && busStop.latitude <= visibleBounds.north && busStop.longitude >= visibleBounds.west && busStop.longitude <= visibleBounds.east;
    }).toList();

    logger.debug('Total bus stops: ${widget.busStops.length}, Visible: ${visibleBusStops.length}');

    return visibleBusStops.map((busStop) => _createBusStopMarker(busStop)).toList();
  }

  fmap.Marker _createBusStopMarker(BusStop busStop) {
    bool isSelectedBusStop = false;
    if (widget.selectedBusStop != null) {
      isSelectedBusStop = widget.selectedBusStop!.id == busStop.id;
    }

    return fmap.Marker(
      point: ll.LatLng(busStop.latitude, busStop.longitude),
      width: isSelectedBusStop ? 36 : 24.0,
      height: isSelectedBusStop ? 36 : 24.0,
      child: GestureDetector(
        onTap: () => widget.onBusStopMarkerTapped?.call(busStop),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.brown[700],
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: isSelectedBusStop ? Colors.green : (Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black), width: isSelectedBusStop ? 4 : 2),
            boxShadow: [
              BoxShadow(
                color: isSelectedBusStop ? Colors.green.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.3),
                blurRadius: isSelectedBusStop ? 6 : 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_bus_outlined,
            color: Colors.white,
            size: 12,
          ),
        ),
      ),
    );
  }

  List<fmap.Marker> _buildClusteredMarkers() {
    // Filter buses based on selected companies and lines
    final filteredBuses = widget.buses.where((bus) {
      // Apply company filter
      if (widget.selectedCompanies.isNotEmpty && !widget.selectedCompanies.contains(bus.codigoEmpresa)) {
        return false;
      }
      // Apply line filter
      if (widget.selectedLines.isNotEmpty && !widget.selectedLines.contains(bus.linea)) {
        return false;
      }
      return true;
    }).toList();

    // Calculate visible bounds based on current camera position and screen size
    final screenSize = MediaQuery.of(context).size;
    final visibleBounds = MarkerClustering.calculateVisibleBounds(_currentCenter, _currentZoom, screenSize);

    // Apply viewport culling - only show buses in visible area
    final visibleBuses = MarkerClustering.filterBusesInBounds(filteredBuses, visibleBounds);

    logger.trace('Total buses: ${widget.buses.length}, Filtered: ${filteredBuses.length}, Visible: ${visibleBuses.length}');

    // Cluster the visible buses
    final clusters = MarkerClustering.clusterBuses(visibleBuses, _currentZoom);

    // Create markers from clusters
    return clusters.map((cluster) {
      if (cluster.count == 1) {
        // Single bus marker
        return _createSingleBusMarker(cluster.buses.first);
      } else {
        // Cluster marker
        return _createClusterMarker(cluster);
      }
    }).toList();
  }

  fmap.Marker _createSingleBusMarker(Bus bus) {
    final color = Company.getColorByCode(bus.codigoEmpresa, customColors: widget.customCompanyColors);

    bool isLineOfSelectedBusStop = false;
    bool isUpcomingOfSelectedBusStop = false;

    if (widget.selectedBusStop != null) {
      if (widget.selectedBusStop!.lines != null) {
        logger.trace('Selected bus stop lines: ${widget.selectedBusStop!.lines}');
        isLineOfSelectedBusStop = widget.selectedBusStop!.lines!.any((line) => line.line == bus.linea);
      }
      if (widget.selectedBusStop!.upcomingBuses != null) {
        logger.trace('Selected bus stop upcoming buses: ${widget.selectedBusStop!.upcomingBuses}');
        isUpcomingOfSelectedBusStop = widget.selectedBusStop!.upcomingBuses!.any((upcoming) => upcoming.busId == bus.codigoBus);
      }
    }

    Widget markerContent = Text(
      bus.linea,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    );

    Widget shapeWidget;

    if (isUpcomingOfSelectedBusStop || isLineOfSelectedBusStop) {
      // 45-degree rotated square for buses of selected bus stop lines
      // Green shadow for upcoming buses, regular shadow for line buses
      shapeWidget = Transform.rotate(
        angle: math.pi / 4, // 45 degrees in radians
        child: Container(
          width: isUpcomingOfSelectedBusStop ? 34.0 : 28.0, // Slightly smaller to fit within bounds when rotated
          height: isUpcomingOfSelectedBusStop ? 34.0 : 28.0,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.rectangle,
            border: Border.all(color: isUpcomingOfSelectedBusStop ? Colors.green : (Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black), width: isUpcomingOfSelectedBusStop ? 4 : 2),
            boxShadow: [
              BoxShadow(
                color: isUpcomingOfSelectedBusStop ? Colors.green.withValues(alpha: 0.6) : Colors.black.withValues(alpha: 0.3),
                blurRadius: isUpcomingOfSelectedBusStop ? 6 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Transform.rotate(
            angle: -math.pi / 4, // Counter-rotate the text to keep it upright
            child: Center(child: markerContent),
          ),
        ),
      );
    } else {
      // Circle shape for regular buses
      shapeWidget = Container(
        width: 30.0,
        height: 30.0,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: markerContent),
      );
    }

    return fmap.Marker(
      point: ll.LatLng(bus.latitude, bus.longitude),
      width: isUpcomingOfSelectedBusStop
          ? 40.0
          : isLineOfSelectedBusStop
              ? 35.0
              : 30.0,
      height: isUpcomingOfSelectedBusStop
          ? 40.0
          : isLineOfSelectedBusStop
              ? 35.0
              : 30.0,
      child: GestureDetector(
        onTap: () => widget.onBusMarkerTapped(bus),
        child: shapeWidget,
      ),
    );
  }

  fmap.Marker _createClusterMarker(BusCluster cluster) {
    // Calculate company distribution in the cluster
    final companyDistribution = <int, int>{};
    for (final bus in cluster.buses) {
      companyDistribution[bus.codigoEmpresa] = (companyDistribution[bus.codigoEmpresa] ?? 0) + 1;
    }

    return fmap.Marker(
      point: cluster.center,
      width: 45.0, // 50% bigger than normal marker (30 * 1.5)
      height: 45.0,
      child: GestureDetector(
        onTap: () => widget.onClusterMarkerTapped(cluster),
        child: Container(
          width: 45.0,
          height: 45.0,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Pie chart background
              CustomPaint(
                painter: _PieChartPainter(
                  companyDistribution: companyDistribution,
                  strokeWidth: Theme.of(context).brightness == Brightness.light ? 3.0 : 3.0,
                  customCompanyColors: widget.customCompanyColors,
                ),
                size: const Size(45.0, 45.0),
              ),
              // Content overlay
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.directions_bus,
                      color: Colors.white,
                      size: 16,
                    ),
                    Text(
                      '${cluster.count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(0.5, 0.5),
                            blurRadius: 2.0,
                            color: Colors.black,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void updateBuses(List<Bus> buses) {
    setState(() {
      // The buses are passed from parent, so we just trigger a rebuild
    });
  }
}
