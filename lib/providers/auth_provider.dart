// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_logger.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/crashlytics_service.dart';
import '../services/push_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _logTag = 'AuthProvider';

  User _user = User(id: 0);
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  User get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user.id > 0;
  String? get error => _error;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // ========================================================================
  // ПРОВЕРКА АВТОРИЗАЦИИ ПРИ ЗАПУСКЕ
  // ========================================================================

  Future<void> checkAuth() async {
    _isLoading = true;
    _safeNotify();

    try {
      await ApiService.loadCookies();

      final prefs = await SharedPreferences.getInstance();

      final savedUserId = prefs.getInt('userId') ?? 0;
      final savedName = prefs.getString('userName') ?? '';
      final savedEmail = prefs.getString('userEmail') ?? '';

      // ВАЖНО: запрос всегда — cookie могут прийти из web-auth (без prefs.remember_token)
      try {
        final result = await ApiService.get(
          '/api/auth/check',
          forceRefresh: true,
        );

        if (result.isSuccess) {
          final data = result.valueOrNull?['data'];
          if (data is Map && data['is_logged_in'] == true) {
            _user = User(
              id: data['user_id'] ?? savedUserId,
              name: data['user_name'] ?? savedName,
              email: data['user_email'] ?? savedEmail,
            );

            await prefs.setInt('userId', _user.id);
            await prefs.setBool('isLoggedIn', true);
            if (_user.name != null) {
              await prefs.setString('userName', _user.name!);
            }
            if (_user.email != null) {
              await prefs.setString('userEmail', _user.email!);
            }

            await CrashlyticsService.setUserIdentifier(_user.id.toString());
            await CrashlyticsService.log(
              'User authenticated: ${_user.id}',
            );

            PushService().syncToken();

            _isLoading = false;
            _safeNotify();
            return;
          }
        } else {
          AppLogger.warning(
            _logTag,
            'checkAuth API failed: ${result.errorOrNull?.message}',
          );
        }
      } catch (e, stackTrace) {
        AppLogger.error(_logTag, 'checkAuth failed', e, stackTrace);
        await CrashlyticsService.recordError(
          e,
          stackTrace,
          reason: 'Auth check failed',
        );

        if (savedUserId > 0) {
          _user = User(
            id: savedUserId,
            name: savedName,
            email: savedEmail,
          );

          await CrashlyticsService.setUserIdentifier(
            savedUserId.toString(),
          );

          PushService().syncToken();
          _isLoading = false;
          _safeNotify();
          return;
        }
      }

      // Ничего не нашли — пользователь не авторизован
      _user = User(id: 0);
      _isLoading = false;
      _safeNotify();
    } catch (e) {
      AppLogger.error(_logTag, 'checkAuth outer error', e, StackTrace.current);
      _isLoading = false;
      _safeNotify();
    }
  }

  void setLoggedIn(
    bool isLoggedIn, {
    int? userId,
    String? name,
    String? email,
    String? phone,
    String? token,
  }) {
    if (isLoggedIn) {
      _user = User(
        id: userId ?? _user.id,
        name: name ?? _user.name,
        email: email ?? _user.email,
        phone: phone ?? _user.phone,
      );
    } else {
      _user = User(id: 0);
    }
    _safeNotify();
  }

  Future<void> logout() async {
    await CrashlyticsService.log('User logged out: ${_user.id}');

    _user = User(id: 0);
    _safeNotify();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_qr_card');
    await prefs.remove('remember_token');
    await prefs.remove('userId');
    await prefs.remove('userName');
    await prefs.remove('userEmail');
    await prefs.remove('userPhone');
    await prefs.setBool('isLoggedIn', false);

    // Fire-and-forget: НЕ await (сервер может быть недоступен, не блокируем UI)
    unawaited(
      ApiService.post('/api/auth/logout', {}).then((r) {
        if (r.isFailure) {
          AppLogger.warning(
            _logTag,
            'logout API failed: ${r.errorOrNull?.message}',
          );
        }
      }).catchError((_) {}),
    );

    await ApiService.clearSession();

    await CrashlyticsService.setUserIdentifier('');
  }

  // ========================================================================
  // ОШИБКИ
  // ========================================================================

  void clearError() {
    if (_error != null) {
      _error = null;
      _safeNotify();
    }
  }
}