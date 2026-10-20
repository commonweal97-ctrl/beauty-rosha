import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';
import '../cat_widget.dart';

class CatCityHint {
  static const _prefsKey = 'cat_city_hint_seen';
  static bool _isShowing = false;

  static Future<void> maybeShow(BuildContext context, {required Rect cityRect}) async {
    if (!context.mounted) return;
    if (_isShowing) return;

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_prefsKey) == true;
    if (seen) return;
    if (!context.mounted) return;

    _isShowing = true;
    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (ctx, _, _) => _CatCityHintOverlay(cityRect: cityRect),
      );
      await prefs.setBool(_prefsKey, true);
    } catch (_) {
    } finally {
      _isShowing = false;
    }
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

class _CatCityHintOverlay extends StatefulWidget {
  const _CatCityHintOverlay({required this.cityRect});
  final Rect cityRect;

  @override
  State<_CatCityHintOverlay> createState() => _CatCityHintOverlayState();
}

class _CatCityHintOverlayState extends State<_CatCityHintOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeIn;
  int _step = 1;

  @override
  void initState() {
    super.initState();
    _fadeIn = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void dispose() {
    _fadeIn.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_step == 1) {
      setState(() => _step = 2);
    } else {
      _close();
    }
  }

  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.cityRect;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    const catSize = 220.0;
    final catLeft = screenWidth - catSize + 20;
    final catTop = screenHeight - catSize - 30;

    final bubbleWidth = (screenWidth * 0.55).clamp(200.0, 280.0);
    const bubbleLeft = 16.0;
    final bubbleTop = catTop - 20;

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _fadeIn,
        builder: (context, _) {
          final opacity = _fadeIn.value;
          return Stack(
            children: [
              // Затемнение с дыркой (spotlight) — как было
              Positioned.fill(
                child: GestureDetector(
                  onTap: _nextStep,
                  behavior: HitTestBehavior.opaque,
                  child: CustomPaint(
                    painter: _CitySpotlightPainter(
                      rect: _step == 2 ? r.inflate(10) : Rect.zero,
                      color: Colors.black.withValues(alpha: 0.6 * opacity),
                      radius: _step == 2 ? 16 : 0,
                    ),
                  ),
                ),
              ),

              // Котик
              Positioned(
                left: catLeft,
                top: catTop,
                width: catSize,
                height: catSize,
                child: Opacity(
                  opacity: opacity,
                  child: GestureDetector(
                    onTap: _nextStep,
                    child: CatWidget(size: catSize, onTap: _nextStep),
                  ),
                ),
              ),

              // Облачко с текстом
              Positioned(
                left: bubbleLeft,
                top: bubbleTop,
                width: bubbleWidth,
                child: Opacity(
                  opacity: opacity,
                  child: CustomPaint(
                    painter: _BubbleWithTailPainter(
                      color: context.colors.surface,
                      tailRight: 24,
                      tailSize: 20,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _step == 1
                                ? 'Привет! Меня зовут, кошечка Аля.'
                                : 'Выберите город доставки.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _step == 1
                                ? 'Я тут, чтобы помогать.'
                                : 'Расскажите, куда будем доставлять ваши заказчики',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
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

class _CitySpotlightPainter extends CustomPainter {
  _CitySpotlightPainter({
    required this.rect,
    required this.color,
    this.radius = 12,
  });
  final Rect rect;
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    debugPrint('CAT: spotlight rect=$rect, size=$size');
    if (rect == Rect.zero) {
      canvas.drawRect(
          Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = color);
      return;
    }
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
  bool shouldRepaint(covariant _CitySpotlightPainter old) =>
      old.rect != rect || old.color != color || old.radius != radius;
}

class _BubbleWithTailPainter extends CustomPainter {
  _BubbleWithTailPainter({
    required this.color,
    required this.tailRight,
    required this.tailSize,
  });
  final Color color;
  final double tailRight;
  final double tailSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const radius = 16.0;

    final bodyHeight = size.height - tailSize * 0.6;
    final bodyRect = Rect.fromLTWH(0, 0, size.width, bodyHeight);
    final bodyRRect = RRect.fromRectAndRadius(
      bodyRect,
      const Radius.circular(radius),
    );

    final path = Path()..addRRect(bodyRRect);

    final baseRight = size.width - tailRight;
    final baseLeft = baseRight - tailSize;
    final baseY = bodyRect.bottom - 2;
    final tipX = baseRight + 4;
    final tipY = size.height;

    final tailPath = Path()
      ..moveTo(baseLeft, baseY)
      ..lineTo(baseRight, baseY)
      ..lineTo(tipX, tipY)
      ..close();

    final combined = Path.combine(PathOperation.union, path, tailPath);

    canvas.save();
    canvas.translate(0, 4);
    canvas.drawPath(
      combined,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.restore();

    canvas.drawPath(combined, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleWithTailPainter old) =>
      old.color != color ||
      old.tailRight != tailRight ||
      old.tailSize != tailSize;
}
