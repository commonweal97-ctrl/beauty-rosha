// lib/widgets/cart/card_banner.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../qr_popup.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/main_shell.dart';
import '../../core/price_formatter.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.credit_card_rounded,
              color: isPendingCart
                  ? context.colors.success
                  : context.colors.brand,
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
                      color: isPendingCart
                          ? context.colors.success
                          : context.colors.textPrimary,
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
                          'Скидка ',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.success,
                          ),
                        ),
                        context.formatPrice(
                          cart.cardDiscount,
                          fontSize: 13,
                          color: context.colors.success,
                          prefix: '−',
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        context.formatPrice(
                          potentialDiscount,
                          fontSize: 13,
                          color: context.colors.textMuted,
                        ),
                        Text(
                          ' с Б-картой',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (isPendingCart)
              Icon(
                Icons.check_circle,
                color: context.colors.success,
                size: 20,
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.colors.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Активировать',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.colors.brand,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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