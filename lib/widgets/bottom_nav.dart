// lib/widgets/bottom_nav.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class BottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final int cartCount;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.cartCount = 0,
  });

  @override
  State<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<BottomNav> with TickerProviderStateMixin {
  late AnimationController _pulseController;

  static const int _itemCount = 4;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap(int index) {
    if (index == widget.currentIndex) {
      _pulseController.forward().then((_) => _pulseController.reverse());
    }
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;

    return Container(
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 0,
        bottom: isAndroid ? (bottomPadding > 0 ? bottomPadding : 8) : 8,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: context.colors.border.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final itemWidth = totalWidth / _itemCount;

                final indicatorWidth = itemWidth - 8;
                final indicatorLeft =
                    (itemWidth * widget.currentIndex) + 4;

                return SizedBox(
                  height: 56,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        left: indicatorLeft,
                        top: 0,
                        bottom: 0,
                        width: indicatorWidth,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: context.colors.brand,
                            boxShadow: [
                              BoxShadow(
                                color: context.colors.brand
                                    .withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavItem(
                            index: 0,
                            label: 'Главная',
                            child: CustomPaint(
                              size: const Size(24, 24),
                              painter: _HomeIconPainter(
                                isActive: widget.currentIndex == 0, activeColor: Colors.white, inactiveColor: context.colors.textMuted),
                            ),
                          ),
                          _buildNavItem(
                            index: 1,
                            label: 'Меню',
                            child: CustomPaint(
                              size: const Size(24, 24),
                              painter: _MenuIconPainter(
                                isActive: widget.currentIndex == 1, activeColor: Colors.white, inactiveColor: context.colors.textMuted),
                            ),
                          ),
                          _buildNavItem(
                            index: 2,
                            label: 'Корзина',
                            badge: widget.cartCount > 0
                                ? (widget.cartCount > 99
                                    ? '99+'
                                    : '${widget.cartCount}')
                                : null,
                            child: CustomPaint(
                              size: const Size(24, 24),
                              painter: _CartIconPainter(
                                isActive: widget.currentIndex == 2, activeColor: Colors.white, inactiveColor: context.colors.textMuted),
                            ),
                          ),
                          _buildNavItem(
                            index: 3,
                            label: 'Кабинет',
                            child: CustomPaint(
                              size: const Size(24, 24),
                              painter: _ProfileIconPainter(
                                isActive: widget.currentIndex == 3, activeColor: Colors.white, inactiveColor: context.colors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required Widget child,
    String? badge,
  }) {
    final isActive = widget.currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _handleTap(index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: isActive ? 1.0 : 0.92,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutBack,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    child,
                    if (badge != null)
                      Positioned(
                        top: -6,
                        right: -12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          decoration: BoxDecoration(
                            // Активная вкладка → белый бейдж (чтобы не сливался с красным табом)
                            // Неактивная → красный бейдж
                            color: isActive
                                ? Colors.white
                                : context.colors.brand,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: isActive
                                    ? Colors.black.withValues(alpha: 0.15)
                                    : context.colors.brand
                                        .withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            badge,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              // Активная → красное число на белом
                              // Неактивная → белое число на красном
                              color: isActive
                                  ? context.colors.brand
                                  : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: Duration(milliseconds: 200),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? Colors.white
                        : context.colors.textMuted,
                    letterSpacing: isActive ? 0.2 : 0,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ========== ICON PAINTERS ==========

class _HomeIconPainter extends CustomPainter {
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  _HomeIconPainter({this.isActive = false, required this.activeColor, required this.inactiveColor});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isActive ? activeColor : inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final scale = size.width / 24;
    canvas.scale(scale);
    final path = Path()
      ..moveTo(3, 12)
      ..lineTo(12, 3)
      ..lineTo(21, 12)
      ..lineTo(21, 21)
      ..cubicTo(21, 21.55, 20.55, 22, 20, 22)
      ..lineTo(4, 22)
      ..cubicTo(3.45, 22, 3, 21.55, 3, 21)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawRRect(
      RRect.fromLTRBR(9, 13, 15, 22, const Radius.circular(2)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MenuIconPainter extends CustomPainter {
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  _MenuIconPainter({this.isActive = false, required this.activeColor, required this.inactiveColor});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isActive ? activeColor : inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final scale = size.width / 24;
    canvas.scale(scale);
    canvas.drawLine(const Offset(3, 12), const Offset(21, 12), paint);
    canvas.drawLine(const Offset(3, 6), const Offset(21, 6), paint);
    canvas.drawLine(const Offset(3, 18), const Offset(21, 18), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CartIconPainter extends CustomPainter {
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  _CartIconPainter({this.isActive = false, required this.activeColor, required this.inactiveColor});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isActive ? activeColor : inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final scale = size.width / 24;
    canvas.scale(scale);
    canvas.drawCircle(const Offset(9, 21), 1, paint);
    canvas.drawCircle(const Offset(20, 21), 1, paint);
    final path = Path()
      ..moveTo(1, 1)
      ..lineTo(5, 1)
      ..lineTo(7.68, 14.39)
      ..cubicTo(7.88, 15.28, 8.66, 16, 9.68, 16)
      ..lineTo(19.4, 16)
      ..cubicTo(20.42, 16, 21.2, 15.28, 21.4, 14.39)
      ..lineTo(23, 6)
      ..lineTo(6, 6);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProfileIconPainter extends CustomPainter {
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  _ProfileIconPainter({this.isActive = false, required this.activeColor, required this.inactiveColor});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isActive ? activeColor : inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final scale = size.width / 24;
    canvas.scale(scale);
    final path = Path()
      ..moveTo(20, 21)
      ..lineTo(20, 19)
      ..cubicTo(20, 16.8, 18.2, 15, 16, 15)
      ..lineTo(8, 15)
      ..cubicTo(5.8, 15, 4, 16.8, 4, 19)
      ..lineTo(4, 21);
    canvas.drawPath(path, paint);
    canvas.drawCircle(const Offset(12, 7), 4, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}