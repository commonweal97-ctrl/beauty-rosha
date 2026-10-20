import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';
import '../cat_widget.dart';

class CatBCardHint {
  static const _prefsKey = 'cat_bcard_hint_seen';
  static bool _isShowing = false;

  static Future<void> maybeShow(BuildContext context) async {
    if (!context.mounted) return;
    if (_isShowing) return;

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_prefsKey) == true;
    if (seen) return;

    // Проверяем, что context ещё жив после await
    if (!context.mounted) return;

    _isShowing = true;
    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (ctx, _, _) => const _CatBCardHintOverlay(),
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

class _CatBCardHintOverlay extends StatefulWidget {
  const _CatBCardHintOverlay();

  @override
  State<_CatBCardHintOverlay> createState() => _CatBCardHintOverlayState();
}

class _CatBCardHintOverlayState extends State<_CatBCardHintOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeIn;

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

  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // Затемнение (без spotlight, просто фон)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _close,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.6 * opacity),
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
                    onTap: _close,
                    child: CatWidget(size: catSize, onTap: _close),
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
                            'Ух ты! Теперь у вас есть Б-карта.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Все цены в нашем магазине для вас теперь по уникальной цене.',
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
