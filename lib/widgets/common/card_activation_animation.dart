// lib/widgets/common/card_activation_animation.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';

/// Премиум-анимация активации Б-карты — БЕЗ overlay, БЕЗ чёрного экрана.
/// Только: затемнение страницы профиля (spotlight), QR виден сквозь «окно»,
/// замок трясётся и открывается.
class CardActivationAnimation {
  static const _prefsKey = 'card_activation_animation_seen_for';

  /// Проверяет флаг и, если ещё не показывали, показывает анимацию.
  /// [cardRect] — глобальный Rect плитки карты (spotlight-окно).
  static Future<void> maybeShow(
    BuildContext context, {
    required String cardNumber,
    required Rect cardRect,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final seenFor = prefs.getString(_prefsKey);

    // Показываем, если для ЭТОЙ карты ещё не показывали (или карта сменилась)
    if (seenFor != null && seenFor == cardNumber && cardNumber.isNotEmpty) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (ctx, _, _) {
          return _CardActivationOverlay(
            cardNumber: cardNumber,
            cardRect: cardRect,
          );
        },
      );
      // Флаг: запоминаем ДЛЯ ЭТОЙ карты (номер)
      await prefs.setString(_prefsKey, cardNumber);
    } catch (_) {
      // При ошибке показа — флаг не ставим, попробуем при следующем входе
    }
  }

  /// Сброс флага — вызывать при деактивации карты (или принудительно).
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// Принудительный сброс — для теста / отладки.
  static Future<void> debugReset() async {
    await reset();
  }
}

class _CardActivationOverlay extends StatefulWidget {
  const _CardActivationOverlay({
    required this.cardNumber,
    required this.cardRect,
  });

  final String cardNumber;
  final Rect cardRect;

  @override
  State<_CardActivationOverlay> createState() => _CardActivationOverlayState();
}

class _CardActivationOverlayState extends State<_CardActivationOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fadeIn;
  late final AnimationController _shake;
  late final AnimationController _open;
  late final AnimationController _fadeOut;

  bool _lockOpened = false;

  @override
  void initState() {
    super.initState();

    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _open = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeOut = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    await _fadeIn.forward(); // затемнение страницы
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    await _shake.forward(); // дрожание замка
    if (!mounted) return;

    setState(() => _lockOpened = true);
    await _open.forward(); // открытие замка
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    await _fadeOut.forward(); // всё обратно
    if (!mounted) return;

    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _fadeIn.dispose();
    _shake.dispose();
    _open.dispose();
    _fadeOut.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.cardRect;

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([_fadeIn, _shake, _open, _fadeOut]),
        builder: (context, _) {
          final overlayOpacity = _fadeIn.value * (1.0 - _fadeOut.value);

          final shakeAngle = _lockOpened
              ? 0.0
              : math.sin(_shake.value * math.pi * 10) * 0.15 * (1 - _shake.value);


          return Stack(
            children: [
              // Spotlight: затемнение везде, кроме окна карты
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      rect: r,
                      color: Colors.black.withValues(alpha: 0.82 * overlayOpacity),
                      radius: 18,
                    ),
                  ),
                ),
              ),
              // Замок на QR — трясётся, открывается, исчезает
              Positioned(
                left: r.center.dx - 30,
                top: r.center.dy - 30,
                child: Opacity(
                  opacity: (1.0 - _fadeOut.value),
                  child: Transform.rotate(
                    angle: shakeAngle,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: context.colors.brand.withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: Icon(
                          _lockOpened
                              ? Icons.lock_open_rounded
                              : Icons.lock_outline_rounded,
                          key: ValueKey(_lockOpened),
                          size: 30,
                          color: _lockOpened
                              ? context.colors.brand
                              : context.colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Затемняет всё, кроме прямоугольника [rect] (со скруглением).
class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.rect,
    required this.color,
    this.radius = 18,
  });

  final Rect rect;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.zero,
      ));

    final inner = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

    final path = Path.combine(PathOperation.difference, outer, inner);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) =>
      old.rect != rect || old.color != color || old.radius != radius;
}
