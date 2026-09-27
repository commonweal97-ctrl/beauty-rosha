// lib/services/waitlist_service.dart
import '../core/result.dart';
import 'api_service.dart';

class WaitlistService {
  /// Количество товаров в листе ожидания. При ошибке — `0`.
  static Future<int> getCount() async {
    final result = await ApiService.get(
      '/api/waitlist/count',
      forceRefresh: true,
    );

    if (result.isFailure) return 0;
    return result.valueOrNull?['data']?['count'] ?? 0;
  }

  static Future<Result<Map<String, dynamic>>> getItems({
    int page = 1,
    int limit = 20,
    String? search,
    String? sort,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (sort != null) params['sort'] = sort;

    return ApiService.get('/api/waitlist/items', queryParams: params);
  }

  /// Проверка: товар в листе ожидания. При ошибке — `false`.
  static Future<bool> isInWaitlist(int productId) async {
    final result = await ApiService.get(
      '/api/waitlist/check',
      queryParams: {'product_id': productId.toString()},
    );

    if (result.isFailure) return false;
    return result.valueOrNull?['data']?['in_waitlist'] ?? false;
  }

  /// Пакетная проверка. При ошибке — пустая Map.
  static Future<Map<int, bool>> checkBatch(List<int> productIds) async {
    if (productIds.isEmpty) return {};

    final result = await ApiService.post('/api/waitlist/check-batch', {
      'product_ids': productIds,
    });

    if (result.isFailure) return {};

    final data = result.valueOrNull?['data'];
    final map = <int, bool>{};

    if (data is Map) {
      data.forEach((key, value) {
        final id = int.tryParse(key.toString());
        if (id != null) map[id] = value == true;
      });
    }

    return map;
  }

  /// Добавление. `true` при успехе, `false` при ошибке.
  static Future<bool> add(int productId) async {
    final result = await ApiService.post('/api/waitlist/add', {
      'product_id': productId,
    });
    return result.isSuccess;
  }

  /// Удаление. `true` при успехе, `false` при ошибке.
  static Future<bool> remove(int productId) async {
    final result = await ApiService.post('/api/waitlist/remove', {
      'product_id': productId,
    });
    return result.isSuccess;
  }

  /// Пакетное удаление. `true` при успехе, `false` при ошибке.
  static Future<bool> removeBatch(List<int> productIds) async {
    if (productIds.isEmpty) return false;

    final result = await ApiService.post('/api/waitlist/remove-batch', {
      'product_ids': productIds,
    });
    return result.isSuccess;
  }

  static Future<Result<Map<String, dynamic>>> getCrossSells(
    List<int> productIds,
  ) async {
    return ApiService.get('/api/products/cross-sells', queryParams: {
      'product_ids': productIds.join(','),
    });
  }
}