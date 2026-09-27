// lib/widgets/cart/free_delivery_progress_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/cart_provider.dart';
import '../../providers/city_provider.dart';
import '../../providers/currency_provider.dart';

class FreeDeliveryProgressBar extends StatelessWidget {
  const FreeDeliveryProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final currency = context.watch<CurrencyProvider>();
    final freeThreshold =
        context.watch<CityProvider>().freeDeliveryThreshold;

    final checkedTotal = cart.finalTotal;

    if (freeThreshold <= 0 || checkedTotal <= 0) {
      return const SizedBox.shrink();
    }

    final progress = (checkedTotal / freeThreshold).clamp(0.0, 1.0);
    final remaining =
        (freeThreshold - checkedTotal).clamp(0, double.infinity).toInt();
    final isAchieved = checkedTotal >= freeThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: isAchieved
                ? [
                    const TextSpan(
                      text: 'Доставка будет бесплатной',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                  ]
                : [
                    const TextSpan(
                      text: 'Осталось ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8F8F9A),
                      ),
                    ),
                    TextSpan(
                      text: '$remaining ',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    TextSpan(
                      text: currency.symbol,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                        fontFamily: currency.fontFamily,
                      ),
                    ),
                    const TextSpan(
                      text: ' до бесплатной доставки',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF8F8F9A),
                      ),
                    ),
                  ],
          ),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 2,
            backgroundColor: const Color(0xFFECECF0),
            valueColor: AlwaysStoppedAnimation<Color>(
              isAchieved ? const Color(0xFF4CAF50) : const Color(0xFFDD1847),
            ),
          ),
        ),
      ],
    );
  }
}