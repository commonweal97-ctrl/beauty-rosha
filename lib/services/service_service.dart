// lib/services/service_service.dart
import '../core/api_error.dart';
import '../core/result.dart';
import 'api_service.dart';

class ServiceService {
  static Map<String, dynamic>? _cachedPrices;
  static DateTime? _cacheTime;
  static const _cacheTtl = Duration(minutes: 10);

  /// 🔥 Единый источник цен на услуги сервисного центра
  /// Кэшируется на 10 минут
  static Future<Result<Map<String, dynamic>>> getPrices() async {
    // Возвращаем кэш, если свежий
    if (_cachedPrices != null && _cacheTime != null) {
      if (DateTime.now().difference(_cacheTime!) < _cacheTtl) {
        return Result.success(_cachedPrices!);
      }
    }

    final result = await ApiService.get('/api/service/prices');

    if (result.isFailure) {
      // Возвращаем кэш, если есть (даже устаревший)
      if (_cachedPrices != null) {
        return Result.success(_cachedPrices!);
      }
      return Result.failure(result.errorOrNull!);
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      if (_cachedPrices != null) {
        return Result.success(_cachedPrices!);
      }
      return Result.failure(
        const ServerError('Некорректный ответ API'),
      );
    }

    _cachedPrices = Map<String, dynamic>.from(data);
    _cacheTime = DateTime.now();

    return Result.success(_cachedPrices!);
  }

  /// Сбросить кэш (например, при pull-to-refresh)
  static void clearPricesCache() {
    _cachedPrices = null;
    _cacheTime = null;
  }

  static Future<Result<Map<String, dynamic>>> submitCourierRequest({
    required String address,
    required String date,
    required String time,
    required String items,
  }) async {
    return await ApiService.post('/api/service/courier-request', {
      'address': address,
      'date': date,
      'time': time,
      'items': items,
    });
  }
}
