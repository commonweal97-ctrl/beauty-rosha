// lib/providers/auth_provider.dart
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

      final savedToken = prefs.getString('remember_token');
      final savedUserId = prefs.getInt('userId') ?? 0;
      final savedName = prefs.getString('userName') ?? '';
      final savedEmail = prefs.getString('userEmail') ?? '';

      if (savedToken != null && savedToken.isNotEmpty && savedUserId > 0) {
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
      }

      _user = User(id: 0);
    } catch (e, stackTrace) {
      AppLogger.error(_logTag, 'checkAuth exception', e, stackTrace);
      await CrashlyticsService.recordError(
        e,
        stackTrace,
        reason: 'Auth check exception',
      );

      _user = User(id: 0);
    }

    _isLoading = false;
    _safeNotify();
  }

  // ========================================================================
  // УСТАНОВКА ПОЛЬЗОВАТЕЛЯ ПОСЛЕ ВХОДА
  // ========================================================================

  void setLoggedIn(
    bool value, {
    int? userId,
    String? name,
    String? phone,
    String? email,
    String? token,
  }) {
    if (value && userId != null && userId > 0) {
      _user = User(
        id: userId,
        name: name ?? '',
        phone: phone ?? '',
        email: email ?? '',
      );

      CrashlyticsService.setUserIdentifier(userId.toString());
      CrashlyticsService.log('User logged in: $userId');

      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('isLoggedIn', true);
        prefs.setInt('userId', userId);
        if (name != null && name.isNotEmpty) {
          prefs.setString('userName', name);
        }
        if (phone != null && phone.isNotEmpty) {
          prefs.setString('userPhone', phone);
        }
        if (email != null && email.isNotEmpty) {
          prefs.setString('userEmail', email);
        }

        if (token != null && token.isNotEmpty) {
          prefs.setString('remember_token', token);
        }
      });

      if (token != null && token.isNotEmpty) {
        ApiService.setCookie('remember_token=$token');
      }

      PushService().syncToken();
    } else {
      _user = User(id: 0);
      CrashlyticsService.setUserIdentifier('');
    }
    _safeNotify();
  }

  // ========================================================================
  // ВЫХОД
  // ========================================================================

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

    // Fire-and-forget: не блокируем logout, если сервер недоступен
    final logoutResult = await ApiService.post('/api/auth/logout', {});
    if (logoutResult.isFailure) {
      AppLogger.warning(
        _logTag,
        'logout API failed: ${logoutResult.errorOrNull?.message}',
      );
    }

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