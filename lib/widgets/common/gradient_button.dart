// lib/widgets/common/gradient_button.dart
//
// Универсальная CTA-кнопка с градиентом brand → brandDark.
// Используется ВЕЗДЕ для основных действий:
// - "Оформить заказ" / "Оплатить"
// - "К оформлению"
// - "Подтвердить код" / "Отправить"
// - "Отследить" / прочие CTA
//
// Всегда одинаковый вид:
// - Height 56 (или 52 через параметр)
// - BorderRadius 14
// - Градиент topLeft → bottomRight (brand → brandDark)
// - Shadow brand @0.35 blur 14 offset (0, 6)
// - Текст: 16-17pt, w700, white
// - Loading: CircularProgressIndicator white
// - Disabled: серый фон, без градиента

import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool enabled;
  final double height;
  final double borderRadius;
  final IconData? icon;
  final double? fontSize;
  final EdgeInsets padding;
  final Color? customShadowColor;
  final LinearGradient? customGradient;
  final Widget? trailing;   // ← текст/виджет справа (цена)

  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.height = 56,
    this.borderRadius = 14,
    this.icon,
    this.fontSize,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.customShadowColor,
    this.customGradient,
    this.trailing,
  });

  bool get _isActive => enabled && !isLoading && onPressed != null;

  @override
  Widget build(BuildContext context) {
    final gradient = customGradient ??
        LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.brand, context.colors.brandDark],
        );
    final shadowColor = customShadowColor ?? context.colors.brand;

    return SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: _isActive ? gradient : null,
          color: _isActive ? null : context.colors.border,
          boxShadow: _isActive
              ? [
                  BoxShadow(
                    color: shadowColor.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
          child: InkWell(
            onTap: _isActive ? onPressed : null,
            borderRadius: BorderRadius.circular(borderRadius),
            splashColor: Colors.white.withValues(alpha: 0.2),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: Padding(
              padding: padding,
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : trailing != null
                        ? Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (icon != null) ...[
                                        Icon(icon, size: 20, color: Colors.white),
                                        const SizedBox(width: 8),
                                      ],
                                      Text(
                                        text,
                                        style: TextStyle(
                                          fontSize: fontSize ?? 16,
                                          fontWeight: FontWeight.w700,
                                          color: _isActive
                                              ? Colors.white
                                              : context.colors.textMuted,
                                        ),
                                        maxLines: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: trailing,
                                ),
                              ),
                            ],
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (icon != null) ...[
                                  Icon(icon, size: 20, color: Colors.white),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  text,
                                  style: TextStyle(
                                    fontSize: fontSize ?? 17,
                                    fontWeight: FontWeight.w700,
                                    color: _isActive
                                        ? Colors.white
                                        : context.colors.textMuted,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
