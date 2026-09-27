// lib/services/review_service.dart
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewService {
  static const _lastRequestKey = 'last_review_request';
  static const _reviewCompletedKey = 'review_completed';
  static const _minDaysBetweenRequests = 60;

  final InAppReview _inAppReview = InAppReview.instance;

  /// Проверяет, доступен ли запрос оценки на этой платформе.
  Future<bool> get isAvailable async => await _inAppReview.isAvailable();

  /// Запрашивает оценку приложения, если:
  /// - Пользователь ещё не оценивал
  /// - Прошло 60 дней с последнего запроса
  Future<bool> requestReviewIfNeeded() async {
    final available = await isAvailable;
    if (!available) return false;

    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_reviewCompletedKey) ?? false;
    if (completed) return false;

    final lastRequest = prefs.getString(_lastRequestKey);
    if (lastRequest != null) {
      final lastDate = DateTime.tryParse(lastRequest);
      if (lastDate != null &&
          DateTime.now().difference(lastDate).inDays <
              _minDaysBetweenRequests) {
        return false;
      }
    }

    // Пробуем показать системный диалог оценки.
    try {
      await _inAppReview.requestReview();
      await prefs.setString(_lastRequestKey, DateTime.now().toIso8601String());
      await prefs.setBool(_reviewCompletedKey, true);
      return true;
    } catch (_) {
      // Не смогли показать — пробуем открыть страницу в магазине.
      try {
        await _inAppReview.openStoreListing(appStoreId: '6789254420');
        await prefs.setString(
          _lastRequestKey,
          DateTime.now().toIso8601String(),
        );
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Сбрасывает флаг оценки (для тестирования).
  Future<void> resetForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_reviewCompletedKey);
    await prefs.remove(_lastRequestKey);
  }
}