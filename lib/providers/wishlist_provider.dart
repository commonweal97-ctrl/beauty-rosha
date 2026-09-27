// lib/providers/wishlist_provider.dart
import 'package:flutter/material.dart';

import '../core/app_logger.dart';
import '../services/wishlist_service.dart';

class WishlistProvider extends ChangeNotifier {
  static const _logTag = 'WishlistProvider';

  final Map<int, bool> _wishlist = {};
  int _count = 0;

  Map<int, bool> get wishlist => _wishlist;
  int get count => _count;

  bool isInWishlist(int productId) => _wishlist[productId] ?? false;

  void setInWishlist(int productId, bool value) {
    _wishlist[productId] = value;
    notifyListeners();
  }

  Future<void> loadCount() async {
    _count = await WishlistService.getCount();
    notifyListeners();
  }

  /// Установка начального значения из `appInit()`.
  void setInitialCount(int count) {
    _count = count;
    notifyListeners();
  }

  Future<void> checkBatch(List<int> productIds) async {
    if (productIds.isEmpty) return;

    final result = await WishlistService.checkBatch(productIds);
    if (result.isEmpty) return;

    _wishlist.addAll(result);
    notifyListeners();
  }

  /// Переключает товар в/из избранного.
  ///
  /// Оптимистичное обновление: сразу меняем UI, а если запрос упал —
  /// откатываем изменение.
  Future<void> toggle(int productId) async {
    final wasInList = _wishlist[productId] ?? false;
    final previousCount = _count;

    // Оптимистично
    _wishlist[productId] = !wasInList;
    _count += wasInList ? -1 : 1;
    notifyListeners();

    final result = wasInList
        ? await WishlistService.remove(productId)
        : await WishlistService.add(productId);

    if (result.isFailure) {
      // Откат при ошибке
      _wishlist[productId] = wasInList;
      _count = previousCount;
      notifyListeners();

      AppLogger.warning(
        _logTag,
        'toggle($productId) failed: ${result.errorOrNull?.message}',
      );
      return;
    }

    // Синхронизируем count с сервером (если сервер вернул data.count)
    final serverCount = result.valueOrNull?['data']?['count'];
    if (serverCount is int && serverCount != _count) {
      _count = serverCount;
      notifyListeners();
    }
  }
}