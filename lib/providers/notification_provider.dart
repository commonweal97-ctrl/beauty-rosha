// lib/providers/notification_provider.dart
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_logger.dart';
import '../services/api_service.dart';

/// Состояние уведомлений.
class NotificationState {
  final int unreadCount;
  final bool isLoading;
  final DateTime? lastUpdated;

  const NotificationState({
    this.unreadCount = 0,
    this.isLoading = false,
    this.lastUpdated,
  });

  NotificationState copyWith({
    int? unreadCount,
    bool? isLoading,
    DateTime? lastUpdated,
  }) {
    return NotificationState(
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// Базовое событие уведомлений.
abstract class NotificationEvent {}

/// Событие: уведомления прочитаны.
class NotificationReadEvent extends NotificationEvent {
  final int count;
  NotificationReadEvent({this.count = 0});
}

/// Событие: обновление счётчика.
class NotificationCountUpdateEvent extends NotificationEvent {
  final int count;
  NotificationCountUpdateEvent(this.count);
}

/// Глобальная событийная шина (Singleton).
class NotificationEventBus {
  static final NotificationEventBus _instance =
      NotificationEventBus._internal();
  factory NotificationEventBus() => _instance;
  NotificationEventBus._internal();

  final _controller = StreamController<NotificationEvent>.broadcast();
  Stream<NotificationEvent> get stream => _controller.stream;

  void add(NotificationEvent event) {
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}

/// Провайдер с кешированием и дебаунсом.
class NotificationProvider extends ChangeNotifier {
  static const _logTag = 'NotificationProvider';

  NotificationState _state = const NotificationState();
  StreamSubscription? _subscription;
  Timer? _debounceTimer;

  static const Duration _cacheTTL = Duration(minutes: 5);
  static const Duration _debounceDuration = Duration(milliseconds: 300);

  NotificationState get state => _state;
  int get unreadCount => _state.unreadCount;
  bool get isLoading => _state.isLoading;

  NotificationProvider() {
    _initEventBus();
  }

  void _initEventBus() {
    final bus = NotificationEventBus();
    _subscription = bus.stream.listen((event) {
      if (event is NotificationReadEvent) {
        _handleReadEvent(event);
      } else if (event is NotificationCountUpdateEvent) {
        _updateCount(event.count);
      }
    });
  }

  Future<void> loadUnreadCount({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheValid()) return;
    if (_state.isLoading) return;

    _setLoading(true);

    try {
      final result = await ApiService.get('/api/notifications/unread-count');

      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'loadUnreadCount failed: ${result.errorOrNull?.message}',
        );
        return;
      }

      final newCount = result.valueOrNull?['data']?['count'] ?? 0;
      _updateCount(newCount, updateTimestamp: true);
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refreshCount() async {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      loadUnreadCount(forceRefresh: true);
    });
    return Future.value();
  }

  void _updateCount(int count, {bool updateTimestamp = false}) {
    final clamped = count.clamp(0, 999);
    if (_state.unreadCount == clamped) return;

    _state = _state.copyWith(
      unreadCount: clamped,
      lastUpdated: updateTimestamp ? DateTime.now() : _state.lastUpdated,
    );

    _syncBadge(clamped);
    notifyListeners();
  }

  void _setLoading(bool loading) {
    if (_state.isLoading == loading) return;
    _state = _state.copyWith(isLoading: loading);
    notifyListeners();
  }

  bool _isCacheValid() {
    if (_state.lastUpdated == null) return false;
    return DateTime.now().difference(_state.lastUpdated!) < _cacheTTL;
  }

  void _handleReadEvent(NotificationReadEvent event) {
    if (event.count == 0 && _state.unreadCount == 0) return;

    if (event.count > 0) {
      final newCount = (_state.unreadCount - event.count).clamp(0, 999);
      _updateCount(newCount);
    } else {
      _updateCount(0);
    }
  }

  Future<void> _syncBadge(int count) async {
    final result = await ApiService.post(
      '/api/notifications/sync-badge',
      {'count': count},
    );

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'sync-badge($count) failed: ${result.errorOrNull?.message}',
      );
    }
  }

  void markAsRead(int count) {
    if (count <= 0) return;
    NotificationEventBus().add(NotificationReadEvent(count: count));
  }

  void markAllAsRead() {
    if (_state.unreadCount == 0) return;
    NotificationEventBus().add(NotificationReadEvent(count: _state.unreadCount));
  }

  void setUnreadCount(int count) {
    _updateCount(count);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }
}