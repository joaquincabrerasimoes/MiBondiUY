import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mibondiuy/models/bus.dart';

class BusService {
  static String get _baseUrl => dotenv.env['BUS_LIVE_API1'] ?? '';
  static String get _origin => dotenv.env['BUS_LIVE_API1_ORIGIN'] ?? '';
  static String get _referer => dotenv.env['BUS_LIVE_API1_REFERER'] ?? '';

  static Future<List<Bus>> getBuses({int subsistema = -1, int empresa = -1, List<String>? lineas}) async {
    try {
      final Map<String, dynamic> requestBody = {'subsistema': subsistema.toString(), 'empresa': empresa.toString()};

      if (lineas != null && lineas.isNotEmpty) {
        requestBody['lineas'] = lineas;
      }

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json, text/javascript',
          'Origin': _origin,
          'Referer': _referer,
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> features = data['features'] ?? [];

        return features.map((feature) => Bus.fromJson(feature)).toList();
      } else {
        throw Exception('Failed to load buses: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching buses: $e');
    }
  }
}
