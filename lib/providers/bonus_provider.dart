// lib/providers/bonus_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_logger.dart';
import '../services/api_service.dart';

class BonusProvider extends ChangeNotifier {
  static const _logTag = 'BonusProvider';

  int _balance = 0;
  bool _isLoading = false;
  bool _isLoaded = false;

  // Истекающие бонусы
  List<Map<String, dynamic>> _expiringBatches = [];
  int _totalExpiringSoon = 0;
  bool _isExpiringLoading = false;

  // Кэш
  static const String _cacheKey = 'cached_bonus_balance';
  static const String _cacheTimeKey = 'cached_bonus_balance_time';
  static const int _cacheTtlSeconds = 300; // 5 минут

  int get balance => _balance;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  List<Map<String, dynamic>> get expiringBatches => _expiringBatches;
  int get totalExpiringSoon => _totalExpiringSoon;
  bool get isExpiringLoading => _isExpiringLoading;

  /// Загрузка баланса с кешированием.
  Future<void> loadBalance({bool forceRefresh = false}) async {
    if (_isLoading) return;

    if (!forceRefresh) {
      final cached = await _loadFromCache();
      if (cached != null) {
        _balance = cached;
        _isLoaded = true;
        AppLogger.info(_logTag, 'loaded from cache = $_balance');
        notifyListeners();
        return;
      }
    }

    _isLoading = true;
    notifyListeners();

    bool loaded = false;

    try {
      for (int attempt = 0; attempt < 3; attempt++) {
        final result = await ApiService.get(
          '/api/bonus/balance',
          forceRefresh: true,
        );

        if (result.isSuccess) {
          final data = result.valueOrNull?['data'];
          if (data is Map) {
            _balance = data['points'] ?? 0;
            _isLoaded = true;
            loaded = true;
            await _saveToCache(_balance);
            AppLogger.info(_logTag, 'balance loaded from API = $_balance');
            break;
          }
        } else {
          AppLogger.warning(
            _logTag,
            'loadBalance attempt ${attempt + 1} failed: '
                '${result.errorOrNull?.message}',
          );
        }

        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      AppLogger.error(_logTag, 'loadBalance unexpected error', e);
    }

    // Fallback на кэш
    if (!loaded) {
      final cached = await _loadFromCache();
      if (cached != null) {
        _balance = cached;
        _isLoaded = true;
        AppLogger.info(_logTag, 'fallback to cache = $_balance');
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Загрузка информации об истекающих бонусах.
  Future<void> loadExpiringBatches({bool forceRefresh = false}) async {
    if (_isExpiringLoading) return;

    _isExpiringLoading = true;
    notifyListeners();

    final result = await ApiService.get(
      '/api/bonus/expiring',
      forceRefresh: forceRefresh,
    );

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadExpiringBatches failed: ${result.errorOrNull?.message}',
      );
    } else {
      final data = result.valueOrNull?['data'];
      if (data is Map) {
        _expiringBatches = (data['batches'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _totalExpiringSoon = data['total_expiring_soon'] ?? 0;

        AppLogger.info(
          _logTag,
          'expiring batches loaded = ${_expiringBatches.length}, '
              'soon = $_totalExpiringSoon',
        );
      }
    }

    _isExpiringLoading = false;
    notifyListeners();
  }

  /// Ручная установка баланса (при начислении/списании).
  void setBalance(int balance) {
    _balance = balance;
    _isLoaded = true;
    AppLogger.info(_logTag, 'balance set manually = $_balance');
    _saveToCache(_balance);
    notifyListeners();
  }

  /// Увеличение баланса (начисление).
  void addBonus(int amount) {
    _balance += amount;
    AppLogger.info(_logTag, 'added $amount, new balance = $_balance');
    _saveToCache(_balance);
    notifyListeners();
  }

  /// Уменьшение баланса (списание).
  void spendBonus(int amount) {
    _balance -= amount;
    if (_balance < 0) _balance = 0;
    AppLogger.info(_logTag, 'spent $amount, new balance = $_balance');
    _saveToCache(_balance);
    notifyListeners();
  }

  /// Очистка кеша.
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimeKey);
    } catch (e) {
      AppLogger.warning(_logTag, 'clearCache prefs failed', e);
    }

    _balance = 0;
    _isLoaded = false;
    _expiringBatches = [];
    _totalExpiringSoon = 0;
    AppLogger.info(_logTag, 'cache cleared');
    notifyListeners();
  }

  // ========== Приватные методы кеширования ==========

  Future<void> _saveToCache(int balance) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_cacheKey, balance);
      await prefs.setInt(
        _cacheTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      AppLogger.warning(_logTag, 'saveToCache failed', e);
    }
  }

  Future<int?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedTime = prefs.getInt(_cacheTimeKey);

      if (cachedTime == null) return null;

      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - cachedTime > _cacheTtlSeconds * 1000) {
        return null;
      }

      return prefs.getInt(_cacheKey);
    } catch (e) {
      AppLogger.warning(_logTag, 'loadFromCache failed', e);
      return null;
    }
  }
}