// lib/providers/recommendation_provider.dart
import 'package:flutter/material.dart';

import '../core/app_logger.dart';
import '../models/product.dart';
import '../services/api_service.dart';

/// Базовый класс для всех провайдеров рекомендаций.
abstract class BaseRecommendationProvider extends ChangeNotifier {
  static const _logTag = 'Recommendations';

  List<Product> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  bool _isLoaded = false;
  bool _disposed = false;

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  bool get isLoaded => _isLoaded;

  /// Каждый провайдер определяет свой endpoint.
  String get endpoint;

  /// Каждый провайдер определяет параметры запроса.
  Map<String, dynamic> get queryParams => {};

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  void _applyBadges(List<Product> products, dynamic badges) {
    if (badges == null) return;

    Map<String, dynamic> badgesMap;
    if (badges is Map) {
      badgesMap = Map<String, dynamic>.from(badges);
    } else {
      return;
    }

    if (badgesMap.isEmpty) return;

    for (final product in products) {
      final badge = badgesMap[product.id.toString()];
      if (badge is Map) {
        product.badge = badge['text'] as String?;
      }
    }
  }

  /// Безопасное извлечение списка продуктов из data.
  List _extractProductsList(dynamic data) {
    if (data is List) return data;
    if (data is Map) return data['products'] ?? [];
    return [];
  }

  /// Безопасное извлечение badges из data.
  dynamic _extractBadges(dynamic data) {
    if (data is Map) return data['badges'];
    return null;
  }

  /// Безопасное извлечение has_more из data.
  bool _extractHasMore(dynamic data) {
    if (data is Map) return data['has_more'] ?? false;
    return false;
  }

  /// Безопасное извлечение total из data.
  int _extractTotal(dynamic data) {
    if (data is Map) return data['total'] ?? 0;
    return 0;
  }

  Future<void> loadRecommendations() async {
    if (_isLoading || !_hasMore) {
      AppLogger.info(
        _logTag,
        'skip loading: isLoading=$_isLoading, hasMore=$_hasMore',
      );
      return;
    }

    _isLoading = true;
    _safeNotify();

    try {
      final params = {
        'page': _page.toString(),
        'limit': '24',
        ...queryParams.map((key, value) => MapEntry(key, value.toString())),
      };

      AppLogger.info(
        _logTag,
        'loading page $_page from $endpoint with params: $params',
      );

      final result = await ApiService.get(
        endpoint,
        forceRefresh: _page == 1,
        queryParams: params,
      );

      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'loadRecommendations failed: ${result.errorOrNull?.message}',
        );
        _hasMore = false;
      } else {
        final data = result.valueOrNull?['data'];

        if (data == null) {
          AppLogger.warning(_logTag, 'no data in response');
          _hasMore = false;
        } else {
          final List productsJson = _extractProductsList(data);
          AppLogger.info(_logTag, 'loaded ${productsJson.length} products');

          if (productsJson.isEmpty) {
            AppLogger.info(_logTag, 'no products in response');
            _hasMore = false;
            _isLoading = false;
            _safeNotify();
            return;
          }

          final products =
              productsJson.map((p) => Product.fromJson(p)).toList();

          final badges = _extractBadges(data);
          _applyBadges(products, badges);

          if (_page == 1) {
            _products = products;
          } else {
            _products.addAll(products);
          }

          _isLoaded = true;

          final hasMoreFromApi = _extractHasMore(data);
          final total = _extractTotal(data);

          AppLogger.info(
            _logTag,
            'has_more=$hasMoreFromApi, total=$total, '
                'current=${_products.length}',
          );

          _hasMore = hasMoreFromApi == true || productsJson.length >= 24;
          if (_hasMore) _page++;

          AppLogger.info(_logTag, 'next page: $_page, hasMore: $_hasMore');
        }
      }
    } catch (e, st) {
      AppLogger.error(_logTag, 'loadRecommendations unexpected error', e, st);
      _hasMore = false;
    }

    _isLoading = false;
    _safeNotify();
  }

  Future<List<Product>> loadSimilarProducts(int productId) async {
    try {
      AppLogger.info(_logTag, 'loading similar for product $productId');

      final result = await ApiService.get(
        '/api/recommendations/product',
        forceRefresh: true,
        queryParams: {
          'product_id': productId.toString(),
          'limit': '12',
        },
      );

      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'loadSimilarProducts($productId) failed: '
              '${result.errorOrNull?.message}',
        );
        return [];
      }

      final data = result.valueOrNull?['data'];
      if (data == null) return [];

      final List productsJson = _extractProductsList(data);
      AppLogger.info(_logTag, 'loaded ${productsJson.length} similar products');

      if (productsJson.isEmpty) return [];

      final products = productsJson.map((p) => Product.fromJson(p)).toList();

      final badges = _extractBadges(data);
      _applyBadges(products, badges);

      return products;
    } catch (e, st) {
      AppLogger.error(
        _logTag,
        'loadSimilarProducts($productId) unexpected error',
        e,
        st,
      );
      return [];
    }
  }

  void reset() {
    AppLogger.info(_logTag, 'resetting provider state');
    _products = [];
    _page = 1;
    _hasMore = true;
    _isLoaded = false;
    _isLoading = false;
    _safeNotify();
  }

  Future<void> refresh() async {
    AppLogger.info(_logTag, 'refreshing recommendations');
    reset();
    await loadRecommendations();
  }
}

/// Провайдер для главной страницы.
class HomeRecommendationProvider extends BaseRecommendationProvider {
  @override
  String get endpoint => '/api/recommendations/user';

  @override
  Map<String, dynamic> get queryParams => {'type': 'home'};
}

/// Провайдер для профиля.
class ProfileRecommendationProvider extends BaseRecommendationProvider {
  @override
  String get endpoint => '/api/recommendations/user';

  @override
  Map<String, dynamic> get queryParams => {'type': 'profile'};
}

/// Провайдер для корзины.
class CartRecommendationProvider extends BaseRecommendationProvider {
  @override
  String get endpoint => '/api/recommendations/user';

  @override
  Map<String, dynamic> get queryParams => {'type': 'cart'};
}