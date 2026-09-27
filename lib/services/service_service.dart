// lib/services/service_service.dart
import '../core/result.dart';
import 'api_service.dart';

class ServiceService {
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