// lib/providers/cart_recommendation_provider.dart
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_logger.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class CartRecommendationProvider extends ChangeNotifier {
  static const _logTag = 'CartRecommendationProvider';

  List<Product> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  bool _isLoaded = false;
  bool _disposed = false;
  final int _seed = Random().nextInt(1000000);

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  bool get isLoaded => _isLoaded;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> loadRecommendations() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    _safeNotify();

    // Основной запрос
    final mainResult = await ApiService.get(
      '/api/recommendations/user?page=$_page&limit=24&seed=$_seed',
      forceRefresh: _page == 1,
    );

    if (_disposed) return;

    if (mainResult.isSuccess) {
      final data = mainResult.valueOrNull?['data'];
      if (data is Map) {
        _applyProductsFromData(data);
        _isLoading = false;
        _safeNotify();
        return;
      }
    } else {
      AppLogger.warning(
        _logTag,
        'recommendations failed: ${mainResult.errorOrNull?.message}, '
            'trying fallback',
      );
    }

    // Fallback: обычные товары
    final fallbackResult = await ApiService.get(
      '/api/products?page=$_page&limit=24&sort=random',
    );

    if (_disposed) return;

    if (fallbackResult.isFailure) {
      AppLogger.warning(
        _logTag,
        'fallback failed: ${fallbackResult.errorOrNull?.message}',
      );
      _isLoading = false;
      _safeNotify();
      return;
    }

    final fallbackData = fallbackResult.valueOrNull?['data'];
    if (fallbackData is Map) {
      _applyProductsFromData(fallbackData);
    }

    _isLoading = false;
    _safeNotify();
  }

  void _applyProductsFromData(Map data) {
    final productsRaw = data['products'];
    final productsJson = productsRaw is List
        ? productsRaw
            .whereType<Map>()
            .map((p) => Product.fromJson(Map<String, dynamic>.from(p)))
            .toList()
        : <Product>[];

    _products.addAll(productsJson);
    _isLoaded = true;
    _hasMore = data['has_more'] ?? false;
    if (_hasMore) _page++;
  }

  void reset() {
    _products = [];
    _page = 1;
    _hasMore = true;
    _isLoaded = false;
    _isLoading = false;
    _safeNotify();
  }

  Future<void> refresh() async {
    reset();
    await loadRecommendations();
  }
}