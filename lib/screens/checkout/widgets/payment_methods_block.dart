// lib/screens/checkout/widgets/payment_methods_block.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../providers/checkout_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/cart_provider.dart';

class PaymentMethodsBlock extends StatefulWidget {
  const PaymentMethodsBlock({super.key});

  @override
  State<PaymentMethodsBlock> createState() => _PaymentMethodsBlockState();
}

class _PaymentMethodsBlockState extends State<PaymentMethodsBlock> {
  bool _showInstallments = false;

  List<Map<String, dynamic>> _getAvailableMethods(
    String deliveryMethod,
    double deliveryCost,
    double subtotal,
    String currency,
  ) {
    final methods = <Map<String, dynamic>>[];
    final total = subtotal + deliveryCost;
    
    // 🔥 Для BYN и KZT — только оплата в валюте (invoice)
    if (currency != 'RUB') {
      methods.add({
        'id': 'invoice',
        'name': 'Оплата в $currency',
        'icon': 'assets/payment/t-bank.png',
        'description': 'Перевод через сервис «Оплати»',
      });
      return methods;
    }
    
    // 🔥 При получении — только если доставка бесплатная и RUB
    final isFreeDelivery = deliveryCost == 0;
    if (isFreeDelivery && (deliveryMethod == 'pickup-store' || deliveryMethod == 'courier')) {
      methods.add({
        'id': 'cod',
        'name': 'При получении',
        'icon': 'assets/payment/hand-money-cash-hold-coins.svg',
        'description': 'Оплата при получении заказа',
      });
    }
    
    // Картой онлайн — только RUB
    methods.add({
      'id': 'card',
      'name': 'Картой',
      'icon': 'assets/payment/card-credit-finance.svg',
      'description': 'Банковской картой онлайн',
    });
    
    // Подели — только RUB и сумма ≤ 30 000₽
    if (total <= 30000) {
      methods.add({
        'id': 'podeli',
        'name': 'Подели',
        'icon': 'assets/payment/logo_podeli.png',
        'description': 'Оплата частями без переплат',
      });
    }
    
    return methods;
  }

  List<double> _calculateInstallments(double total) {
    if (total <= 0) return [0, 0, 0, 0];
    final base = (total / 4).floorToDouble();
    final parts = [base, base, base, base];
    final sum = parts.reduce((a, b) => a + b);
    final remainder = total - sum;
    if (remainder != 0) parts[3] += remainder;
    return parts;
  }

  List<String> _getPaymentDates() {
    final now = DateTime.now();
    final months = ['янв', 'фев', 'мар', 'апр', 'мая', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    final dates = ['Сегодня'];
    for (int i = 1; i < 4; i++) {
      final date = now.add(Duration(days: i * 14));
      dates.add('${date.day} ${months[date.month - 1]}');
    }
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    final checkout = context.watch<CheckoutProvider>();
    final currency = context.watch<CurrencyProvider>();
    final cart = context.watch<CartProvider>();
    
    final methods = _getAvailableMethods(
      checkout.deliveryMethod,
      checkout.deliveryCost,
      cart.finalTotal,
      currency.currency,
    );
    
    // Автовыбор первого метода, если текущий недоступен
    if (methods.isNotEmpty && !methods.any((m) => m['id'] == checkout.paymentMethod)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        checkout.setPaymentMethod(methods.first['id'] as String);
      });
    }
    
    if (methods.isEmpty) return const SizedBox();
    
    final total = cart.finalTotal + checkout.deliveryCost;
    final installments = _calculateInstallments(total);
    final dates = _getPaymentDates();
    final currencySymbol = currency.symbol;
    
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Способ оплаты',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 16),
          
          ...methods.map((m) {
            final isSelected = checkout.paymentMethod == m['id'];
            final iconPath = m['icon'] as String;
            final isSvg = iconPath.endsWith('.svg');
            final isPng = iconPath.endsWith('.png');
            
            return GestureDetector(
              onTap: () {
                checkout.setPaymentMethod(m['id'] as String);
                setState(() => _showInstallments = m['id'] == 'podeli');
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? const Color(0xFFDD1847) : const Color(0xFFF0F0F0),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  color: isSelected ? const Color(0xFFFEF5F7) : Colors.white,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: isSvg
                            ? SvgPicture.asset(iconPath, width: 24, height: 24)
                            : isPng
                                ? Image.asset(iconPath, width: 24, height: 24, errorBuilder: (_, _, _) => const Icon(Icons.payment, size: 24, color: Color(0xFF999999)))
                                : const Icon(Icons.payment, size: 24, color: Color(0xFF999999)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m['name'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
                          if (m['description'] != null)
                            Text(m['description'] as String, style: const TextStyle(fontSize: 13, color: Color(0xFF8F8F9A))),
                        ],
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? const Color(0xFFDD1847) : const Color(0xFFD0D0D0), width: 2),
                      ),
                      child: isSelected
                          ? Center(child: Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFDD1847))))
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),
          
          if (_showInstallments && checkout.paymentMethod == 'podeli')
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_formatPrice(total)} $currencySymbol', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(20)), child: const Text('4 платежа', style: TextStyle(fontSize: 12, color: Color(0xFF666666)))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: installments.asMap().entries.map((e) {
                      final index = e.key;
                      final amount = e.value;
                      final isActive = index == 0;
                      return Expanded(
                        child: Column(
                          children: [
                            Container(height: 5, decoration: BoxDecoration(color: isActive ? const Color(0xFFEE3124) : const Color(0xFFE8E8E8), borderRadius: BorderRadius.circular(3))),
                            const SizedBox(height: 10),
                            Text(dates[index], style: TextStyle(fontSize: 12, color: isActive ? const Color(0xFF1A1A1A) : const Color(0xFF888888), fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
                            const SizedBox(height: 4),
                            Text('${_formatPrice(amount)} $currencySymbol', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Container(padding: const EdgeInsets.only(top: 10), decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE0E0E0), width: 1))), child: const Text('Первые 2 недели — беспроцентный период', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF999999)))),
                ],
              ),
            ),
          
          if (checkout.paymentMethod == 'invoice')
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFFFF9E6), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                      children: [
                        TextSpan(text: 'Оплата через сервис '),
                        TextSpan(text: '«Оплати»', style: TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: ' по номеру Т-банк '),
                        TextSpan(text: '+79208447732', style: TextStyle(fontWeight: FontWeight.w600)),
                        TextSpan(text: '.\nСчёт будет направлен на вашу почту в течение 24 часов.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('Внимание: банк может взимать комиссию за перевод.', style: TextStyle(fontSize: 12, color: Color(0xFF856404))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price == price.roundToDouble()) return '${price.toInt()}';
    return price.toStringAsFixed(2);
  }
}