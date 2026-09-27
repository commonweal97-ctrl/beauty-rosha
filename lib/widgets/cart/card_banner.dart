// lib/widgets/cart/card_banner.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../qr_popup.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/main_shell.dart';

class CardBanner extends StatelessWidget {
  const CardBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.select<CartProvider, _CardBannerData>(
      (c) => _CardBannerData(
        hasCard: c.hasCard,
        cardStatus: c.cardStatus,
        cardDiscount: c.cardDiscount,
        totalOldPrice: c.totalOldPrice,
        checkedCount: c.checkedIds.length,
      ),
    );
    
    if (cart.checkedCount == 0) return const SizedBox.shrink();
    if (cart.cardStatus == 'active') return const SizedBox.shrink();
    
    final isLoggedIn = context.select<AuthProvider, bool>(
      (a) => a.isLoggedIn,
    );
    
    final currency = context.watch<CurrencyProvider>();
    
    final isPendingCart = cart.hasCard && cart.cardStatus == 'pending_cart';
    
    if (cart.hasCard && cart.cardDiscount <= 0) return const SizedBox.shrink();
    
    final potentialDiscount = (cart.totalOldPrice * 0.05).roundToDouble();
    
    if (!cart.hasCard && potentialDiscount <= 0) return const SizedBox.shrink();
    
    return GestureDetector(
      onTap: () {
        if (!isLoggedIn) {
          MainShell.push(context, const LoginScreen());
          return;
        }
        QrPopup.show(context);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.credit_card_rounded,
              color: isPendingCart ? const Color(0xFF4CAF50) : const Color(0xFFDD1847),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPendingCart ? 'Б-карта активна' : 'Вы можете сэкономить',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isPendingCart ? const Color(0xFF4CAF50) : const Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 🔥 Исправлено: RichText с правильным шрифтом для валюты
                  if (isPendingCart)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'Скидка −${_formatPrice(cart.cardDiscount)} ',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF4CAF50),
                          ),
                        ),
                        Text(
                          currency.symbol,
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF4CAF50),
                            fontFamily: currency.fontFamily,
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${_formatPrice(potentialDiscount)} ',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF888888),
                          ),
                        ),
                        Text(
                          currency.symbol,
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF888888),
                            fontFamily: currency.fontFamily,
                          ),
                        ),
                        Text(
                          ' с Б-картой',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (isPendingCart)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF4CAF50),
                size: 20,
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDD1847).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Активировать',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDD1847)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price <= 0) return '0';
    if (price == price.roundToDouble()) return '${price.toInt()}';
    return price.toStringAsFixed(2);
  }
}

class _CardBannerData {
  final bool hasCard;
  final String? cardStatus;
  final double cardDiscount;
  final double totalOldPrice;
  final int checkedCount;

  const _CardBannerData({
    required this.hasCard,
    required this.cardStatus,
    required this.cardDiscount,
    required this.totalOldPrice,
    required this.checkedCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CardBannerData &&
          hasCard == other.hasCard &&
          cardStatus == other.cardStatus &&
          cardDiscount == other.cardDiscount &&
          totalOldPrice == other.totalOldPrice &&
          checkedCount == other.checkedCount;

  @override
  int get hashCode => hasCard.hashCode ^ cardStatus.hashCode ^ cardDiscount.hashCode ^ totalOldPrice.hashCode ^ checkedCount.hashCode;
}