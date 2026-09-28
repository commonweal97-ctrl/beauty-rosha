// lib/screens/profile/profile_widgets.dart
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

// ========================================================================
// ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ
// ========================================================================

class ProfileDivider extends StatelessWidget {
  const ProfileDivider({super.key});
  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        thickness: 1,
        indent: 16,
        endIndent: 16,
        color: context.colors.surfaceAlt,
      );
}

class ProfileTabCard extends StatelessWidget {
  final Widget customIcon;
  final int count;
  final String label;
  final VoidCallback onTap;
  const ProfileTabCard({
    super.key,
    required this.customIcon,
    required this.count,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              customIcon,
              SizedBox(height: 2),
              Text('$count',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
              Text(label, style: TextStyle(fontSize: 14, color: context.colors.textPrimary)),
            ],
          ),
        ),
      );
}

class ProfileMenuItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  const ProfileMenuItem({super.key, required this.title, this.subtitle, required this.onTap}) : trailing = null;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    if (subtitle != null)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(subtitle!, style: TextStyle(fontSize: 14, color: context.colors.textMuted)),
                      ),
                  ],
                ),
              ),
              ?trailing,
              SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 22, color: context.colors.textDisabled),
            ],
          ),
        ),
      );
}

// ========================================================================
// КАСТОМНЫЕ ИКОНКИ
// ========================================================================

class HeartPainter extends CustomPainter {
  final Color color;
  HeartPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final scaleX = size.width / 23;
    final scaleY = size.height / 21;
    canvas.drawPath(
      Path()
        ..moveTo(11.5 * scaleX, 19.5 * scaleY)
        ..cubicTo(5.5 * scaleX, 15 * scaleY, 1 * scaleX, 10.8 * scaleY, 1 * scaleX, 7 * scaleY)
        ..cubicTo(1 * scaleX, 4.2 * scaleY, 3.1 * scaleX, 1.5 * scaleY, 6.5 * scaleX, 1.5 * scaleY)
        ..cubicTo(8 * scaleX, 1.5 * scaleY, 9.5 * scaleX, 2 * scaleY, 10.7 * scaleX, 3 * scaleY)
        ..lineTo(11.5 * scaleX, 3 * scaleY)
        ..lineTo(12.3 * scaleX, 2.2 * scaleY)
        ..cubicTo(13.5 * scaleX, 1.3 * scaleY, 15 * scaleX, 1.5 * scaleY, 16.5 * scaleX, 1.5 * scaleY)
        ..cubicTo(19.9 * scaleX, 1.5 * scaleY, 22 * scaleX, 4.2 * scaleY, 22 * scaleX, 7 * scaleY)
        ..cubicTo(22 * scaleX, 10.8 * scaleY, 17.5 * scaleX, 15 * scaleY, 11.5 * scaleX, 19.5 * scaleY)
        ..close(),
      paint,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StarPainter extends CustomPainter {
  final Color color;
  StarPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.scale(size.width / 24);
    canvas.drawPath(
      Path()
        ..moveTo(12, 2)
        ..lineTo(15.09, 8.26)
        ..lineTo(22, 9.27)
        ..lineTo(17, 14.14)
        ..lineTo(18.18, 21.02)
        ..lineTo(12, 17.77)
        ..lineTo(5.82, 21.02)
        ..lineTo(7, 14.14)
        ..lineTo(2, 9.27)
        ..lineTo(8.91, 8.26)
        ..close(),
      paint,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PurchasesIconPainter extends CustomPainter {
  final Color color;
  PurchasesIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.scale(size.width / 24);
    canvas.drawPath(
      Path()
        ..moveTo(6, 2)
        ..lineTo(3, 6)
        ..lineTo(3, 20)
        ..cubicTo(3, 21.1, 3.9, 22, 5, 22)
        ..lineTo(19, 22)
        ..cubicTo(20.1, 22, 21, 21.1, 21, 20)
        ..lineTo(21, 6)
        ..lineTo(18, 2)
        ..close(),
      paint,
    );
    canvas.drawLine(Offset(3, 6), const Offset(21, 6), paint);
    canvas.drawPath(
      Path()
        ..moveTo(16, 10)
        ..cubicTo(16, 12.2, 14.2, 14, 12, 14)
        ..cubicTo(9.8, 14, 8, 12.2, 8, 10),
      paint,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WaitlistIconPainter extends CustomPainter {
  final Color color;
  WaitlistIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.scale(size.width / 24);
    canvas.drawCircle(const Offset(12, 12), 10, paint);
    canvas.drawLine(const Offset(12, 12), const Offset(12, 6), paint);
    canvas.drawLine(const Offset(12, 12), const Offset(16, 14), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}