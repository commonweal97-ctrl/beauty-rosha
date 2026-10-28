import '../core/api_error.dart';
import '../core/result.dart';
import '../models/cancellation_info.dart';
import 'api_service.dart';

/// Сервис для работы с заказами (preview и отмена).
class OrdersApi {
  /// Preview отмены заказа — возвращает CancellationInfo.
  static Future<Result<CancellationInfo>> cancelPreview(int orderId) async {
    final result = await ApiService.post(
      '/api/orders/cancel-preview',
      {'order_id': orderId},
    );

    if (result.isFailure) {
      return Result.failure(result.errorOrNull ?? const ServerError('Ошибка сети'));
    }

    final response = result.valueOrNull;
    if (response == null || response['success'] != true) {
      return Result.failure(
        ServerError(
          response?['message']?.toString() ?? 'Не удалось получить preview отмены',
        ),
      );
    }

    final data = response['data'];
    if (data is! Map) {
      return Result.failure(const ParseError('Некорректный ответ сервера'));
    }

    try {
      return Result.success(
        CancellationInfo.fromJson(Map<String, dynamic>.from(data)),
      );
    } catch (e, st) {
      return Result.failure(UnknownError('Ошибка парсинга', cause: e, stackTrace: st));
    }
  }

  /// Отменить заказ.
  static Future<Result<void>> cancel(int orderId) async {
    final result = await ApiService.post(
      '/api/orders/cancel',
      {'order_id': orderId},
    );

    if (result.isFailure) {
      return Result.failure(result.errorOrNull ?? const ServerError('Ошибка сети'));
    }

    final response = result.valueOrNull;
    if (response == null || response['success'] != true) {
      return Result.failure(
        ServerError(
          response?['message']?.toString() ?? 'Не удалось отменить заказ',
        ),
      );
    }

    return Result.success(null);
  }
}
