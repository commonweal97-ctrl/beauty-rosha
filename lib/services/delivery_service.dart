// lib/services/delivery_service.dart
import '../core/app_logger.dart';
import 'api_service.dart';

class DeliveryService {
  static const _logTag = 'DeliveryService';

  static Future<Map<String, dynamic>> checkExceptions(String date) async {
    final result = await ApiService.get(
      '/api/admin/delivery-exceptions/check?date=$date',
    );

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'checkExceptions($date) failed: ${result.errorOrNull?.message}',
      );
      return {'full_day_blocked': false, 'blocked_slots': []};
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      return {'full_day_blocked': false, 'blocked_slots': []};
    }

    return Map<String, dynamic>.from(data);
  }
}