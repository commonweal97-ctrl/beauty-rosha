// lib/providers/recommendation_provider.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  // 🔥 Кэш первой страницы — мгновенный старт при повторном запуске
  static const int _cacheTtlSeconds = 30 * 60; // 30 минут

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  bool get isLoaded => _isLoaded;

  /// Каждый провайдер определяет свой endpoint.
  String get endpoint;

  /// Каждый провайдер определяет параметры запроса.
  Map<String, dynamic> get queryParams => {};

  /// Уникальный ключ кэша для этого провайдера.
  String get _cacheKey {
    final type = queryParams['type'] ?? 'default';
    return 'rec_cache_${endpoint}_$type';
  }

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

  /// 🔥 Prefetch первых 8 картинок (card-размер) — мгновенное появление.
  /// Fire-and-forget: не блокирует UI, ошибки игнорируются.
  void _precacheFirstImages() {
    final items = _products.take(15).toList();
    final cm = DefaultCacheManager();
    AppLogger.info(_logTag, 'precaching ${items.length} images');
    for (var i = 0; i < items.length; i++) {
      final p = items[i];
      final url = p.imageUrlCard;
      if (url.isEmpty) continue;
      // Задержка между запросами (чтобы не было 429)
      Future.delayed(Duration(milliseconds: i * 50), () {
        unawaited(cm.downloadFile(url).then<void>((_) {}).catchError((_) {}));
      });
    }
  }

  /// Сохраняет первую страницу в кэш.
  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'ts': DateTime.now().millisecondsSinceEpoch,
        'products': _products.take(24).map((p) => p.toJson()).toList(),
      };
      await prefs.setString(_cacheKey, jsonEncode(data));
    } catch (e) {
      AppLogger.warning(_logTag, 'saveCache failed: $e');
    }
  }

  /// Загружает кэш (если свежий). Возвращает true при успехе.
  Future<bool> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.isEmpty) return false;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final ts = (data['ts'] as num?)?.toInt() ?? 0;
      final ageSec = (DateTime.now().millisecondsSinceEpoch - ts) ~/ 1000;
      if (ageSec > _cacheTtlSeconds) {
        AppLogger.info(_logTag, 'cache expired (age=${ageSec}s)');
        return false;
      }

      final list = (data['products'] as List?) ?? [];
      if (list.isEmpty) return false;

      _products = list
          .whereType<Map>()
          .map((p) => Product.fromJson(Map<String, dynamic>.from(p)))
          .toList();
      _isLoaded = true;
      _safeNotify();
      AppLogger.info(_logTag, 'cache loaded: ${_products.length} products, age=${ageSec}s');
      return true;
    } catch (e) {
      AppLogger.warning(_logTag, 'loadFromCache failed: $e');
      return false;
    }
  }

  Future<void> loadRecommendations() async {
    if (_isLoading || !_hasMore) {
      AppLogger.info(
        _logTag,
        'skip loading: isLoading=$_isLoading, hasMore=$_hasMore',
      );
      return;
    }

    // 🔥 Первая страница: пробуем отдать кэш мгновенно
    if (_page == 1 && !_isLoaded) {
      final fromCache = await _loadFromCache();
      if (fromCache && _isLoaded) {
        // Кэш свежий — не грузим сеть (без мигания)
        return;
      }
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

          // 🔥 Первая страница — в кэш + precache картинок
          if (_page == 2) {
            await _saveCache();
            _precacheFirstImages();
          }

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
    // 🔥 Кэш сбрасываем — рекомендации персональные
    SharedPreferences.getInstance().then((p) => p.remove(_cacheKey));
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