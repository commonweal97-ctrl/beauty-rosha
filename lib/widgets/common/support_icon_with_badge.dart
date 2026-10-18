// lib/widgets/common/support_icon_with_badge.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/support_badge_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/main_shell.dart';
import '../../screens/profile/support_screen.dart';

/// Единая иконка поддержки с бейджем непрочитанных.
///
/// Используется во всех местах, где раньше был "голый" `Icon(Icons.support_agent)`.
/// Бейдж показывает количество непрочитанных сообщений поддержки
/// (см. [SupportBadgeProvider]).
class SupportIconWithBadge extends StatelessWidget {
  const SupportIconWithBadge({
    super.key,
    this.size = 22,
    this.color,
    this.backgroundColor,
    this.borderRadius = 12,
    this.padding = 10,
    this.onTap,
  });

  /// Размер самой иконки.
  final double size;

  /// Цвет иконки. Если null — берётся `context.colors.textSecondary`.
  final Color? color;

  /// Фон контейнера (квадрат со скруглением). Если null — прозрачный.
  final Color? backgroundColor;

  /// Радиус скругления контейнера.
  final double borderRadius;

  /// Внутренний отступ контейнера.
  final double padding;

  /// Кастомный обработчик нажатия. Если null — открывает [SupportScreen]
  /// (с проверкой авторизации).
  final VoidCallback? onTap;

  void _defaultOnTap(BuildContext context) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      MainShell.push(context, const LoginScreen());
      return;
    }
    MainShell.push(context, const SupportScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SupportBadgeProvider>(
      builder: (context, badge, child) {
        final unread = badge.unreadCount;
        return GestureDetector(
          onTap: onTap ?? () => _defaultOnTap(context),
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: backgroundColor ?? Colors.transparent,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.support_agent,
                  size: size,
                  color: color ?? context.colors.textSecondary,
                ),
                if (unread > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF3B30),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: context.colors.surface,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          unread > 99 ? '99' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
