// lib/widgets/product/product_price_block.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../models/product_detail.dart';
import '../../providers/cart_provider.dart';
import '../../core/product_price_display.dart';
import '../sale_countdown_timer.dart';
import 'price_detail_sheet.dart';
import '../../core/app_colors.dart';
import '../../core/price_formatter.dart';

class ProductPriceBlock extends StatelessWidget {
  final ProductDetail product;

  const ProductPriceBlock({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    final hasActiveCard = context.watch<CartProvider>().hasCard;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (product.inStock)
                _buildPrice(hasActiveCard, context)
              else
                Text(
                  'Нет в наличии',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.colors.error),
                ),
              const Spacer(),
              if (product.inStock)
                product.stock <= 3
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/lightning.svg',
                            width: 14,
                            height: 14,
                          ),
                          const SizedBox(width: 4),
                          RichText(
                            text: TextSpan(
                              text: 'Осталось ',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.error),
                              children: [
                                TextSpan(
                                  text: '${product.stock} шт',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.error),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : RichText(
                        text: TextSpan(
                          text: 'Осталось ',
                          style: TextStyle(fontSize: 13, color: context.colors.textMuted),
                          children: [
                            TextSpan(
                              text: '${product.stock} шт',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.error),
                            ),
                          ],
                        ),
                      ),
            ],
          ),

          // Таймер обратного отсчёта акции
          if (product.hasActiveSaleDate) ...[
            const SizedBox(height: 10),
            SaleCountdownTimer(
              saleEndDate: product.saleEndDate!,
              saleStartDate: product.saleDateFrom,
              compact: false,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrice(bool hasActiveCard, BuildContext context) {
    final display = ProductPriceDisplay.resolve(
      regularPrice: product.price,
      cardPrice: product.cardPrice,
      salePrice: product.hasSale ? product.salePrice : null,
      hasActiveCard: hasActiveCard,
    );

    if (display.isSale) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          context.formatPrice(
            display.primaryPrice,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: context.colors.error,
            prefix: '% ',
          ),
          const SizedBox(width: 6),
          if (display.secondaryPrice != null)
            context.formatPrice(
              display.secondaryPrice!,
              fontSize: 16,
              color: context.colors.textMuted,
              decoration: TextDecoration.lineThrough,
            ),
        ],
      );
    }

    final effectiveCardPrice = product.cardPrice ?? (product.price * 0.95);

    return GestureDetector(
      onTap: () {
        PriceDetailSheet.show(
          context,
          cardPrice: effectiveCardPrice,
          fullPrice: product.price,
          hasCard: hasActiveCard,
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.credit_card_rounded, size: 28, color: context.colors.brand),
          const SizedBox(width: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              context.formatPrice(
                display.primaryPrice,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: context.colors.brand,
              ),
              if (display.secondaryPrice != null) ...[
                const SizedBox(width: 6),
                context.formatPrice(
                  display.secondaryPrice!,
                  fontSize: 16,
                  color: context.colors.textMuted,
                  decoration: display.strikethroughSecondary
                      ? TextDecoration.lineThrough
                      : null,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
