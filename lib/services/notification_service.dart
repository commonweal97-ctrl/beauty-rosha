// lib/services/notification_service.dart
import 'dart:async';
import 'package:flutter/services.dart';

import '../core/app_logger.dart';
import 'api_service.dart';

/// Сервис для работы с уведомлениями.
class NotificationService {
  static const _logTag = 'NotificationService';

  static final NotificationService _instance =
      NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const _channel = MethodChannel('com.beautyrosha.beautyRosha/badge');

  int? _cachedUnreadCount;
  DateTime? _cacheTimestamp;
  static const Duration _cacheTtl = Duration(seconds: 10);

  bool _isLoadingUnreadCount = false;
  final List<Completer<int>> _pendingUnreadRequests = [];

  // ========================================================================
  // ПОЛУЧЕНИЕ УВЕДОМЛЕНИЙ
  // ========================================================================

  Future<Map<String, dynamic>> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final result = await ApiService.get(
      '/api/notifications',
      queryParams: {
        'page': page.toString(),
        'limit': limit.toString(),
      },
      forceRefresh: true,
    );

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'getNotifications failed: ${result.errorOrNull?.message}',
      );
      return {
        'success': false,
        'message': result.errorOrNull?.userMessage ?? 'Ошибка загрузки',
      };
    }

    final response = result.valueOrNull ?? const {};
    final unread = response['data']?['unread'];
    if (unread != null) {
      final count = _parseInt(unread);
      _updateCachedUnreadCount(count);
      _setBadge(count);
    }
    return response;
  }

  // ========================================================================
  // КОЛИЧЕСТВО НЕПРОЧИТАННЫХ
  // ========================================================================

  Future<int> getUnreadCount() async {
    if (_isCacheValid()) return _cachedUnreadCount!;

    // Дедупликация параллельных запросов
    if (_isLoadingUnreadCount) {
      final completer = Completer<int>();
      _pendingUnreadRequests.add(completer);
      return completer.future;
    }

    _isLoadingUnreadCount = true;

    try {
      final result = await ApiService.get(
        '/api/notifications/unread-count',
        forceRefresh: true,
      );

      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'getUnreadCount failed: ${result.errorOrNull?.message}',
        );
        final fallback = _cachedUnreadCount ?? 0;
        _resolvePendingRequests(fallback);
        return fallback;
      }

      final countData = result.valueOrNull?['data']?['count'] ?? 0;
      final count = _parseInt(countData);
      _updateCachedUnreadCount(count);
      _resolvePendingRequests(count);
      return count;
    } finally {
      _isLoadingUnreadCount = false;
    }
  }

  Future<int> refreshUnreadCount() async {
    _invalidateCache();
    return getUnreadCount();
  }

  // ========================================================================
  // ИЗМЕНЕНИЕ СТАТУСА
  // ========================================================================

  Future<bool> markAsRead(dynamic notificationId) async {
    final id = _parseId(notificationId);
    if (id == null) return false;

    // Оптимистичное уменьшение
    final previousCount = _cachedUnreadCount;
    if (_cachedUnreadCount != null && _cachedUnreadCount! > 0) {
      _cachedUnreadCount = _cachedUnreadCount! - 1;
    }

    final result = await ApiService.post(
      '/api/notifications/read',
      {'id': id},
    );

    if (result.isFailure) {
      // Откат
      _cachedUnreadCount = previousCount;
      AppLogger.warning(
        _logTag,
        'markAsRead($id) failed: ${result.errorOrNull?.message}',
      );
      return false;
    }

    await _applyServerCount(result.valueOrNull);
    return true;
  }

  Future<bool> markAllAsRead() async {
    final result = await ApiService.post(
      '/api/notifications/read',
      {'all': true},
    );

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'markAllAsRead failed: ${result.errorOrNull?.message}',
      );
      return false;
    }

    _updateCachedUnreadCount(0);
    await _setBadge(0);
    return true;
  }

  // ========================================================================
  // УДАЛЕНИЕ
  // ========================================================================

  Future<bool> deleteNotification(dynamic notificationId) async {
    final id = _parseId(notificationId);
    if (id == null) return false;

    final result = await ApiService.post(
      '/api/notifications/delete',
      {'id': id},
    );

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'deleteNotification($id) failed: ${result.errorOrNull?.message}',
      );
      return false;
    }

    await _applyServerCount(result.valueOrNull);
    return true;
  }

  Future<bool> deleteNotifications(List<int> ids) async {
    if (ids.isEmpty) return false;

    final result = await ApiService.post(
      '/api/notifications/delete',
      {'ids': ids},
    );

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'deleteNotifications(${ids.length}) failed: '
            '${result.errorOrNull?.message}',
      );
      return false;
    }

    await _applyServerCount(result.valueOrNull);
    return true;
  }

  // ========================================================================
  // BADGE
  // ========================================================================

  Future<void> _setBadge(int count) async {
    try {
      await _channel.invokeMethod('setBadge', count);
    } catch (e) {
      AppLogger.warning(_logTag, 'setBadge($count) failed', e);
    }
  }

  Future<void> clearBadge() async {
    try {
      await _channel.invokeMethod('clearBadge');
    } catch (e) {
      AppLogger.warning(_logTag, 'clearBadge failed', e);
    }
  }

  // ========================================================================
  // ПРИВАТНЫЕ
  // ========================================================================

  /// Извлекает `unread_count` из ответа, обновляет кэш и badge.
  /// Используется во всех мутирующих методах.
  Future<void> _applyServerCount(Map<String, dynamic>? response) async {
    final raw = response?['data']?['unread_count'] ?? 0;
    final count = _parseInt(raw);
    _updateCachedUnreadCount(count);
    await _setBadge(count);
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _parseId(dynamic id) {
    if (id is int) return id;
    if (id is String) return int.tryParse(id);
    return null;
  }

  bool _isCacheValid() {
    return _cachedUnreadCount != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheTtl;
  }

  void _updateCachedUnreadCount(int count) {
    _cachedUnreadCount = count;
    _cacheTimestamp = DateTime.now();
  }

  void _invalidateCache() {
    _cachedUnreadCount = null;
    _cacheTimestamp = null;
  }

  void _resolvePendingRequests(int count) {
    for (final completer in _pendingUnreadRequests) {
      if (!completer.isCompleted) {
        completer.complete(count);
      }
    }
    _pendingUnreadRequests.clear();
  }
}