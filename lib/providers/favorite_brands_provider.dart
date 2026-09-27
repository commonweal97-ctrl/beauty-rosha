// lib/providers/favorite_brands_provider.dart
import 'package:flutter/material.dart';

import '../core/app_logger.dart';
import '../services/api_service.dart';

class FavoriteBrandsProvider extends ChangeNotifier {
  static const _logTag = 'FavoriteBrandsProvider';

  final Map<int, bool> _favorites = {};
  final Set<int> _loading = {}; // бренды в процессе лайка
  int _count = 0;

  Map<int, bool> get favorites => _favorites;
  Set<int> get loading => _loading;
  int get count => _count;

  bool isFavorite(int brandId) => _favorites[brandId] ?? false;
  bool isLoading(int brandId) => _loading.contains(brandId);

  void setInitialCount(int count) {
    _count = count;
    notifyListeners();
  }

  Future<void> loadCount() async {
    _count = await ApiService.getFavoriteBrandsCount();
    notifyListeners();
  }

  Future<void> checkBatch(List<int> brandIds) async {
    if (brandIds.isEmpty) return;

    final result = await ApiService.checkFavoriteBrandsBatch(brandIds);

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'checkBatch failed: ${result.errorOrNull?.message}',
      );
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return;

    data.forEach((key, value) {
      final id = int.tryParse(key.toString());
      if (id != null) {
        _favorites[id] = value == true;
      }
    });

    notifyListeners();
  }

  Future<void> toggle(int brandId) async {
    if (brandId <= 0 || _loading.contains(brandId)) return;

    _loading.add(brandId);
    notifyListeners();

    try {
      final result = await ApiService.toggleFavoriteBrand(brandId);

      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'toggle($brandId) failed: ${result.errorOrNull?.message}',
        );
      } else {
        final data = result.valueOrNull?['data'];
        if (data is Map) {
          _favorites[brandId] =
              data['is_favorite'] ?? !(_favorites[brandId] ?? false);
          _count = data['count'] ?? _count;
        }
      }
    } finally {
      _loading.remove(brandId);
      notifyListeners();
    }
  }
}