// lib/providers/support_badge_provider.dart
import 'package:flutter/material.dart';

import '../core/app_logger.dart';
import '../services/api_service.dart';

/// Провайдер счётчика непрочитанных сообщений поддержки.
///
/// Источники обновления:
/// 1. FCM-пуш с `data['type'] == 'support'` → [increment] (см. `PushService`).
/// 2. Открытие `SupportScreen` → [markAsRead] (сбрасывает в 0 + API).
/// 3. Периодический/стартовый [load] (API `/api/support/unread-count`).
class SupportBadgeProvider extends ChangeNotifier {
  static const _logTag = 'SupportBadgeProvider';

  int _unreadCount = 0;
  bool _isLoading = false;

  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  void _set(int count) {
    final clamped = count.clamp(0, 999);
    if (_unreadCount == clamped) return;
    _unreadCount = clamped;
    notifyListeners();
  }

  /// Инкремент при входящем пуше (`data['type'] == 'support'`).
  /// Если в пуше есть конкретное число — используем его (`data['count']`),
  /// иначе — +1.
  void increment({int? count}) {
    _set(_unreadCount + (count ?? 1));
  }

  /// Сброс при открытии `SupportScreen` (пользователь прочитал).
  Future<void> markAsRead() async {
    if (_unreadCount == 0) return;
    _set(0);

    final result = await ApiService.post('/api/support/unread-count/read', {});
    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'markAsRead failed: ${result.errorOrNull?.message}',
      );
    }
  }

  /// Загрузка при старте / по запросу.
  Future<void> load() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      final result = await ApiService.get('/api/support/unread-count');
      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'load failed: ${result.errorOrNull?.message}',
        );
        return;
      }
      final count = (result.valueOrNull?['data']?['count'] ?? 0) as int;
      _set(count);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
