import 'package:flutter/material.dart';

/// Единая типографика приложения.
/// Использование: AppTypography.h1, AppTypography.buttonLarge
class AppTypography {
  // ============================================================
  // ЗАГОЛОВКИ ЭКРАНОВ
  // ============================================================
  
  /// Очень крупный — hero-заголовки на главной
  static const h0 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.8,
  );

  /// Заголовок экрана — например, "Корзина", "Профиль"
  static const h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.5,
  );

  /// Крупный подзаголовок — "Могут вас заинтересовать"
  static const h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.3,
  );

  /// Секция — "Описание", "Характеристики"
  static const h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  /// Маленький заголовок — "Показать все"
  static const h4 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.35,
  );

  // ============================================================
  // КНОПКИ
  // ============================================================

  /// Большая CTA-кнопка — "Оформить заказ", "В корзину"
  static const buttonLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.1,
  );

  /// Средняя кнопка — "Добавить", "Продолжить"
  static const buttonMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.1,
  );

  /// Маленькая кнопка — "ОК", "Отмена"
  static const buttonSmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  // ============================================================
  // ОСНОВНОЙ ТЕКСТ
  // ============================================================

  /// Крупный body — описания товара
  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.55,
  );

  /// Основной body — большинство текста
  static const bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Мелкий body — сноски
  static const bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  // ============================================================
  // ТОВАРЫ
  // ============================================================

  /// Название товара в карточке
  static const productTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Название товара на детальном экране (крупнее)
  static const productTitleLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.3,
  );

  /// Бренд товара — мелкий, серый
  static const productBrand = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Цена — крупная, жирная
  static const productPrice = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.3,
  );

  /// Цена большая — на детальном экране
  static const productPriceLarge = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.5,
  );

  /// Старая цена — зачёркнутая, серая
  static const productPriceOld = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.2,
    decoration: TextDecoration.lineThrough,
  );

  // ============================================================
  // СЛУЖЕБНЫЕ
  // ============================================================

  /// Подпись под полем — маленькая, серая
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Метка на бейдже — очень мелкая
  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.3,
  );

  /// Текст в поле ввода
  static const input = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  /// Текст ссылки
  static const link = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    decoration: TextDecoration.underline,
  );
}
