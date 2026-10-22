// lib/widgets/common/city_hint_animation.dart
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';

/// Подсказка при первом заходе на «Главную»: подсвечивает блок города
/// в хедере (spotlight) и показывает пузырь со стрелкой, указывающей
/// на этот блок.
class CityHintAnimation {
  static const _prefsKey = 'city_hint_animation_seen';

  /// Показывает подсказку ОДИН раз (флаг в SharedPreferences).
  /// [cityRect] — глобальный Rect блока города.
  static Future<void> maybeShow(BuildContext context, {required Rect cityRect}) async {
    if (!context.mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_prefsKey) == true;
    if (seen) return;

    if (!context.mounted) return;

    try {
      await showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (ctx, _, _) => _CityHintOverlay(cityRect: cityRect),
      );
      // Флаг ставим после успешного показа
      await prefs.setBool(_prefsKey, true);
    } catch (_) {
      // При ошибке — флаг не ставим
    }
  }

  /// Сброс флага — для теста.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}

class _CityHintOverlay extends StatefulWidget {
  const _CityHintOverlay({required this.cityRect});
  final Rect cityRect;

  @override
  State<_CityHintOverlay> createState() => _CityHintOverlayState();
}

class _CityHintOverlayState extends State<_CityHintOverlay>
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

  @override
  Widget build(BuildContext context) {
    final r = widget.cityRect;

    // Пузырь размещаем ПОД блоком города (по центру), с отступом
    final screenWidth = MediaQuery.of(context).size.width;
    // Компактный, но читаемый пузырь (максимум 340)
    final bubbleWidth = (screenWidth - 48).clamp(240.0, 340.0);
    final bubbleLeft = (r.center.dx - bubbleWidth / 2)
        .clamp(16.0, screenWidth - bubbleWidth - 16);
    final bubbleTop = r.bottom + 16;

    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _fadeIn,
        builder: (context, _) {
          final opacity = _fadeIn.value;
          return Stack(
            children: [
              // Spotlight (затемнение везде кроме блока города)
              // Тап по затемнению — закрыть подсказку.
              // Rect расширяем на 10px — подсветка заметнее.
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: 0.75 * opacity),
                      BlendMode.srcOver,
                    ),
                    child: Stack(
                      children: [
                        const Positioned.fill(
                          child: ColoredBox(color: Colors.black),
                        ),
                        // "Дырка" — белый прямоугольник с BlendMode.clear
                        Positioned.fromRect(
                          rect: r.inflate(10),
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.clear,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Пузырь с текстом и стрелкой
              Positioned(
                left: bubbleLeft,
                top: bubbleTop,
                width: bubbleWidth,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_rounded,
                                color: context.colors.brand,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Выберите город',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: context.colors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Установите тут город, куда будет доставка заказов',
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
              // Стрелка от пузыря к блоку города
              Positioned(
                left: r.center.dx - 8,
                top: bubbleTop - 10,
                child: Opacity(
                  opacity: opacity,
                  child: CustomPaint(
                    size: const Size(16, 10),
                    painter: _CityArrowPainter(color: context.colors.surface),
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

class _CityArrowPainter extends CustomPainter {
  _CityArrowPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(size.width / 2, 0) // вершина (указывает на блок города)
      ..lineTo(0, size.height) // левый низ
      ..lineTo(size.width, size.height) // правый низ
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CityArrowPainter old) => old.color != color;
}
