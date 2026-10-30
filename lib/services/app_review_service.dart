// lib/services/app_review_service.dart

import 'dart:io';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

/// Сервис для запроса оценки приложения.
///
/// Стратегия:
/// - Сохраняем дату последнего заказа.
/// - Через 3–7 дней после заказа (при открытии приложения) — пре-попап.
/// - «Нравится» → InAppReview (App Store / Google Play)
/// - «Не нравится» → форма обратной связи
/// - Не чаще 1 раза в 90 дней.
class AppReviewService {
  static const String _keyLastShown = 'app_review_last_shown';
  static const String _keyReviewCompleted = 'app_review_completed';
  static const String _keyOrderPlacedAt = 'app_review_order_placed_at';
  static const String _keyOrderCount = 'app_review_order_count';
  static const String _keyFeedbackShown = 'app_review_feedback_shown';

  static const int _minDaysAfterOrder = 0;
  static const int _minDaysBetweenRequests = 90;
  static const String _ruStoreUrl = 'https://www.rustore.ru/catalog/app/com.beautyrosha.beauty_rosha';

  /// Записать дату заказа (при оформлении).
  static Future<void> recordOrderPlaced() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOrderPlacedAt, DateTime.now().toIso8601String());
    final count = prefs.getInt(_keyOrderCount) ?? 0;
    await prefs.setInt(_keyOrderCount, count + 1);
  }

  /// Проверить, пора ли запрашивать оценку (при открытии приложения).
  ///
  /// Условия:
  /// - Не оценивал ранее (completed = true → не показываем).
  /// - Прошло ≥ 3 дней с заказа.
  /// - Не показывали ≥ 90 дней.
  static Future<bool> shouldShowNow() async {
    final prefs = await SharedPreferences.getInstance();

    // Уже оценил — не показываем
    if (prefs.getBool(_keyReviewCompleted) ?? false) return false;

    // Дата заказа
    final placedAtStr = prefs.getString(_keyOrderPlacedAt);
    if (placedAtStr == null) return false;
    final placedAt = DateTime.tryParse(placedAtStr);
    if (placedAt == null) return false;

    // Прошло ≥ 3 дней
    if (DateTime.now().difference(placedAt).inDays < _minDaysAfterOrder) {
      return false;
    }

    // Не показывали ≥ 90 дней
    final lastShownStr = prefs.getString(_keyLastShown);
    if (lastShownStr != null) {
      final lastShown = DateTime.tryParse(lastShownStr);
      if (lastShown != null &&
          DateTime.now().difference(lastShown).inDays < _minDaysBetweenRequests) {
        return false;
      }
    }

    return true;
  }

  /// Отметить, что пользователь уже оценил (или отказался от пре-попапа).
  static Future<void> markAsCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReviewCompleted, true);
    await prefs.setString(_keyLastShown, DateTime.now().toIso8601String());
  }

  /// Отметить, что показали пре-попап «Не нравится» (форма обратной связи).
  static Future<void> markFeedbackShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFeedbackShown, true);
    await prefs.setString(_keyLastShown, DateTime.now().toIso8601String());
  }

  /// Показать системный диалог оценки (InAppReview).
  ///
  /// Возвращает true если удалось.
  static Future<bool> showSystemReview() async {
    try {
      if (Platform.isIOS) {
        final inAppReview = InAppReview.instance;
        if (await inAppReview.isAvailable()) {
          await inAppReview.requestReview();
          return true;
        }
        return false;
      }

      // Android — проверяем RuStore
      if (await _isRuStoreInstall()) {
        final url = Uri.parse(_ruStoreUrl);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return true;
        }
        return false;
      }

      // Google Play
      final inAppReview = InAppReview.instance;
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Открыть форму обратной связи (если «Не нравится»).
  static Future<void> openFeedback() async {
    // TODO: заменить на реальный URL формы / почты
    final url = Uri.parse('mailto:support@бьютироща.рф?subject=Отзыв%20о%20приложении');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

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
