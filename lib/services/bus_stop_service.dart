import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mibondiuy/models/bus_stop.dart';

class BusStopService {
  static const String _tokenCacheKey = 'oauth_token';
  static const String _tokenTimeCacheKey = 'oauth_token_time';
  static const String _busStopsCacheKey = 'bus_stops_cache';
  static const String _busStopsTimeCacheKey = 'bus_stops_cache_time';
  static const String _busStopLinesCacheKey = 'bus_stop_lines_cache';
  static const String _busStopLinesTimeCacheKey = 'bus_stop_lines_cache_time';
  static const int _tokenExpiryMinutes = 5; // Tokens expire after 5 minutes
  static const int _tokenRefreshMinutes = 4; // Refresh proactively after 4 minutes
  static const int _cacheExpiryHours = 24; // Cache bus stops for 24 hours
  static const int _linesCacheExpiryMinutes = 30; // Cache lines for 30 minutes

  static String get _accessTokenUrl => dotenv.env['ACCESS_TOKEN_URL'] ?? '';
  static String get _clientId => dotenv.env['CLIENT_ID'] ?? '';
  static String get _clientSecret => dotenv.env['CLIENT_SECRET'] ?? '';
  static String get _busStopsApi => dotenv.env['BUS_STOPS_API'] ?? '';
  static String get _busStopsApiLines => dotenv.env['BUS_STOPS_API_LINES'] ?? '';
  static String get _busStopsApiUpcoming => dotenv.env['BUS_STOPS_API_UPCOMING'] ?? '';

  /// Gets a valid OAuth 2.0 token, either from cache or by requesting a new one
  /// Proactively refreshes the token if it's older than 4 minutes (before the 5-minute expiry)
  static Future<String?> getValidatedToken() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedToken = prefs.getString(_tokenCacheKey);
    final tokenTime = prefs.getInt(_tokenTimeCacheKey);

    if (cachedToken != null && tokenTime != null) {
      final tokenAge = DateTime.now().millisecondsSinceEpoch - tokenTime;
      final ageInMinutes = tokenAge / (1000 * 60);

      // Refresh token proactively before expiry
      if (ageInMinutes < _tokenRefreshMinutes) {
        return cachedToken;
      }
    }

