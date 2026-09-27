// lib/widgets/cart/first_order_discount_banner.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_logger.dart';
import '../../providers/cart_provider.dart';
import '../../providers/currency_provider.dart';
import '../../services/api_service.dart';

const _logTag = 'FirstOrderDiscountBanner';

/// Баннер скидки на первый заказ в приложении.
///
/// Архитектура:
/// - Сам слушает CartProvider через Consumer
/// - Автоматически обновляется при изменении корзины
/// - Показывает детали через отдельный метод
class FirstOrderDiscountBanner extends StatelessWidget {
  const FirstOrderDiscountBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.firstOrderDiscount <= 0 || cart.firstOrderInfo == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8E8E8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/mobile-b-roscha.webp',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF4CAF50).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.phone_android,
                        color: Color(0xFF4CAF50),
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ваша скидка на первый заказ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Не упустите возможность - добавьте товары! Она действует лишь раз.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF777777),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showDetails(context, cart),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF0F0F0),
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            size: 12,
                            color: Color(0xFF999999),
                          ),
                        ),
                        const SizedBox(height: 2),
                        _buildPriceWidget(context, cart.firstOrderDiscount),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriceWidget(BuildContext context, double price) {
    final currency = context.read<CurrencyProvider>();
    final formatted = price <= 0
        ? '0'
        : (price == price.roundToDouble()
            ? '${price.toInt()}'
            : price.toStringAsFixed(2));
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$formatted ',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E7D32),
            ),
          ),
          TextSpan(
            text: currency.symbol,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2E7D32),
              fontFamily: currency.fontFamily,
            ),
          ),
        ],
      ),
    );
  }

  void _showDetails(BuildContext context, CartProvider cart) async {
    final currency = context.read<CurrencyProvider>();
    const maxDiscountRub = 2000.0;
    String maxDiscountText = '2 000 ₽';

    final ratesResult = await ApiService.get(
      '/api/currency/rates',
      forceRefresh: true,
    );

    if (ratesResult.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadRates failed: ${ratesResult.errorOrNull?.message}',
      );
    } else {
      final data = ratesResult.valueOrNull?['data'];
      final rates = (data is Map ? data['rates'] : null) as Map?;

      if (rates != null) {
        if (currency.currency == 'BYN' && rates.containsKey('BYN')) {
          final rateData = rates['BYN'];
          final rate = (rateData is Map ? rateData['rate'] : null) as num?;
          final rateValue = rate?.toDouble() ?? 28.5;
          final converted = (maxDiscountRub / rateValue).toStringAsFixed(0);
          maxDiscountText = '$converted BYN';
        } else if (currency.currency == 'KZT' && rates.containsKey('KZT')) {
          final rateData = rates['KZT'];
          final rate = (rateData is Map ? rateData['rate'] : null) as num?;
          final rateValue = rate?.toDouble() ?? 6.3;
          final converted = (maxDiscountRub / rateValue).round();
          maxDiscountText = '$converted ₸';
        }
      }
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Ваша скидка на первый заказ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Скидка равна 5% от суммы корзины и не может превышать $maxDiscountText. Скидка суммируется с другими акциями и предложениями.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF555555),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFF0F0F5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Понятно',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDD1847),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierColor: Colors.black54,
      barrierDismissible: true,
    );
  }
}