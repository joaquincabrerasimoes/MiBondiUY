import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as ll;
import 'package:mibondiuy/models/bus.dart';
import 'package:mibondiuy/models/company.dart';

class BusCluster {
  final ll.LatLng center;
  final List<Bus> buses;
  final int count;

  BusCluster(this.center, this.buses) : count = buses.length;

  double get averageLatitude => buses.map((b) => b.latitude).reduce((a, b) => a + b) / buses.length;
  double get averageLongitude => buses.map((b) => b.longitude).reduce((a, b) => a + b) / buses.length;
}

class MarkerClustering {
  static const double _earthRadius = 6371000; // Earth radius in meters

  /// Calculate clustering distance based on zoom level
  /// Higher zoom = smaller clustering distance (more spread out)
  /// Lower zoom = larger clustering distance (more consolidated)
  static double _getClusteringDistance(double zoom) {
    if (zoom >= 16.5) return 0; // Very close zoom - 50m clustering
    if (zoom >= 16) return 50; // Very close zoom - 50m clustering
    if (zoom >= 15) return 100; // Very close zoom - 50m clustering
    if (zoom >= 14) return 200; // Close zoom - 100m clustering
    if (zoom >= 13) return 500; // Medium zoom - 200m clustering
    if (zoom >= 12) return 1000; // Medium zoom - 200m clustering
    if (zoom >= 11) return 2000; // Far zoom - 500m clustering
    if (zoom >= 10) return 5000; // Far zoom - 500m clustering
    if (zoom >= 9) return 10000; // Far zoom - 500m clustering
    return 20000; // Very far zoom - 1km clustering
  }

  /// Calculate distance between two points in meters using Haversine formula
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Calculate visible bounds from camera center, zoom, and screen size
  static fmap.LatLngBounds calculateVisibleBounds(ll.LatLng center, double zoom, Size screenSize) {
    // Web Mercator projection constants
    const double maxLatitude = 85.0511287798;

    // Calculate the resolution at the given zoom level
    // At zoom level 0, the world is 256 pixels wide
    final double resolution = 156543.03392 * math.cos(_degreesToRadians(center.latitude)) / math.pow(2, zoom);

    // Calculate half the width and height in meters
    final double halfWidthMeters = (screenSize.width / 2) * resolution;
    final double halfHeightMeters = (screenSize.height / 2) * resolution;

    // Convert meters to degrees
    final double deltaLat = (halfHeightMeters / _earthRadius) * (180 / math.pi);
    final double deltaLng = (halfWidthMeters / _earthRadius) * (180 / math.pi) / math.cos(_degreesToRadians(center.latitude));

    // Calculate bounds
    final double north = math.min(center.latitude + deltaLat, maxLatitude);
    final double south = math.max(center.latitude - deltaLat, -maxLatitude);
    final double east = center.longitude + deltaLng;
    final double west = center.longitude - deltaLng;

    // Handle longitude wrapping
    final double normalizedEast = east > 180 ? east - 360 : east;
    final double normalizedWest = west < -180 ? west + 360 : west;

    return fmap.LatLngBounds(
      ll.LatLng(south, normalizedWest),
      ll.LatLng(north, normalizedEast),
    );
  }

  /// Filter buses that are within the visible map bounds
  static List<Bus> filterBusesInBounds(List<Bus> buses, fmap.LatLngBounds? bounds) {
    if (bounds == null) return buses;

    return buses.where((bus) {
      final busLatLng = ll.LatLng(bus.latitude, bus.longitude);
      return bounds.contains(busLatLng);
    }).toList();
  }

  /// Cluster buses based on zoom level and proximity
  static List<BusCluster> clusterBuses(List<Bus> buses, double zoom) {
    if (buses.isEmpty) return [];

    final clusteringDistance = _getClusteringDistance(zoom);
    final clusters = <BusCluster>[];
    final processedBuses = <bool>[];

    // Initialize processed array
    for (int i = 0; i < buses.length; i++) {
      processedBuses.add(false);
    }

    for (int i = 0; i < buses.length; i++) {
      if (processedBuses[i]) continue;

      final currentBus = buses[i];
      final clusterBuses = <Bus>[currentBus];
      processedBuses[i] = true;

      // Find nearby buses to cluster
      for (int j = i + 1; j < buses.length; j++) {
        if (processedBuses[j]) continue;

        final otherBus = buses[j];
        final distance = _calculateDistance(
          currentBus.latitude,
          currentBus.longitude,
          otherBus.latitude,
          otherBus.longitude,
        );

        if (distance <= clusteringDistance) {
          clusterBuses.add(otherBus);
          processedBuses[j] = true;
        }
      }

      // Calculate cluster center (centroid)
      final centerLat = clusterBuses.map((b) => b.latitude).reduce((a, b) => a + b) / clusterBuses.length;
      final centerLon = clusterBuses.map((b) => b.longitude).reduce((a, b) => a + b) / clusterBuses.length;
      final center = ll.LatLng(centerLat, centerLon);

      clusters.add(BusCluster(center, clusterBuses));
    }

    return clusters;
  }

  /// Get the most common company color in a cluster for the marker
  static Color getClusterColor(List<Bus> buses) {
    if (buses.isEmpty) return Colors.blue;

    final companyCount = <int, int>{};
    for (final bus in buses) {
      companyCount[bus.codigoEmpresa] = (companyCount[bus.codigoEmpresa] ?? 0) + 1;
    }

    // Find the most common company
    int mostCommonCompany = companyCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    return Company.getColorByCode(mostCommonCompany);
  }
}
