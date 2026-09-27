// lib/providers/rateable_provider.dart
import 'package:flutter/material.dart';

import '../core/app_logger.dart';
import '../services/api_service.dart';

class RateableProvider extends ChangeNotifier {
  static const _logTag = 'RateableProvider';

  /// ID товаров, которые пользователь купил, но ещё не оценил.
  Set<int> _rateableIds = {};
  bool _loaded = false;

  Set<int> get rateableIds => _rateableIds;
  bool get isLoaded => _loaded;

  /// Проверяет, можно ли оценить товар.
  bool canRate(int productId) => _rateableIds.contains(productId);

  /// Загружает список товаров для оценки с сервера.
  Future<void> loadRateable() async {
    final result = await ApiService.get(
      '/api/reviews/my',
      forceRefresh: true,
    );

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadRateable failed: ${result.errorOrNull?.message}',
      );
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return;

    final toRate = (data['to_rate'] as List?) ?? const [];

    _rateableIds = toRate
        .whereType<Map>()
        .map((item) {
          final id = item['id'];
          if (id is int) return id;
          if (id is String) return int.tryParse(id);
          return null;
        })
        .whereType<int>()
        .toSet();

    _loaded = true;
    notifyListeners();
  }

  /// Убирает товар из списка после успешной оценки.
  void markRated(int productId) {
    if (_rateableIds.remove(productId)) {
      notifyListeners();
    }
  }

  /// Сброс при логауте.
  void clear() {
    _rateableIds = {};
    _loaded = false;
    notifyListeners();
  }
}