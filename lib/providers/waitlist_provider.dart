// lib/providers/waitlist_provider.dart
import 'package:flutter/material.dart';

import '../core/app_logger.dart';
import '../services/waitlist_service.dart';

class WaitlistProvider extends ChangeNotifier {
  static const _logTag = 'WaitlistProvider';

  final Map<int, bool> _waitlist = {};
  int _count = 0;

  Map<int, bool> get waitlist => _waitlist;
  int get count => _count;

  bool isInWaitlist(int productId) => _waitlist[productId] ?? false;

  void setInWaitlist(int productId, bool value) {
    _waitlist[productId] = value;
    notifyListeners();
  }

  Future<void> loadCount() async {
    _count = await WaitlistService.getCount();
    notifyListeners();
  }

  void setInitialCount(int count) {
    _count = count;
    notifyListeners();
  }

  Future<void> checkBatch(List<int> productIds) async {
    if (productIds.isEmpty) return;

    // WaitlistService.checkBatch не бросает — при ошибке вернёт {}.
    final map = await WaitlistService.checkBatch(productIds);
    if (map.isEmpty) return;

    _waitlist.addAll(map);
    notifyListeners();
  }

  /// Переключает товар в/из листа ожидания.
  /// Возвращает `true` при успехе.
  Future<bool> toggle(int productId) async {
    final isInList = _waitlist[productId] ?? false;

    if (isInList) {
      final ok = await WaitlistService.remove(productId);
      if (!ok) {
        AppLogger.warning(_logTag, 'toggle($productId): remove failed');
        return false;
      }

      _waitlist[productId] = false;
      _count = (_count - 1).clamp(0, 999999);
      notifyListeners();
      return true;
    }

    final ok = await WaitlistService.add(productId);
    if (!ok) {
      AppLogger.warning(_logTag, 'toggle($productId): add failed');
      return false;
    }

    _waitlist[productId] = true;
    _count++;
    notifyListeners();
    return true;
  }
}