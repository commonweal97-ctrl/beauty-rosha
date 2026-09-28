import 'package:flutter/material.dart';

/// Единые отступы и радиусы приложения.
/// 
/// Использование:
///   EdgeInsets.all(AppSpacing.md)
///   BorderRadius.circular(AppRadii.card)
class AppSpacing {
  AppSpacing._();

  /// 4 — минимальный
  static const double xs = 4;

  /// 8 — между мелкими элементами
  static const double sm = 8;

  /// 12 — между элементами
  static const double md = 12;

  /// 16 — стандартный отступ карточки
  static const double lg = 16;

  /// 20 — крупный отступ
  static const double xl = 20;

  /// 24 — между секциями
  static const double xxl = 24;

  /// 32 — крупный раздел
  static const double xxxl = 32;

  /// 48 — между крупными секциями
  static const double huge = 48;

  // ============================================================
  // Готовые EdgeInsets
  // ============================================================

  /// Карточка: 16 со всех сторон
  static const card = EdgeInsets.all(lg);

  /// Карточка компактная: 12
  static const cardCompact = EdgeInsets.all(md);

  /// Карточка крупная: 20
  static const cardLarge = EdgeInsets.all(xl);

  /// Кнопка: горизонталь 20, вертикаль 14
  static const button = EdgeInsets.symmetric(horizontal: xl, vertical: 14);

  /// Кнопка компактная: 16 / 10
  static const buttonCompact = EdgeInsets.symmetric(horizontal: lg, vertical: 10);

  /// Поле ввода: 16 / 14
  static const input = EdgeInsets.symmetric(horizontal: lg, vertical: 14);

  /// Экран: 16 слева/справа
  static const screen = EdgeInsets.symmetric(horizontal: lg);

  /// Экран с вертикалью: 16 / 24
  static const screenVertical = EdgeInsets.symmetric(horizontal: lg, vertical: xxl);
}

/// Единые радиусы скругления.
class AppRadii {
  AppRadii._();

  /// 8 — чипы, бейджи
  static const double chip = 8;

  /// 10 — мелкие кнопки
  static const double buttonSmall = 10;

  /// 12 — поля ввода, кнопки
  static const double button = 12;

  /// 14 — кнопки CTA, карточки мелкие
  static const double cardSmall = 14;

  /// 16 — стандартные карточки
  static const double card = 16;

  /// 20 — крупные карточки, изображения
  static const double cardLarge = 20;

  /// 24 — hero-блоки, попапы
  static const double modal = 24;

  /// 999 — круглая форма
  static const double circle = 999;
}