    // Token is expired, close to expiry, or doesn't exist - get a new one
    return await _requestNewToken();
  }

  /// Gets a valid OAuth 2.0 token, either from cache or by requesting a new one
  /// @deprecated Use getValidatedToken() instead for better token management
  static Future<String?> _getValidToken() async {
    return await getValidatedToken();
  }

  /// Requests a new OAuth 2.0 token from the server
  static Future<String?> _requestNewToken() async {
    try {
      final response = await http.post(
        Uri.parse(_accessTokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'grant_type': 'client_credentials',
          'client_id': _clientId,
          'client_secret': _clientSecret,
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final token = data['access_token'];

        if (token != null) {
          // Cache the token
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_tokenCacheKey, token);
          await prefs.setInt(_tokenTimeCacheKey, DateTime.now().millisecondsSinceEpoch);

          return token;
        }
      }

      throw Exception('Failed to get access token: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error requesting access token: $e');
    }
  }

  /// Gets bus stops from cache or API
  static Future<List<BusStop>> getBusStops({bool forceRefresh = false}) async {
    print("Getting bus stops");
    if (!forceRefresh) {
      final cachedStops = await _getCachedBusStops();
      if (cachedStops != null) {
        print("Got bus stops from cache");
        return cachedStops;
      }
    }

    // Cache miss or force refresh, fetch from API
    print("Fetching bus stops from API");
    return await _fetchBusStopsFromApi();
  }

  /// Gets bus stops from local cache if available and not expired
  static Future<List<BusStop>?> _getCachedBusStops() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_busStopsCacheKey);
      final cacheTime = prefs.getInt(_busStopsTimeCacheKey);

      if (cachedData != null && cacheTime != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;
        final ageInHours = cacheAge / (1000 * 60 * 60);

        if (ageInHours < _cacheExpiryHours) {
          final List<dynamic> jsonList = jsonDecode(cachedData);
          return jsonList.map((json) => BusStop.fromJson(json)).toList();
        }
      }
    } catch (e) {
      // If there's an error reading cache, return null to fetch from API
      debugPrint('Error reading bus stops cache: $e');
    }

    return null;
  }

  /// Fetches bus stops from the API
  static Future<List<BusStop>> _fetchBusStopsFromApi() async {
    final token = await getValidatedToken();
    if (token == null) {
      throw Exception('Unable to get valid access token');
    }

    try {
      final response = await http.get(
        Uri.parse(_busStopsApi),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        List<dynamic> stopsData;

        // Handle different API response formats
        if (data is List) {
          stopsData = data;
        } else if (data is Map && data.containsKey('data')) {
          stopsData = data['data'];
        } else if (data is Map && data.containsKey('stops')) {
          stopsData = data['stops'];
        } else {
          throw Exception('Unexpected API response format');
        }

        final busStops = stopsData.map((json) => BusStop.fromJson(json)).toList();

        // Cache the results
        await _cacheBusStops(busStops);

        return busStops;
      } else if (response.statusCode == 401) {
        // Token might be invalid, clear cache and try once more
        await _clearTokenCache();
        throw Exception('Authentication failed. Please try again.');
      } else {
        throw Exception('Failed to load bus stops: ${response.statusCode}');
      }
    } catch (e) {
      print(e);
      throw Exception('Error fetching bus stops: $e');
    }
  }

  /// Caches bus stops data locally
  static Future<void> _cacheBusStops(List<BusStop> busStops) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = busStops.map((stop) => stop.toJson()).toList();
      await prefs.setString(_busStopsCacheKey, jsonEncode(jsonList));
      await prefs.setInt(_busStopsTimeCacheKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error caching bus stops: $e');
    }
  }

  /// Clears the OAuth token cache
  static Future<void> _clearTokenCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenCacheKey);
    await prefs.remove(_tokenTimeCacheKey);
  }

  /// Clears the bus stops cache
  static Future<void> clearBusStopsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_busStopsCacheKey);
    await prefs.remove(_busStopsTimeCacheKey);
  }

  /// Refreshes bus stops cache by clearing it and fetching new data
  static Future<List<BusStop>> refreshBusStops() async {
    await clearBusStopsCache();
    return await getBusStops(forceRefresh: true);
  }

  /// Gets lines that pass through a specific bus stop
  static Future<List<BusLine>> getBusStopLines(String busStopId, {bool forceRefresh = false}) async {
    print("Getting lines for bus stop $busStopId");
    if (!forceRefresh) {
      final cachedLines = await _getCachedBusStopLines(busStopId);
      if (cachedLines != null) {
        print("Got lines from cache");
        return cachedLines;
      }
    }

    // Cache miss or force refresh, fetch from API
    print("Fetching lines from API");
    return await _fetchBusStopLinesFromApi(busStopId);
  }

  /// Gets lines from local cache if available and not expired
  static Future<List<BusLine>?> _getCachedBusStopLines(String busStopId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_busStopLinesCacheKey}_$busStopId';
      final timeCacheKey = '${_busStopLinesTimeCacheKey}_$busStopId';

      final cachedData = prefs.getString(cacheKey);
      final cacheTime = prefs.getInt(timeCacheKey);

      if (cachedData != null && cacheTime != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - cacheTime;
        final ageInMinutes = cacheAge / (1000 * 60);

        if (ageInMinutes < _linesCacheExpiryMinutes) {
          final List<dynamic> jsonList = jsonDecode(cachedData);
          return jsonList.map((json) => BusLine.fromJson(json)).toList();
        }
      }
    } catch (e) {
      // If there's an error reading cache, return null to fetch from API
      debugPrint('Error reading bus stop lines cache: $e');
    }

    return null;
  }

  /// Fetches lines for a specific bus stop from the API
  static Future<List<BusLine>> _fetchBusStopLinesFromApi(String busStopId) async {
    final token = await getValidatedToken();
    if (token == null) {
      throw Exception('Unable to get valid access token');
    }

    try {
      // Replace {busStopId} in the URL with the actual bus stop ID
      final apiUrl = _busStopsApiLines.replaceAll('{busStopId}', busStopId);

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        List<dynamic> linesData;

        // Handle different API response formats
        if (data is List) {
          linesData = data;
        } else if (data is Map && data.containsKey('data')) {
          linesData = data['data'];
        } else if (data is Map && data.containsKey('lines')) {
          linesData = data['lines'];
        } else if (data is Map && data.containsKey('results')) {
          linesData = data['results'];
        } else {
          // If it's a single object, wrap it in a list
          linesData = [data];
        }

        // Convert to BusLine objects
        final busLines = linesData.map((json) => BusLine.fromJson(json)).toList();

        // Cache the results (still cache as raw JSON for efficiency)
        await _cacheBusStopLines(busStopId, linesData);

        return busLines;
      } else if (response.statusCode == 401) {
        // Token might be invalid, clear cache and try once more
        await _clearTokenCache();
        throw Exception('Authentication failed. Please try again.');
      } else if (response.statusCode == 404) {
        // Bus stop not found or no lines available
        return [];
      } else {
        print(response);
        throw Exception('Failed to load bus stop lines: ${response.statusCode}');
      }
    } catch (e) {
      print(e);
      throw Exception('Error fetching bus stop lines: $e');
    }
  }

  /// Caches bus stop lines data locally
  static Future<void> _cacheBusStopLines(String busStopId, List<dynamic> linesData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '${_busStopLinesCacheKey}_$busStopId';
      final timeCacheKey = '${_busStopLinesTimeCacheKey}_$busStopId';

      await prefs.setString(cacheKey, jsonEncode(linesData));
      await prefs.setInt(timeCacheKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error caching bus stop lines: $e');
    }
  }

  /// Clears the bus stop lines cache for a specific bus stop
  static Future<void> clearBusStopLinesCache(String busStopId) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '${_busStopLinesCacheKey}_$busStopId';
    final timeCacheKey = '${_busStopLinesTimeCacheKey}_$busStopId';

    await prefs.remove(cacheKey);
    await prefs.remove(timeCacheKey);
  }

  /// Clears all bus stop lines caches
  static Future<void> clearAllBusStopLinesCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (String key in keys) {
      if (key.startsWith(_busStopLinesCacheKey) || key.startsWith(_busStopLinesTimeCacheKey)) {
        await prefs.remove(key);
      }
    }
  }

  /// Refreshes lines for a specific bus stop by clearing cache and fetching new data
  static Future<List<BusLine>> refreshBusStopLines(String busStopId) async {
    await clearBusStopLinesCache(busStopId);
    return await getBusStopLines(busStopId, forceRefresh: true);
  }

  /// Gets upcoming buses for a specific bus stop and lines
  /// This method does NOT cache data as it provides real-time information
  ///
  /// [busStopId] - The ID of the bus stop
  /// [lines] - List of line identifiers to get upcoming buses for
  /// Returns a list of [UpcomingBus] objects with real-time arrival information
  static Future<List<UpcomingBus>> getUpcomingBuses(String busStopId, List<String> lines) async {
    final token = await getValidatedToken();
    if (token == null) {
      throw Exception('Unable to get valid access token');
    }

    // Convert lines list to comma-separated string
    final busesList = lines.join(',');

    try {
      // Replace placeholders in the URL with actual values
      final apiUrl = _busStopsApiUpcoming.replaceAll('{busStopId}', busStopId).replaceAll('{busesList}', busesList.replaceAll(",", "%2C"));

      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        List<dynamic> upcomingBusesData;

        // Handle different API response formats
        if (data is List) {
          upcomingBusesData = data;
        } else if (data is Map && data.containsKey('data')) {
          upcomingBusesData = data['data'];
        } else if (data is Map && data.containsKey('buses')) {
          upcomingBusesData = data['buses'];
        } else if (data is Map && data.containsKey('results')) {
          upcomingBusesData = data['results'];
        } else {
          // If it's a single object, wrap it in a list
          upcomingBusesData = [data];
        }

        // Convert to UpcomingBus objects
        final upcomingBuses = upcomingBusesData.map((json) => UpcomingBus.fromJson(json)).toList();

        // Sort by ETA (earliest first)
        upcomingBuses.sort((a, b) => a.eta.compareTo(b.eta));

        return upcomingBuses;
      } else if (response.statusCode == 401) {
        // Token might be invalid, clear cache and try once more
        await _clearTokenCache();
        throw Exception('Authentication failed. Please try again.');
      } else if (response.statusCode == 404) {
        // Bus stop not found or no upcoming buses
        return [];
      } else {
        throw Exception('Failed to load upcoming buses: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching upcoming buses: $e');
    }
  }

  /// Gets upcoming buses for a specific bus stop using all available lines
  /// This is a convenience method that first fetches the lines for the bus stop
  /// and then gets upcoming buses for all those lines
  ///
  /// [busStopId] - The ID of the bus stop
  /// Returns a list of [UpcomingBus] objects with real-time arrival information
  static Future<List<UpcomingBus>> getUpcomingBusesForAllLines(String busStopId) async {
    try {
      // First get the lines for this bus stop
      final busLines = await getBusStopLines(busStopId);

      if (busLines.isEmpty) {
        return [];
      }

      // Extract the line names/codes
      final lineNames = busLines.map((line) => line.line).toList();

      // Get upcoming buses for all lines
      return await getUpcomingBuses(busStopId, lineNames);
    } catch (e) {
      throw Exception('Error fetching upcoming buses for all lines: $e');
    }
  }
}
