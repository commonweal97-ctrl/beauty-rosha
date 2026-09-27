// lib/services/dadata_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class DadataService {
  static const _token = '3a827d10d5f52ae61c7332285e85411439c58c7b';
  static const _url = 'https://suggestions.dadata.ru/suggestions/api/4_1/rs/suggest/address';

  static Future<List<Map<String, dynamic>>> suggest(String query) async {
    if (query.length < 3) return [];

    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $_token',
        },
        body: jsonEncode({
          'query': query,
          'count': 5,
          'locations': [{'region': 'Брянская'}],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final suggestions = data['suggestions'] as List? ?? [];
        return suggestions.map((s) => {
          'value': s['value'] as String,
          'city': s['data']?['city'] as String? ?? '',
          'lat': s['data']?['geo_lat'] as String?,
          'lon': s['data']?['geo_lon'] as String?,
        }).toList();
      }
    } catch (_) {}
    return [];
  }
}