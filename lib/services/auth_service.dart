// lib/services/auth_service.dart
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Биометрия с fallback на код-пароль (стандартное поведение iOS)
  static Future<bool> authenticateWithBiometrics(String reason) async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (!canCheck) return false;
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> hasBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      return canCheck;
    } catch (e) {
      return false;
    }
  }

  static Future<List<BiometricType>> getBiometricTypes() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  // Сохранение состояния входа
  static Future<void> saveLogin({required int userId, String? name, String? phone, String? email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setInt('userId', userId);
    if (name != null) await prefs.setString('userName', name);
    if (phone != null) await prefs.setString('userPhone', phone);
    if (email != null) await prefs.setString('userEmail', email);
  }

  static Future<Map<String, dynamic>?> getSavedLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    if (!isLoggedIn) return null;
    return {
      'userId': prefs.getInt('userId') ?? 0,
      'userName': prefs.getString('userName') ?? '',
      'userPhone': prefs.getString('userPhone') ?? '',
      'userEmail': prefs.getString('userEmail') ?? '',
    };
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  static Future<void> saveRememberToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('remember_token', token);
  }

  static Future<String?> getRememberToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('remember_token');
  }

  static Future<void> clearLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('userId');
    await prefs.remove('userName');
    await prefs.remove('userPhone');
    await prefs.remove('userEmail');
    await prefs.remove('remember_token');
    await prefs.remove('saved_cookies');
  }
}