// lib/services/wishlist_service.dart
import '../core/result.dart';
import 'api_service.dart';

class WishlistService {
  static Future<Result<Map<String, dynamic>>> getItems({
    int page = 1,
    int limit = 20,
    String? search,
    String? sort,
    bool? inStock,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (sort != null) params['sort'] = sort;
    if (inStock == true) params['in_stock'] = '1';

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return await ApiService.get('/api/wishlist/items?$queryString');
  }

  static Future<Result<Map<String, dynamic>>> add(int productId) async {
    return await ApiService.post('/api/wishlist/add', {
      'product_id': productId,
    });
  }

  static Future<Result<Map<String, dynamic>>> remove(int productId) async {
    return await ApiService.post('/api/wishlist/remove', {
      'product_id': productId,
    });
  }

  /// Пакетная проверка статусов: возвращает `Map<int, bool>`.
  /// При ошибке — пустая Map.
  static Future<Map<int, bool>> checkBatch(List<int> productIds) async {
    if (productIds.isEmpty) return {};

    final result = await ApiService.post('/api/wishlist/check-batch', {
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
    } else if (data is List) {
      for (final id in data) {
        final parsed = int.tryParse(id.toString());
        if (parsed != null) map[parsed] = true;
      }
    }

    return map;
  }

  /// Пакетное добавление. Возвращает новое количество.
  static Future<int?> addBatch(List<int> productIds) async {
    if (productIds.isEmpty) return null;

    final result = await ApiService.post('/api/wishlist/add-batch', {
      'product_ids': productIds,
    });

    if (result.isFailure) return null;
    return result.valueOrNull?['data']?['count'] as int?;
  }

  /// Пакетное удаление. Возвращает новое количество.
  static Future<int?> removeBatch(List<int> productIds) async {
    if (productIds.isEmpty) return null;

    final result = await ApiService.post('/api/wishlist/remove-batch', {
      'product_ids': productIds,
    });

    if (result.isFailure) return null;
    return result.valueOrNull?['data']?['count'] as int?;
  }

  /// Возвращает `true`, если товар в избранном.
  /// При ошибке сети/парсинга — `false`.
  static Future<bool> check(int productId) async {
    final result =
        await ApiService.get('/api/wishlist/check?product_id=$productId');
    if (result.isFailure) return false;
    return result.valueOrNull?['data']?['in_wishlist'] ?? false;
  }

  /// Возвращает количество товаров в избранном.
  /// При ошибке — `0`.
  static Future<int> getCount() async {
    final result = await ApiService.get('/api/wishlist/count');
    if (result.isFailure) return 0;
    return result.valueOrNull?['data']?['count'] ?? 0;
  }
}