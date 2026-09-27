// lib/services/catalog_service.dart
import '../core/app_logger.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/brand.dart';
import 'api_service.dart';

class CatalogResult {
  final List<Product> products;
  final int total;
  final int page;
  final int pages;
  final List<Map<String, dynamic>> badges;

  CatalogResult({
    required this.products,
    required this.total,
    required this.page,
    required this.pages,
    this.badges = const [],
  });
}

class CatalogService {
  static const _logTag = 'CatalogService';

  static Future<CatalogResult> getProducts({
    int page = 1,
    int limit = 24,
    int? categoryId,
    String? brand,
    String sort = 'popular',
    double? priceFrom,
    double? priceTo,
    String stock = 'all',
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (categoryId != null) params['category_id'] = categoryId.toString();
    if (sort != 'popular') params['sort'] = sort;
    if (priceFrom != null) params['price_from'] = priceFrom.toString();
    if (priceTo != null) params['price_to'] = priceTo.toString();
    if (brand != null && brand.isNotEmpty) params['brand'] = brand;
    if (stock != 'all') params['stock'] = stock;

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final url = '/api/products?$queryString';

    AppLogger.info(_logTag, 'GET $url');

    final result = await ApiService.get(url);

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'getProducts failed: ${result.errorOrNull?.message}',
      );
      return CatalogResult(products: [], total: 0, page: 1, pages: 1);
    }

    final response = result.valueOrNull;
    final data = response?['data'];

    if (data is! Map) {
      AppLogger.warning(_logTag, 'getProducts: no data');
      return CatalogResult(products: [], total: 0, page: 1, pages: 1);
    }

    final productsJson = (data['products'] as List?) ?? const [];
    final products = productsJson
        .map((p) => Product.fromJson(p as Map<String, dynamic>))
        .toList();

    AppLogger.info(
      _logTag,
      'getProducts: total=${data['total']}, '
      'loaded=${products.length}',
    );

    // Разбор badges
    final badges = <Map<String, dynamic>>[];
    final rawBadges = data['badges'];

    if (rawBadges is Map) {
      rawBadges.forEach((key, value) {
        if (value is Map) {
          badges.add({
            'product_id': int.tryParse(key.toString()),
            'text': value['text'],
            ...value,
          });
        }
      });
    } else if (rawBadges is List) {
      for (final b in rawBadges) {
        if (b is Map) {
          badges.add(Map<String, dynamic>.from(b));
        }
      }
    }

    return CatalogResult(
      products: products,
      total: data['total'] ?? 0,
      page: data['page'] ?? 1,
      pages: data['pages'] ?? 1,
      badges: badges,
    );
  }

  static Future<List<String>> getBrands({int? categoryId}) async {
    final params = categoryId != null ? '?category_id=$categoryId' : '';
    final result = await ApiService.get('/api/brands$params');

    if (result.isFailure) return [];

    final data = result.valueOrNull?['data'];
    if (data is! List) return [];

    return data
        .map((b) => b is String ? b : (b['name'] ?? b['brand'] ?? ''))
        .cast<String>()
        .toList();
  }

  static Future<List<Brand>> getBrandsList({int? categoryId}) async {
    final params = categoryId != null ? '?category_id=$categoryId' : '';
    final result = await ApiService.get('/api/brands$params');

    if (result.isFailure) return [];

    final data = result.valueOrNull?['data'];
    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((b) => Brand.fromJson(Map<String, dynamic>.from(b)))
        .toList();
  }

  static Future<List<Category>> getCategories({String? brand}) async {
    final params = (brand != null && brand.isNotEmpty)
        ? '?brand=${Uri.encodeComponent(brand)}'
        : '';
    final result = await ApiService.get('/api/categories$params');

    if (result.isFailure) return [];

    final data = result.valueOrNull?['data'];
    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((c) => Category.fromJson(Map<String, dynamic>.from(c)))
        .toList();
  }

  static Future<List<Category>> getSubcategories(int parentId) async {
    final result = await ApiService.get(
      '/api/mobile-menu/subcategories?parent_id=$parentId',
    );

    if (result.isFailure) return [];

    final data = result.valueOrNull?['data'];
    if (data is! Map) return [];

    final subJson = (data['subcategories'] as List?) ?? const [];

    return subJson
        .whereType<Map>()
        .map((s) => Category.fromJson(Map<String, dynamic>.from(s)))
        .toList();
  }
}