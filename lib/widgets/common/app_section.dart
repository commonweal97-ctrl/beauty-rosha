import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_typography.dart';

/// Секция с заголовком и содержимым.
///
/// Использование:
///   AppSection(
///     title: 'Уведомления',
///     child: AppCard(child: Text('...')),
///   )
class AppSection extends StatelessWidget {
  /// Заголовок секции. Если null — заголовок не показывается
  final String? title;

  /// Подзаголовок (мелкий серый текст под заголовком)
  final String? subtitle;

  /// Содержимое
  final Widget child;

  /// Виджет справа от заголовка (кнопка "Показать все" и т.п.)
  final Widget? trailing;

  /// Внешний отступ
  final EdgeInsets margin;

  /// Расстояние между заголовком и содержимым
  final double spacing;

  const AppSection({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.margin = const EdgeInsets.only(bottom: AppSpacing.md),
    this.spacing = AppSpacing.sm,
  });

  /// Секция без заголовка (просто отступ)
  const AppSection.plain({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.only(bottom: AppSpacing.md),
  })  : title = null,
        subtitle = null,
        trailing = null,
        spacing = 0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (title == null) {
      return Padding(
        padding: margin,
        child: child,
      );
    }

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: AppTypography.h4.copyWith(color: colors.textPrimary),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppTypography.caption.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
          SizedBox(height: spacing),
          // Содержимое
          child,
        ],
      ),
    );
  }
}
