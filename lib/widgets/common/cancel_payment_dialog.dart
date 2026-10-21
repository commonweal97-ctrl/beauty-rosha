import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class CancelPaymentDialog extends StatelessWidget {
  final bool isWaitingForBank;

  const CancelPaymentDialog({super.key, this.isWaitingForBank = false});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: (isWaitingForBank ? Colors.orange : context.colors.brand).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isWaitingForBank ? Icons.hourglass_top_rounded : Icons.payment_rounded,
                size: 32,
                color: isWaitingForBank ? Colors.orange : context.colors.brand,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isWaitingForBank ? 'Ожидаем оплату' : 'Прервать оплату?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isWaitingForBank
                  ? 'Вы перешли в банк для оплаты. Если вы уже оплатили, подождите несколько секунд.'
                  : 'Если вы закроете окно, заказ не будет оплачен. Вы сможете вернуться к оплате позже в деталях заказа.',
              style: TextStyle(fontSize: 14, color: context.colors.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(color: context.colors.border),
                      foregroundColor: context.colors.textPrimary,
                    ),
                    child: Text(isWaitingForBank ? 'Я оплатил' : 'Продолжить', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: context.colors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Выйти', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
