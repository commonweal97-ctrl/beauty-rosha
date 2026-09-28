// lib/services/analytics_service.dart
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  /// Ленивый доступ к FirebaseAnalytics.
  /// Возвращает null если Firebase ещё не инициализирован — предотвращает краш.
  static FirebaseAnalytics? get _analytics {
    try {
      return FirebaseAnalytics.instance;
    } catch (_) {
      // Firebase ещё не готов — просто скипаем аналитику
      return null;
    }
  }

  // Экраны
  static Future<void> logScreen(String screenName) async {
    await _analytics?.logScreenView(screenName: screenName);
  }

    static Future<void> logSearch(String query, int resultsCount) async {
    await _analytics?.logEvent(
      name: 'search',
      parameters: {
        'search_term': query,
        'results_count': resultsCount,
      },
    );
  }

  // Просмотр товара
  static Future<void> logProductView(int productId, String productName, double price) async {
    await _analytics?.logViewItem(
      currency: 'RUB',
      value: price,
      items: [
        AnalyticsEventItem(
          itemId: productId.toString(),
          itemName: productName,
          price: price,
        ),
      ],
    );
  }

  // Добавление в корзину
  static Future<void> logAddToCart(int productId, String productName, double price, int quantity) async {
    await _analytics?.logAddToCart(
      currency: 'RUB',
      value: price * quantity,
      items: [
        AnalyticsEventItem(
          itemId: productId.toString(),
          itemName: productName,
          price: price,
          quantity: quantity,
        ),
      ],
    );
  }

  // Начало оформления заказа
  static Future<void> logCheckout(double total, int itemsCount) async {
    await _analytics?.logBeginCheckout(
      currency: 'RUB',
      value: total,
    );
  }

  // Покупка
  static Future<void> logPurchase(String orderId, double total) async {
    await _analytics?.logPurchase(
      currency: 'RUB',
      value: total,
      transactionId: orderId,
    );
  }

  // Добавление в избранное
  static Future<void> logAddToWishlist(int productId, String productName) async {
    await _analytics?.logEvent(
      name: 'add_to_wishlist',
      parameters: {
        'product_id': productId,
        'product_name': productName,
      },
    );
  }

  // Регистрация
  static Future<void> logRegistration(String method) async {
    await _analytics?.logSignUp(signUpMethod: method);
  }

  // Вход
  static Future<void> logLogin(String method) async {
    await _analytics?.logLogin(loginMethod: method);
  }

  // Просмотр категории
  static Future<void> logCategoryView(String categoryName) async {
    await _analytics?.logEvent(
      name: 'view_category',
      parameters: {'category_name': categoryName},
    );
  }
}