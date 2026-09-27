// lib/screens/checkout/widgets/order_summary_block.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/checkout_provider.dart';

class OrderSummaryBlock extends StatelessWidget {
  const OrderSummaryBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final currency = context.watch<CurrencyProvider>();
    final checkout = context.watch<CheckoutProvider>();
    
    final checkedCount = cart.checkedIds.fold(0, (sum, id) => sum + (cart.items[id] ?? 0));
    final totalOldPrice = cart.totalOldPrice;
    final totalPrice = cart.totalPrice;
    final cardDiscount = cart.cardDiscount;
    final promoDiscount = cart.promoDiscount;
    final firstOrderDiscount = cart.firstOrderDiscount;
    final deliveryCost = checkout.deliveryCost;
    final finalTotal = cart.finalTotal + deliveryCost - checkout.bonusAmount;
    final hasCard = cart.hasCard;
    
    final saleDiscount = (totalOldPrice - totalPrice - cardDiscount).clamp(0.0, double.infinity).toDouble();
    
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Сводка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 16),
          
          _buildRow('Товары ($checkedCount шт.)', _formatPrice(totalOldPrice, currency), currency, isMuted: true),
          
          if (hasCard && cardDiscount > 0)
            _buildRow('Скидка по Б-карте', '−${_formatPrice(cardDiscount, currency)}', currency, isDiscount: true),
          
          if (saleDiscount > 0)
  _buildRow('Скидка по акции', '−${_formatPrice(saleDiscount, currency)}', currency, isDiscount: true),

if (promoDiscount > 0)
  _buildRow('Промо-акция', '−${_formatPrice(promoDiscount, currency)}', currency, isDiscount: true),
          
          if (firstOrderDiscount > 0)
            _buildRow('Иные скидки', '−${_formatPrice(firstOrderDiscount, currency)}', currency, isDiscount: true),
          
          if (checkout.bonusAmount > 0)
            _buildRow('Бонусы', '−${_formatPrice(checkout.bonusAmount.toDouble(), currency)}', currency, isDiscount: true),
          
          _buildRow('Доставка', deliveryCost > 0 ? _formatPrice(deliveryCost, currency) : 'Бесплатно', currency, isMuted: true, valueColor: deliveryCost > 0 ? null : const Color(0xFF4CAF50)),
          
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFECECF0)),
          const SizedBox(height: 12),
          
          _buildRow('К оплате', _formatPrice(finalTotal, currency), currency, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value,
    CurrencyProvider currency, {
    bool isMuted = false,
    bool isDiscount = false,
    bool isTotal = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? 18 : 15, fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400, color: isMuted ? const Color(0xFF8F8F9A) : const Color(0xFF1A1A1A))),
          Text(value, style: TextStyle(fontSize: isTotal ? 22 : 15, fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600, fontFamily: currency.fontFamily, color: valueColor ?? (isDiscount ? const Color(0xFF2E7D32) : const Color(0xFF1A1A1A)))),
        ],
      ),
    );
  }

  String _formatPrice(double price, CurrencyProvider currency) {
    if (price <= 0) return '0 ${currency.symbol}';
    if (currency.currency == 'BYN') return '${price.toStringAsFixed(2)} ${currency.symbol}';
    if (price == price.roundToDouble()) return '${price.toInt()} ${currency.symbol}';
    return '${price.toStringAsFixed(2)} ${currency.symbol}';
  }
}