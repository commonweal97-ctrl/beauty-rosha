import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/app_spacing.dart';
import '../../core/app_typography.dart';

/// Строка списка для настроек и меню.
/// Единый вид: иконка + заголовок + подзаголовок + trailing.
///
/// Использование:
///   AppListTile(
///     title: 'Уведомления',
///     subtitle: 'Выберите, какие хотите получать',
///     leading: Icon(Icons.notifications),
///     onTap: () {},
///   )
class AppListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Показать стрелку chevron_right справа (если trailing не задан)
  final bool showChevron;

  /// Разделитель снизу
  final bool showDivider;

  const AppListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 14,
            ),
            child: Row(
              children: [
                // Leading (иконка)
                if (leading != null) ...[
                  IconTheme(
                    data: IconThemeData(
                      color: colors.textPrimary,
                      size: 22,
                    ),
                    child: leading!,
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.bodyMedium.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppTypography.caption.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Trailing
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  trailing!,
                ] else if (showChevron) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: colors.textDisabled,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: leading != null ? AppSpacing.lg + 22 + AppSpacing.md : AppSpacing.lg,
            color: colors.border,
          ),
      ],
    );
  }
}
