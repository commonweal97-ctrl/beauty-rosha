// lib/services/purchase_service.dart
import '../core/api_error.dart';
import '../core/app_logger.dart';
import '../models/product.dart';
import 'api_service.dart';

class PurchasedProduct {
  final Product product;
  final PurchaseInfo purchaseInfo;

  PurchasedProduct({required this.product, required this.purchaseInfo});

  factory PurchasedProduct.fromJson(Map<String, dynamic> json) {
    return PurchasedProduct(
      product: Product.fromJson(json['product'] ?? {}),
      purchaseInfo: PurchaseInfo.fromJson(json['purchase_info'] ?? {}),
    );
  }
}

class PurchaseInfo {
  final int orderId;
  final String orderDate;
  final int quantity;
  final double pricePaid;
  final bool isOffline;
  final bool canRate;
  final double? userRating;
  final int? reviewId;

  PurchaseInfo({
    required this.orderId,
    required this.orderDate,
    required this.quantity,
    required this.pricePaid,
    required this.isOffline,
    required this.canRate,
    this.userRating,
    this.reviewId,
  });

  factory PurchaseInfo.fromJson(Map<String, dynamic> json) {
    return PurchaseInfo(
      orderId: json['order_id'] ?? 0,
      orderDate: json['order_date'] ?? '',
      quantity: json['quantity'] ?? 1,
      pricePaid: (json['price_paid'] ?? 0).toDouble(),
      isOffline: json['is_offline'] ?? false,
      canRate: json['can_rate'] ?? false,
      userRating: json['user_rating']?.toDouble(),
      reviewId: json['review_id'],
    );
  }
}

class PurchaseStats {
  final int totalItems;
  final int ratedCount;
  final int unratedCount;

  PurchaseStats({
    required this.totalItems,
    required this.ratedCount,
    required this.unratedCount,
  });

  factory PurchaseStats.fromJson(Map<String, dynamic> json) {
    return PurchaseStats(
      totalItems: json['total_items'] ?? 0,
      ratedCount: json['rated_count'] ?? 0,
      unratedCount: json['unrated_count'] ?? 0,
    );
  }
}

class PurchasesResponse {
  final List<PurchasedProduct> items;
  final int total;
  final bool hasMore;
  final PurchaseStats stats;
  final Map<String, dynamic>? badges;

  PurchasesResponse({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.stats,
    this.badges,
  });

  factory PurchasesResponse.fromJson(Map<String, dynamic> json) {
    final itemsList = json['items'] as List<dynamic>?;
    final items = itemsList
            ?.whereType<Map>()
            .map((e) => PurchasedProduct.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [];

    // Дедубликация по product_id
    final seenIds = <int>{};
    final uniqueItems = <PurchasedProduct>[];

    for (final item in items) {
      final pid = item.product.id;
      if (!seenIds.contains(pid)) {
        seenIds.add(pid);
        uniqueItems.add(item);
      }
    }

    return PurchasesResponse(
      items: uniqueItems,
      total: uniqueItems.length,
      hasMore: json['has_more'] ?? false,
      stats: PurchaseStats.fromJson(json['stats'] ?? {}),
      badges: json['badges'] is Map
          ? Map<String, dynamic>.from(json['badges'] as Map)
          : null,
    );
  }
}

class PurchaseService {
  static const _logTag = 'PurchaseService';

  /// Загружает список покупок.
  /// При ошибке бросает [ApiError] — совместимо с существующим `try/catch`.
  static Future<PurchasesResponse> getItems({
    int page = 1,
    String sort = 'date_desc',
    String hasReview = 'all',
    bool inStock = false,
    String source = 'all',
    String? brand,
    String? search,
  }) async {
    await ApiService.loadCookies();

    final params = <String, String>{
      'page': page.toString(),
      'sort': sort,
      'has_review': hasReview,
      'in_stock': inStock ? '1' : '0',
      'source': source,
    };

    if (brand != null && brand.isNotEmpty) {
      params['brand'] = brand;
    }

    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }

    final queryString = params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final path = '/api/purchases/items?$queryString';
    final result = await ApiService.get(path);

    if (result.isFailure) {
      final error = result.errorOrNull ??
          const UnknownError('Не удалось загрузить покупки');
      AppLogger.warning(_logTag, 'getItems failed: ${error.message}');
      throw error;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      const error = ParseError('Invalid purchases response');
      AppLogger.warning(_logTag, 'getItems: data is not a Map');
      throw error;
    }

    try {
      return PurchasesResponse.fromJson(Map<String, dynamic>.from(data));
    } catch (e, st) {
      AppLogger.error(_logTag, 'getItems parse failed', e, st);
      throw ParseError('Failed to parse purchases', cause: e, stackTrace: st);
    }
  }

  /// Статистика покупок.
  /// При ошибке бросает [ApiError].
  static Future<PurchaseStats> getStats() async {
    await ApiService.loadCookies();
    final result = await ApiService.get('/api/purchases/stats');

    if (result.isFailure) {
      final error = result.errorOrNull ??
          const UnknownError('Не удалось загрузить статистику');
      AppLogger.warning(_logTag, 'getStats failed: ${error.message}');
      throw error;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      const error = ParseError('Invalid stats response');
      AppLogger.warning(_logTag, 'getStats: data is not a Map');
      throw error;
    }

    try {
      return PurchaseStats.fromJson(Map<String, dynamic>.from(data));
    } catch (e, st) {
      AppLogger.error(_logTag, 'getStats parse failed', e, st);
      throw ParseError('Failed to parse stats', cause: e, stackTrace: st);
    }
  }

  /// Бренды купленных товаров с логотипами.
  /// При ошибке — пустой список.
  static Future<List<Map<String, dynamic>>> getBrandsWithLogos() async {
    await ApiService.loadCookies();

    final brandsResult = await ApiService.get('/api/purchases/brands');
    List<String> purchasedBrandNames = [];

    if (brandsResult.isSuccess) {
      final brands = brandsResult.valueOrNull?['data']?['brands'];
      if (brands is List) {
        purchasedBrandNames = brands
            .map((b) => b?.toString() ?? '')
            .where((b) => b.isNotEmpty)
            .toList();
      }
    } else {
      AppLogger.warning(
        _logTag,
        'getBrandsWithLogos/purchases-brands failed: '
            '${brandsResult.errorOrNull?.message}',
      );
    }

    if (purchasedBrandNames.isEmpty) return [];

    final allBrandsResult = await ApiService.get('/api/brands');
    if (allBrandsResult.isFailure) {
      AppLogger.warning(
        _logTag,
        'getBrandsWithLogos/all-brands failed: '
            '${allBrandsResult.errorOrNull?.message}',
      );
      return [];
    }

    final allBrands = allBrandsResult.valueOrNull?['data'];
    if (allBrands is! List) return [];

    final result = <Map<String, dynamic>>[];
    for (final brand in allBrands) {
      if (brand is! Map) continue;
      final name = brand['name']?.toString() ?? '';
      if (purchasedBrandNames.contains(name)) {
        result.add({
          'name': name,
          'logo': brand['logo_url']?.toString() ?? '',
          'slug': brand['slug']?.toString() ?? '',
        });
      }
    }

    return result;
  }
}