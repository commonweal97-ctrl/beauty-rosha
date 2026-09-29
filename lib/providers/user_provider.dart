// lib/providers/user_provider.dart
import 'package:flutter/foundation.dart';

import '../core/app_logger.dart';
import '../services/api_service.dart';

class UserProvider extends ChangeNotifier {
  static const _logTag = 'UserProvider';

  String _phone = '';
  String _email = '';
  String _name = '';
  bool _isLoading = true;
  String? _error;

  String get phone => _phone;
  String get email => _email;
  String get name => _name;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Загружает данные пользователя с сервера.
  Future<void> loadUserData({bool forceRefresh = false}) async {
    // Не сбрасываем в isLoading если уже есть данные — иначе мерцание
    final hasData = _phone.isNotEmpty || _email.isNotEmpty || _name.isNotEmpty;
    if (!hasData || forceRefresh) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    final result = await ApiService.get('/api/user/info');

    if (result.isFailure) {
      _error = result.errorOrNull?.userMessage ?? 'Ошибка загрузки';
      AppLogger.warning(
        _logTag,
        'loadUserData failed: ${result.errorOrNull?.message}',
      );
    } else {
      final data = result.valueOrNull?['data'];
      if (data is Map) {
        // Обновляем только если сервер вернул непустое
        final newPhone = (data['phone'] ?? '').toString();
        final newEmail = (data['email'] ?? '').toString();
        final newName = (data['name'] ?? '').toString();

        if (newPhone.isNotEmpty) _phone = newPhone;
        if (newEmail.isNotEmpty) _email = newEmail;
        if (newName.isNotEmpty) _name = newName;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Обновляет email локально (после успешной смены).
  void updateEmail(String newEmail) {
    _email = newEmail;
    notifyListeners();
  }

  /// Обновляет телефон локально.
  void updatePhone(String newPhone) {
    _phone = newPhone;
    notifyListeners();
  }
}