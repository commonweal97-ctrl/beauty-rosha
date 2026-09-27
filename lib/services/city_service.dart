// lib/services/city_service.dart
import '../core/app_logger.dart';
import 'api_service.dart';

class CityService {
  static const _logTag = 'CityService';

  /// Поиск городов. При ошибке — пустой список.
  static Future<List<Map<String, dynamic>>> searchCities(
    String query, {
    String country = 'Россия',
  }) async {
    if (query.length < 2) return [];

    final result = await ApiService.get(
      '/api/city/search'
      '?q=${Uri.encodeComponent(query)}'
      '&country=${Uri.encodeComponent(country)}',
    );

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'searchCities("$query", $country) failed: '
            '${result.errorOrNull?.message}',
      );
      return [];
    }

    final data = result.valueOrNull?['data'];
    if (data is! List) return [];

    final cities = data
        .whereType<Map>()
        .map((c) => Map<String, dynamic>.from(c))
        .toList();

    AppLogger.info(
      _logTag,
      'searchCities("$query", $country): found ${cities.length}',
    );

    return cities;
  }

  /// Определение города по координатам. `null` при ошибке.
  static Future<Map<String, String>?> detectCity(double lat, double lng) async {
    final result = await ApiService.get('/api/city/detect?lat=$lat&lng=$lng');

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'detectCity($lat, $lng) failed: ${result.errorOrNull?.message}',
      );
      return null;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return null;

    return {
      'city': data['city']?.toString() ?? '',
      'country': data['country']?.toString() ?? 'Россия',
    };
  }

  /// Сохранение выбранного города.
  static Future<void> saveCity(
    String city, {
    String country = 'Россия',
  }) async {
    final result = await ApiService.post('/api/city/save', {
      'city': city,
      'country': country,
    });

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'saveCity("$city", $country) failed: ${result.errorOrNull?.message}',
      );
      return;
    }

    AppLogger.info(_logTag, 'saveCity: $city, $country');
  }
}