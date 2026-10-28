import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/cancellation_info.dart';

/// Диалог подтверждения отмены заказа (аналог Web-попапа).
class CancelOrderDialog extends StatelessWidget {
  final int orderId;
  final CancellationInfo info;

  const CancelOrderDialog({
    super.key,
    required this.orderId,
    required this.info,
  });

  static Future<bool> show(BuildContext context, int orderId, CancellationInfo info) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => CancelOrderDialog(orderId: orderId, info: info),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = info.isPaid;
    final isFree = info.isFree || info.fee <= 0;

    IconData icon;
    Color iconBgColor;
    Color iconColor;
    InlineSpan messageSpan;

    final keyStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: context.colors.textPrimary,
    );
    final feeStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: const Color(0xFFEF6C00),
    );
    final refundStyle = TextStyle(
      fontWeight: FontWeight.w700,
      color: const Color(0xFF2E7D32),
    );
    final providerStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: context.colors.textPrimary,
    );
    final normalStyle = TextStyle(
      color: context.colors.textSecondary,
    );

    if (!isPaid) {
      messageSpan = TextSpan(
        style: normalStyle,
        children: [
          const TextSpan(text: 'Отмена для вас '),
          TextSpan(text: 'бесплатная', style: keyStyle),
          const TextSpan(text: '. Денежные средства '),
          TextSpan(text: 'не списывались', style: keyStyle),
          const TextSpan(text: '.'),
        ],
      );
      icon = Icons.receipt_long_outlined;
      iconBgColor = const Color(0xFFE3F2FD);
      iconColor = const Color(0xFF1565C0);
    } else if (isFree) {
      messageSpan = TextSpan(
        style: normalStyle,
        children: [
          const TextSpan(text: 'Отмена для вас '),
          TextSpan(text: 'бесплатная', style: keyStyle),
          const TextSpan(text: '. Денежные средства '),
          TextSpan(text: info.formatMoney(info.refund), style: refundStyle),
          const TextSpan(text: ' вернутся в течение '),
          TextSpan(text: '1–3 рабочих дней', style: keyStyle),
          const TextSpan(text: ' на вашу банковскую карту.'),
        ],
      );
      icon = Icons.check_rounded;
      iconBgColor = const Color(0xFFE8F5E9);
      iconColor = const Color(0xFF2E7D32);
    } else {
      final provider = info.deliveryProvider;
      messageSpan = TextSpan(
        style: normalStyle,
        children: [
          const TextSpan(text: 'Будет удержано '),
          TextSpan(text: info.formatMoney(info.fee), style: feeStyle),
          if (provider != null) ...[
            const TextSpan(text: ' ('),
            TextSpan(text: provider, style: providerStyle),
            const TextSpan(text: ')'),
          ],
          const TextSpan(text: ' в связи с тем, что услуги доставки частично были оказаны. Оставшиеся '),
          TextSpan(text: info.formatMoney(info.refund), style: refundStyle),
          const TextSpan(text: ' вернутся в течение '),
          TextSpan(text: '1–3 рабочих дней', style: keyStyle),
          const TextSpan(text: ' на вашу банковскую карту.'),
        ],
      );
      icon = Icons.warning_amber_rounded;
      iconBgColor = const Color(0xFFFFF3E0);
      iconColor = const Color(0xFFEF6C00);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: iconColor),
            ),
            const SizedBox(height: 20),
            Text(
              'Уверены, что хотите отменить заказ?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: context.colors.textSecondary,
                ),
                children: [messageSpan],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: context.colors.border),
                    ),
                    child: Text(
                      'Не отменять',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFree ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Отменить заказ',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
