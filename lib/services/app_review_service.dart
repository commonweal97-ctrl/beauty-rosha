// lib/services/app_review_service.dart

import 'dart:io';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

/// Сервис для запроса оценки приложения
///
/// iOS — системный диалог (SKStoreReviewController)
/// Google Play — системный диалог (In-App Review)
/// RuStore — fallback: открывает страницу в RuStore
class AppReviewService {
  static const String _keyLastShown = 'app_review_last_shown';
  static const String _keyReviewShown = 'app_review_shown';
  static const String _keyOrderCount = 'app_review_order_count';

  /// Проверяет, нужно ли показывать запрос оценки
  ///
  /// Условия:
  /// - iOS: после каждого заказа (но не чаще 1 раза в 30 дней)
  /// - Android (Google Play): после каждого заказа (но не чаще 1 раза в 30 дней)
  /// - RuStore: после каждого заказа (открывает страницу)
  static Future<bool> shouldShowAfterOrder() async {
    final prefs = await SharedPreferences.getInstance();

    // Проверяем, показывали ли уже оценку (если да — больше не показываем)
    final reviewShown = prefs.getBool(_keyReviewShown) ?? false;
    if (reviewShown) return false;

    // Проверяем, когда показывали в последний раз
    final lastShown = prefs.getString(_keyLastShown);
    if (lastShown != null) {
      final lastDate = DateTime.tryParse(lastShown);
      if (lastDate != null) {
        final daysSince = DateTime.now().difference(lastDate).inDays;
        if (daysSince < 30) return false;
      }
    }

    return true;
  }

  /// Показывает диалог оценки
  ///
  /// Возвращает true если пользователь увидел диалог
  static Future<bool> showReviewDialog() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // iOS и Google Play — системный диалог
      if (Platform.isIOS || !await _isRuStoreInstall()) {
        final InAppReview inAppReview = InAppReview.instance;

        if (await inAppReview.isAvailable()) {
          await inAppReview.requestReview();
          
          // Сохраняем время показа
          await prefs.setString(_keyLastShown, DateTime.now().toIso8601String());
          
          return true;
        }
        return false;
      }

      // RuStore — открываем страницу в RuStore
      final url = Uri.parse('https://www.rustore.ru/catalog/app/com.beautyrosha.beauty_rosha');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        
        await prefs.setString(_keyLastShown, DateTime.now().toIso8601String());
        
        return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  /// Отмечает, что пользователь уже оценил приложение
  static Future<void> markAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReviewShown, true);
  }

  /// Увеличивает счётчик заказов
  static Future<void> incrementOrderCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt(_keyOrderCount) ?? 0;
    await prefs.setInt(_keyOrderCount, count + 1);
  }

  /// Возвращает количество заказов
  static Future<int> getOrderCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyOrderCount) ?? 0;
  }

  /// Проверяет, установлено ли приложение из RuStore
  static Future<bool> _isRuStoreInstall() async {
    try {
      const channel = MethodChannel('beautyrosha/installer');
      final installer = await channel.invokeMethod<String>('getInstallerPackage');
      if (installer == null || installer.isEmpty) return false;
      return installer.toLowerCase().contains('rustore') ||
          installer.toLowerCase().contains('ru.store');
    } catch (_) {
      return false;
    }
  }
}