// lib/services/dadata_service.dart
// D-4 (Flutter F-1): Dadata SUGGESTIONS 403 -> свой backend /api/address/suggest (Photon)
// Формат совместим с Dadata (value, data.city, data.geo_lat) — вызывающий код не меняем.
// Токен Dadata убран (правило 79: утечка в APK).
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class DadataService {
  static const _path = '/api/address/suggest';

  static Future<List<Map<String, dynamic>>> suggest(String query) async {
    if (query.length < 3) return [];

    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$_path').replace(
        queryParameters: {'q': query},
      );
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = (data['data'] as List?) ?? [];
        return items.map((s) {
          final d = (s['data'] as Map?) ?? const {};
          return {
            'value': (s['value'] ?? s['display'] ?? '').toString(),
            'city': (d['city'] ?? s['city'] ?? '').toString(),
            'lat': d['geo_lat']?.toString(),
            'lon': d['geo_lon']?.toString(),
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }
}
