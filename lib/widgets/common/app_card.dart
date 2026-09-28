import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';

/// Единый блок/карточка приложения.
///
/// Использование:
///   AppCard(child: Text('Привет'))
///   AppCard(onTap: () {}, padding: AppSpacing.cardCompact, child: ...)
class AppCard extends StatelessWidget {
  final Widget child;

  /// Отступ внутри. По умолчанию AppSpacing.card (16)
  final EdgeInsets padding;

  /// Радиус. По умолчанию AppRadii.card (16)
  final double radius;

  /// Цвет фона. По умолчанию colors.surface
  final Color? color;

  /// Обработчик тапа. Если задан — карточка становится кликабельной
  final VoidCallback? onTap;

  /// Внешний отступ
  final EdgeInsets? margin;

  /// Тень. По умолчанию — без тени (плоский дизайн)
  final double elevation;

  /// Обводка (опционально)
  final Color? borderColor;
  final double borderWidth;

  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.card,
    this.radius = AppRadii.card,
    this.color,
    this.onTap,
    this.margin,
    this.elevation = 0,
    this.borderColor,
    this.borderWidth = 1,
  });

  /// Компактная карточка — padding 12, radius 12
  const AppCard.compact({
    super.key,
    required this.child,
    this.color,
    this.onTap,
    this.margin,
    this.elevation = 0,
    this.borderColor,
    this.borderWidth = 1,
  })  : padding = AppSpacing.cardCompact,
        radius = AppRadii.button;

  /// Крупная карточка — padding 20, radius 20
  const AppCard.large({
    super.key,
    required this.child,
    this.color,
    this.onTap,
    this.margin,
    this.elevation = 0,
    this.borderColor,
    this.borderWidth = 1,
  })  : padding = AppSpacing.cardLarge,
        radius = AppRadii.cardLarge;

  /// Карточка без отступов — только фон + радиус
  /// (для изображений, галерей, кастомного layout)
  const AppCard.flat({
    super.key,
    required this.child,
    this.color,
    this.onTap,
    this.margin,
    this.radius = AppRadii.card,
    this.elevation = 0,
    this.borderColor,
    this.borderWidth = 1,
  }) : padding = EdgeInsets.zero;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    Widget content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04 * elevation),
                  blurRadius: elevation * 4,
                  offset: Offset(0, elevation),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: content,
      );
    }

    return content;
  }
}
