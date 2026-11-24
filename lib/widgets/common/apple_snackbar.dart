import 'dart:async';
import 'package:flutter/material.dart';

/// Тип уведомления (Ozon/Apple-style).
/// Определяет accent / icon / badge автоматически.
enum SnackType { info, success, warn, error }

/// Apple-style верхний баннер: белая «пилюля», скруглённые углы,
/// усиленная тень, чёрный жирный текст. Выезжает СВЕРХУ.
///
/// Использование:
///   showAppleSnackBar(context, 'Оплата не завершена', type: SnackType.error);
///   showAppleSnackBar(context, 'Добавлено в корзину', type: SnackType.success);
///   // Override (опционально):
///   showAppleSnackBar(context, 'Своё', accent: Color(0xFFFF0000), icon: Icons.star);
void showAppleSnackBar(
  BuildContext context,
  String message, {
  SnackType type = SnackType.info,
  IconData? icon,
  Color? accent,
  bool? warn,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  // Resolve: type → accent/icon/warn (override через параметры)
  final resolved = _resolveType(type);
  final effectiveAccent = accent ?? resolved.accent;
  final effectiveIcon = icon ?? resolved.icon;
  final effectiveWarn = warn ?? resolved.warn;

  final entry = OverlayEntry(
    builder: (ctx) => _AppleTopBanner(
      message: message,
      icon: effectiveIcon,
      accent: effectiveAccent,
      warn: effectiveWarn,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    ),
  );
  overlay.insert(entry);

  // Удаляем запись после завершения анимации (тот же duration + запас)
  Timer(duration + const Duration(milliseconds: 600), () {
    if (entry.mounted) entry.remove();
  });
}

/// Resolve type → accent/icon/warn.
({Color accent, IconData? icon, bool warn}) _resolveType(SnackType type) {
  switch (type) {
    case SnackType.error:
      return (accent: const Color(0xFFDD1847), icon: null, warn: true);
    case SnackType.warn:
      return (accent: const Color(0xFFFF9F0A), icon: null, warn: true);
    case SnackType.success:
      return (
        accent: const Color(0xFF34C759),
        icon: Icons.check_circle_outline,
        warn: false,
      );
    case SnackType.info:
      return (
        accent: const Color(0xFF0A84FF),
        icon: Icons.info_outline,
        warn: false,
      );
  }
}

class _AppleTopBanner extends StatefulWidget {
  const _AppleTopBanner({
    required this.message,
    required this.duration,
    this.icon,
    this.accent,
    this.warn = false,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final Duration duration;
  final IconData? icon;
  final Color? accent;
  final bool warn;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_AppleTopBanner> createState() => _AppleTopBannerState();
}

class _AppleTopBannerState extends State<_AppleTopBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    _ctrl.forward();

    Future.delayed(widget.duration, () async {
      if (!mounted) return;
      await _ctrl.reverse();
      if (mounted) {
        // OverlayEntry удалит родитель по таймеру
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 8;
    const textColor = Color(0xFF111111);

    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  // Усиленная мягкая тень
                  BoxShadow(
                    color: Color(0x1F000000), // 12%
                    blurRadius: 32,
                    offset: Offset(0, 14),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Color(0x14000000), // 8%
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Color(0x0A000000), // 4%
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.warn) ...[
                    _WarnBadge(color: widget.accent ?? const Color(0xFFDD1847)),
                    const SizedBox(width: 12),
                  ] else if (widget.icon != null) ...[
                    Icon(
                      widget.icon,
                      size: 24,
                      color: widget.accent ?? textColor,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: Text(
                      widget.message,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w700, // жирнее
                        letterSpacing: -0.3,
                        fontFamily: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.fontFamily,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                  if (widget.actionLabel != null &&
                      widget.onAction != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: widget.onAction,
                      child: Text(
                        widget.actionLabel!,
                        style: TextStyle(
                          color: widget.accent ?? const Color(0xFFDD1847),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WarnBadge extends StatelessWidget {
  const _WarnBadge({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.priority_high_rounded, size: 18, color: color),
    );
  }
}

Future<bool?> showAppleDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmText = 'OK',
  String? cancelText,
  bool destructive = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (ctx) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 40,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              if (message != null && message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF5B5B60),
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE5E5EA)),
              Row(
                children: [
                  if (cancelText != null)
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: const Color(0xFF0A84FF),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                            ),
                          ),
                        ),
                        child: Text(
                          cancelText,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  if (cancelText != null)
                    const SizedBox(
                      height: 44,
                      child: VerticalDivider(
                        width: 1,
                        color: Color(0xFFE5E5EA),
                      ),
                    ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: destructive
                            ? const Color(0xFFFF3B30)
                            : const Color(0xFF0A84FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(
                              cancelText == null ? 20 : 0,
                            ),
                            bottomRight: const Radius.circular(20),
                          ),
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: destructive
                              ? FontWeight.w400
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return res ?? false;
}
