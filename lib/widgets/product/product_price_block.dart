// lib/widgets/product/product_price_block.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../models/product_detail.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../sale_countdown_timer.dart';
import 'price_detail_sheet.dart';

class ProductPriceBlock extends StatelessWidget {
  final ProductDetail product;

  const ProductPriceBlock({
    super.key,
    required this.product,
  });

  String _formatPrice(double price) {
    if (price == price.roundToDouble()) return '${price.toInt()}';
    return price.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (product.inStock)
                _buildPrice(currency, isLoggedIn, context)
              else
                const Text(
                  'Нет в наличии',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFE74C3C)),
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
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE74C3C)),
                              children: [
                                TextSpan(
                                  text: '${product.stock} шт',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE74C3C)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : RichText(
                        text: TextSpan(
                          text: 'Осталось ',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF8F8F9A)),
                          children: [
                            TextSpan(
                              text: '${product.stock} шт',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFE74C3C)),
                            ),
                          ],
                        ),
                      ),
            ],
          ),
          
          // 🔥 Таймер обратного отсчёта акции
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

  Widget _buildPrice(CurrencyProvider currency, bool isLoggedIn, BuildContext context) {
    final symbolStyle = TextStyle(
      fontSize: currency.symbolFontSize,
      fontWeight: FontWeight.w800,
      fontFamily: currency.fontFamily,
    );

    if (product.hasSale) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '% ${_formatPrice(product.salePrice!)} ',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFFFF4444)),
          ),
          Text(currency.symbol, style: symbolStyle.copyWith(color: const Color(0xFFFF4444), fontSize: 24)),
          const SizedBox(width: 6),
          Text(
            '${_formatPrice(product.price)} ',
            style: const TextStyle(fontSize: 16, color: Color(0xFF868695), decoration: TextDecoration.lineThrough),
          ),
          Text(currency.symbol, style: symbolStyle.copyWith(fontSize: 16, color: const Color(0xFF868695), decoration: TextDecoration.lineThrough)),
        ],
      );
    }

    if (isLoggedIn) {
      return GestureDetector(
        onTap: () {
          PriceDetailSheet.show(
            context,
            cardPrice: product.cardPrice ?? product.price * 0.95,
            fullPrice: product.price,
            hasCard: true,
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.credit_card_rounded, size: 28, color: Color(0xFFDD1847)),
            const SizedBox(width: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${_formatPrice(product.cardPrice ?? product.price)} ',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFFDD1847)),
                ),
                Text(currency.symbol, style: symbolStyle.copyWith(color: const Color(0xFFDD1847), fontSize: 24)),
                const SizedBox(width: 6),
                Text(
                  '${_formatPrice(product.price)} ',
                  style: const TextStyle(fontSize: 16, color: Color(0xFF868695), decoration: TextDecoration.lineThrough),
                ),
                Text(currency.symbol, style: symbolStyle.copyWith(fontSize: 16, color: const Color(0xFF868695), decoration: TextDecoration.lineThrough)),
              ],
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        PriceDetailSheet.show(
          context,
          cardPrice: product.cardPrice ?? product.price * 0.95,
          fullPrice: product.price,
          hasCard: false,
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.credit_card_rounded, size: 28, color: Color(0xFFDD1847)),
          const SizedBox(width: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${_formatPrice(product.cardPrice ?? product.price)} ',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFFDD1847)),
              ),
              Text(currency.symbol, style: symbolStyle.copyWith(color: const Color(0xFFDD1847), fontSize: 24)),
              const SizedBox(width: 6),
              Text(
                '${_formatPrice(product.price)} ',
                style: const TextStyle(fontSize: 16, color: Color(0xFF868695)),
              ),
              Text(currency.symbol, style: symbolStyle.copyWith(fontSize: 16, color: const Color(0xFF868695))),
            ],
          ),
        ],
      ),
    );
  }
}