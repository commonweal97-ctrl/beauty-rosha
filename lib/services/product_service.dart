// lib/services/product_service.dart
import '../core/app_logger.dart';
import '../models/product_detail.dart';
import 'api_service.dart';

class ProductService {
  static const _logTag = 'ProductService';

  /// Детальная информация о товаре. `null` при ошибке.
  static Future<ProductDetail?> getDetail(String slug, String city) async {
    final url = '/api/products/detail'
        '?slug=${Uri.encodeComponent(slug)}'
        '&city=${Uri.encodeComponent(city)}';

    final result = await ApiService.get(url);

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'getDetail("$slug") failed: ${result.errorOrNull?.message}',
      );
      return null;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      AppLogger.warning(_logTag, 'getDetail("$slug"): no data');
      return null;
    }

    // Парсинг может упасть на неожиданных данных сервера
    try {
      final map = Map<String, dynamic>.from(data);
      AppLogger.info(
        _logTag,
        'getDetail("$slug"): delivery=${map['delivery']}',
      );
      return ProductDetail.fromJson(map);
    } catch (e, st) {
      AppLogger.error(_logTag, 'getDetail("$slug") parse failed', e, st);
      return null;
    }
  }

  /// Трекинг просмотра. Fire-and-forget, ошибки не критичны.
  static Future<void> trackView(int productId) async {
    final result = await ApiService.post(
      '/api/products/view',
      {'product_id': productId},
    );

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'trackView($productId) failed: ${result.errorOrNull?.message}',
      );
    }
  }

  /// Кросс-селлы для списка товаров. При ошибке — пустой список.
  static Future<List<ProductCrossSell>> getCrossSells(
    List<int> productIds,
  ) async {
    if (productIds.isEmpty) return [];

    final ids = productIds.join(',');
    final result =
        await ApiService.get('/api/products/cross-sells?product_ids=$ids');

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'getCrossSells(${productIds.length}) failed: '
            '${result.errorOrNull?.message}',
      );
      return [];
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return [];

    final products = (data['products'] as List?) ?? const [];

    return products
        .whereType<Map>()
        .map((p) => ProductCrossSell.fromJson(Map<String, dynamic>.from(p)))
        .toList();
  }
}