// lib/services/loyalty_service.dart
import '../core/app_logger.dart';
import '../core/result.dart';
import 'api_service.dart';

class LoyaltyService {
  static const _logTag = 'LoyaltyService';

  /// Статус программы лояльности. При ошибке — пустая Map.
  static Future<Map<String, dynamic>> getStatus() async {
    final result = await ApiService.get('/api/loyalty/status');

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'getStatus failed: ${result.errorOrNull?.message}',
      );
      return {};
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return {};

    return Map<String, dynamic>.from(data);
  }

  /// Активация программы лояльности.
  static Future<Result<Map<String, dynamic>>> activate() async {
    return await ApiService.post('/api/loyalty/activate', {});
  }

  /// Создание платежа для программы лояльности.
  static Future<Result<Map<String, dynamic>>> createPayment() async {
    return await ApiService.post('/api/loyalty/create-payment', {});
  }
}