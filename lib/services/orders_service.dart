// lib/services/orders_service.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_logger.dart';
import 'api_service.dart';

class OrdersService {
  static const _logTag = 'OrdersService';

  static const String _cacheKey = 'cached_orders_data';
  static const String _cacheTimestampKey = 'cached_orders_timestamp';
  static const Duration _cacheMaxAge = Duration(minutes: 5);

  /// Загружает заказы: сначала кэш, потом обновляет в фоне.
  static Future<OrdersResult> loadOrders({
    bool forceRefresh = false,
  }) async {
    // 1. Пробуем загрузить из кэша
    CachedOrders? cachedOrders;
    if (!forceRefresh) {
      cachedOrders = await _loadFromCache();
    }

    // 2. Если кэш свежий и не принудительное обновление — возвращаем сразу
    if (cachedOrders != null && !forceRefresh) {
      _refreshInBackground();
      return OrdersResult(data: cachedOrders.orders, isFromCache: true);
    }

    // 3. Загружаем с сервера
    try {
      final orders = await _fetchFromServer();
      await _saveToCache(orders);
      return OrdersResult(data: orders, isFromCache: false);
    } catch (e) {
      AppLogger.warning(_logTag, 'loadOrders failed', e);

      // Если сервер недоступен, но есть кэш — отдаём кэш
      if (cachedOrders != null) {
        return OrdersResult(data: cachedOrders.orders, isFromCache: true);
      }
      rethrow;
    }
  }

  /// Загружает из SharedPreferences.
  static Future<CachedOrders?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimestampKey);
      final json = prefs.getString(_cacheKey);

      if (timestamp == null || json == null) return null;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(cacheTime) > _cacheMaxAge) {
        return null;
      }

      final orders = (jsonDecode(json) as List)
          .whereType<Map>()
          .map((o) => Map<String, dynamic>.from(o))
          .toList();

      return CachedOrders(orders: orders, timestamp: cacheTime);
    } catch (e) {
      AppLogger.warning(_logTag, 'loadFromCache failed', e);
      return null;
    }
  }

  /// Сохраняет в SharedPreferences.
  static Future<void> _saveToCache(
    List<Map<String, dynamic>> orders,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(orders));
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      AppLogger.warning(_logTag, 'saveToCache failed', e);
    }
  }

  /// Фоновое обновление кэша.
  static Future<void> _refreshInBackground() async {
    try {
      final orders = await _fetchFromServer();
      await _saveToCache(orders);
    } catch (e) {
      AppLogger.warning(_logTag, 'refreshInBackground failed', e);
    }
  }

  /// Основной метод загрузки с сервера.
  static Future<List<Map<String, dynamic>>> _fetchFromServer() async {
    // 1. Загружаем историю заказов
    final historyResult = await ApiService.get('/api/orders/history');

    if (historyResult.isFailure) {
      throw Exception(
        'Failed to load orders history: '
        '${historyResult.errorOrNull?.message}',
      );
    }

    final historyData = historyResult.valueOrNull?['data'];
    if (historyData is! Map) {
      throw Exception('Invalid orders history response');
    }

    final ordersRaw = (historyData['orders'] as List?) ?? const [];
    final orders = ordersRaw
        .whereType<Map>()
        .map((o) => Map<String, dynamic>.from(o))
        .toList();

    if (orders.isEmpty) return [];

    // 2. Извлекаем ID заказов
    final orderIds = orders
        .map((o) => o['id'])
        .where((id) => id != null)
        .map((id) => id is int ? id : int.tryParse(id.toString()) ?? 0)
        .where((id) => id > 0)
        .toList();

    if (orderIds.isEmpty) return orders;

    // 3. Загружаем детали пачкой
    final batchResult = await ApiService.post(
      '/api/orders/batch-details',
      {'order_ids': orderIds},
    );

    // 4. Сопоставляем изображения
    if (batchResult.isFailure) {
      AppLogger.warning(
        _logTag,
        'batch-details failed: ${batchResult.errorOrNull?.message}',
      );
      return orders;
    }

    final detailsMap = batchResult.valueOrNull?['data'];
    if (detailsMap is! Map) return orders;

    for (final order in orders) {
      final orderId = order['id'];
      final key =
          orderId is int ? orderId.toString() : orderId?.toString() ?? '';
      final items = detailsMap[key] as List? ?? [];

      for (final item in items) {
        if (item is! Map) continue;
        final img = item['main_image']?.toString() ?? '';
        if (img.isNotEmpty) {
          order['_first_image'] = img.startsWith('http')
              ? img
              : 'https://xn--80abvyjk6cts.xn--p1ai/$img';
          break;
        }
      }
    }

    return orders;
  }
}

/// Результат загрузки заказов.
class OrdersResult {
  final List<Map<String, dynamic>> data;
  final bool isFromCache;

  OrdersResult({required this.data, this.isFromCache = false});
}

/// Закешированные данные.
class CachedOrders {
  final List<Map<String, dynamic>> orders;
  final DateTime timestamp;

  CachedOrders({required this.orders, required this.timestamp});
}