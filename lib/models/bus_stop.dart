class BusStop {
  final String id;
  final String code;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;
  final List<String>? lines;

  BusStop({
    required this.id,
    required this.code,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
    this.lines,
  });

  factory BusStop.fromJson(Map<String, dynamic> json) {
    // Handle coordinates from location object
    double lat = 0.0;
    double lng = 0.0;

    if (json['location'] != null && json['location']['coordinates'] != null) {
      final coordinates = json['location']['coordinates'] as List<dynamic>;
      if (coordinates.length >= 2) {
        lng = coordinates[0].toDouble(); // longitude is first
        lat = coordinates[1].toDouble(); // latitude is second
      }
    }

    // Construct name from street intersections
    String constructedName = '';
    if (json['street1'] != null && json['street2'] != null) {
      constructedName = '${json['street1']} y ${json['street2']}';
    } else if (json['street1'] != null) {
      constructedName = json['street1'].toString();
    } else if (json['street2'] != null) {
      constructedName = json['street2'].toString();
    }

    return BusStop(
      id: json['busstopId']?.toString() ?? json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? json['busstopId']?.toString() ?? '',
      name: json['name']?.toString() ?? constructedName,
      latitude: json['latitude']?.toDouble() ?? json['lat']?.toDouble() ?? lat,
      longitude: json['longitude']?.toDouble() ?? json['lng']?.toDouble() ?? json['lon']?.toDouble() ?? lng,
      address: json['address']?.toString() ?? constructedName,
      lines: json['lines'] != null ? List<String>.from(json['lines'].map((x) => x.toString())) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      if (address != null) 'address': address,
      if (lines != null) 'lines': lines,
    };
  }
}

/// Represents a bus line that serves a bus stop
class BusLine {
  final int lineId;
  final String line;

  BusLine({
    required this.lineId,
    required this.line,
  });

  factory BusLine.fromJson(Map<String, dynamic> json) {
    return BusLine(
      lineId: json['lineId'] ?? 0,
      line: json['line']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lineId': lineId,
      'line': line,
    };
  }

  @override
  String toString() => line;
}

/// Represents an upcoming bus with real-time arrival information
class UpcomingBus {
  final int busId;
  final String companyName;
  final int lineVariantId;
  final String line;
  final String origin;
  final String destination;
  final String subline;
  final bool special;
  final int eta; // Estimated time of arrival in seconds
  final int distance; // Distance in meters
  final int position;
  final String access;
  final String thermalConfort;
  final String emissions;
  final BusLocation location;

  UpcomingBus({
    required this.busId,
    required this.companyName,
    required this.lineVariantId,
    required this.line,
    required this.origin,
    required this.destination,
    required this.subline,
    required this.special,
    required this.eta,
    required this.distance,
    required this.position,
    required this.access,
    required this.thermalConfort,
    required this.emissions,
    required this.location,
  });

  factory UpcomingBus.fromJson(Map<String, dynamic> json) {
    return UpcomingBus(
      busId: json['busId'] ?? 0,
      companyName: json['companyName']?.toString() ?? '',
      lineVariantId: json['lineVariantId'] ?? 0,
      line: json['line']?.toString() ?? '',
      origin: json['origin']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      subline: json['subline']?.toString() ?? '',
      special: json['special'] ?? false,
      eta: json['eta'] ?? 0,
      distance: json['distance'] ?? 0,
      position: json['position'] ?? 0,
      access: json['access']?.toString() ?? '',
      thermalConfort: json['thermalConfort']?.toString() ?? '',
      emissions: json['emissions']?.toString() ?? '',
      location: BusLocation.fromJson(json['location'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'busId': busId,
      'companyName': companyName,
      'lineVariantId': lineVariantId,
      'line': line,
      'origin': origin,
      'destination': destination,
      'subline': subline,
      'special': special,
      'eta': eta,
      'distance': distance,
      'position': position,
      'access': access,
      'thermalConfort': thermalConfort,
      'emissions': emissions,
      'location': location.toJson(),
    };
  }

  /// Returns ETA formatted as minutes and seconds
  String get formattedEta {
    if (eta <= 0) return 'Arriving now';
    if (eta < 60) return '${eta}s';

    final minutes = eta ~/ 60;
    final seconds = eta % 60;

    if (seconds == 0) return '${minutes}m';
    return '${minutes}m ${seconds}s';
  }

  /// Returns distance formatted in meters or kilometers
  String get formattedDistance {
    if (distance < 1000) return '${distance}m';
    final km = (distance / 1000).toStringAsFixed(1);
    return '${km}km';
  }
}

/// Represents the location of a bus
class BusLocation {
  final String type;
  final List<double> coordinates; // [longitude, latitude]

  BusLocation({
    required this.type,
    required this.coordinates,
  });

  factory BusLocation.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as List<dynamic>? ?? [];
    return BusLocation(
      type: json['type']?.toString() ?? 'Point',
      coordinates: List<double>.from(coords.map((coord) => coord.toDouble())),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'coordinates': coordinates,
    };
  }

  /// Returns longitude (first coordinate)
  double get longitude => coordinates.isNotEmpty ? coordinates[0] : 0.0;

  /// Returns latitude (second coordinate)
  double get latitude => coordinates.length > 1 ? coordinates[1] : 0.0;
}
