// lib/widgets/quick_actions.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../screens/main_shell.dart';
import '../screens/auth/login_screen.dart';
import '../screens/profile/purchases_screen.dart';
import '../screens/profile/orders_screen.dart';
import '../screens/service/service_screen.dart';
import '../widgets/qr_popup.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  void _handleRestrictedAction(BuildContext context, Widget screen) {
    final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!isLoggedIn) {
      MainShell.push(context, const LoginScreen());
      return;
    }
    MainShell.push(context, screen);
  }

  void _showQrPopup(BuildContext context) {
    QrPopup.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActionButton(
            label: 'Б-Запись',
            onTap: () async {
              final url = Uri.parse('https://запись.бьютироща.рф');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: CustomPaint(size: const Size(28, 28), painter: _CalendarIconPainter()),
          ),
          _ActionButton(
            label: 'Сервис',
            onTap: () => _handleRestrictedAction(context, const ServiceScreen()),
            child: const Icon(Icons.build_outlined, size: 28, color: Color(0xFFDD1847)),
          ),
          GestureDetector(
            onTap: () => _showQrPopup(context),
            child: Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFF0506E), Color(0xFFDD1847)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: const Color(0xFFDD1847).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              child: Center(child: SvgPicture.asset('assets/icons/qrcode.svg', width: 32, height: 32)),
            ),
          ),
          _ActionButton(
            label: 'Куплено',
            onTap: () => _handleRestrictedAction(context, const PurchasesScreen()),
            child: CustomPaint(size: const Size(28, 28), painter: _PurchasesIconPainter()),
          ),
          _ActionButton(
            label: 'Заказы',
            onTap: () => _handleRestrictedAction(context, const OrdersScreen()),
            child: CustomPaint(size: const Size(28, 28), painter: _TrackIconPainter()),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Widget child;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 62,  // ← было 56, стало 62
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,              // ← было 10, стало 11 (чуть меньше для вместимости)
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.visible,  // ← не обрезать
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFDD1847)..style = PaintingStyle.stroke..strokeWidth = 2;
    final scale = size.width / 24; canvas.scale(scale);
    canvas.drawRRect(RRect.fromLTRBR(3, 4, 21, 22, const Radius.circular(2)), paint);
    canvas.drawLine(const Offset(16, 2), const Offset(16, 6), paint);
    canvas.drawLine(const Offset(8, 2), const Offset(8, 6), paint);
    canvas.drawLine(const Offset(3, 10), const Offset(21, 10), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PurchasesIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFDD1847)..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final scale = size.width / 24; canvas.scale(scale);
    final path = Path()..moveTo(6, 2)..lineTo(3, 6)..lineTo(3, 20)..cubicTo(3, 21.1, 3.9, 22, 5, 22)..lineTo(19, 22)..cubicTo(20.1, 22, 21, 21.1, 21, 20)..lineTo(21, 6)..lineTo(18, 2)..close();
    canvas.drawPath(path, paint); canvas.drawLine(const Offset(3, 6), const Offset(21, 6), paint);
    final path2 = Path()..moveTo(16, 10)..cubicTo(16, 12.2, 14.2, 14, 12, 14)..cubicTo(9.8, 14, 8, 12.2, 8, 10);
    canvas.drawPath(path2, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TrackIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFDD1847)..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final scale = size.width / 24; canvas.scale(scale);
    final path = Path()..moveTo(21, 16)..lineTo(21, 8)..cubicTo(21, 7.3, 20.6, 6.5, 20, 6.27)..lineTo(13, 2.27)..cubicTo(12.4, 2, 11.6, 2, 11, 2.27)..lineTo(4, 6.27)..cubicTo(3.4, 6.5, 3, 7.3, 3, 8)..lineTo(3, 16)..cubicTo(3, 16.7, 3.4, 17.5, 4, 17.73)..lineTo(11, 21.73)..cubicTo(11.6, 22, 12.4, 22, 13, 21.73)..lineTo(20, 17.73)..cubicTo(20.6, 17.5, 21, 16.7, 21, 16)..close();
    canvas.drawPath(path, paint); canvas.drawLine(const Offset(3.27, 6.96), const Offset(12, 12.01), paint);
    canvas.drawLine(const Offset(12, 12.01), const Offset(20.73, 6.96), paint);
    canvas.drawLine(const Offset(12, 22.08), const Offset(12, 12), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}