// lib/screens/checkout/widgets/payment_methods_block.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../providers/checkout_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../core/app_colors.dart';
import '../../../core/price_formatter.dart';

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
    if (isFreeDelivery &&
        (deliveryMethod == 'pickup-store' || deliveryMethod == 'courier')) {
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

    // Сплит — только RUB и сумма ≤ 50 000₽
    if (total <= 50000) {
      methods.add({
        'id': 'yandex_split',
        'name': 'Сплит',
        'icon': 'assets/payment/ya_split.png',
        'description': 'Оплата частями от Яндекса',
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
    final months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'мая',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
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
    final isYandexSplit = checkout.paymentMethod == 'yandex_split';
    final currency = context.watch<CurrencyProvider>();
    final cart = context.watch<CartProvider>();

    final methods = _getAvailableMethods(
      checkout.deliveryMethod,
      checkout.deliveryCost,
      cart.finalTotal,
      currency.currency,
    );

    // Автовыбор первого метода, если текущий недоступен
    if (methods.isNotEmpty &&
        !methods.any((m) => m['id'] == checkout.paymentMethod)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        checkout.setPaymentMethod(methods.first['id'] as String);
      });
    }

    if (methods.isEmpty) return SizedBox();

    final total = cart.finalTotal + checkout.deliveryCost;
    final installments = _calculateInstallments(total);
    final dates = _getPaymentDates();

    return Container(
      color: context.colors.surface,
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Способ оплаты',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          SizedBox(height: 16),

          ...methods.map((m) {
            final isSelected = checkout.paymentMethod == m['id'];
            final iconPath = m['icon'] as String;
            final isSvg = iconPath.endsWith('.svg');
            final isPng = iconPath.endsWith('.png');

            return GestureDetector(
              onTap: () {
                checkout.setPaymentMethod(m['id'] as String);
                setState(
                  () => _showInstallments =
                      (m['id'] == 'podeli' || m['id'] == 'yandex_split'),
                );
              },
              child: Container(
                padding: EdgeInsets.all(14),
                margin: EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? context.colors.brand
                        : context.colors.surfaceAlt,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  color: isSelected
                      ? context.colors.brandLight
                      : context.colors.surface,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : context.colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: isSvg
                            ? SvgPicture.asset(
                                iconPath,
                                width: 24,
                                height: 24,
                                colorFilter: ColorFilter.mode(
                                  isSelected
                                      ? Colors.black
                                      : context.colors.textPrimary,
                                  BlendMode.srcIn,
                                ),
                              )
                            : isPng
                            ? Image.asset(
                                iconPath,
                                width: 24,
                                height: 24,
                                errorBuilder: (_, _, _) => Icon(
                                  Icons.payment,
                                  size: 24,
                                  color: context.colors.textMuted,
                                ),
                              )
                            : Icon(
                                Icons.payment,
                                size: 24,
                                color: isSelected
                                    ? Colors.black
                                    : context.colors.textPrimary,
                              ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m['name'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          if (m['description'] != null)
                            Text(
                              m['description'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.colors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? context.colors.brand
                              : context.colors.border,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? Center(
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.colors.brand,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),

          if (_showInstallments &&
              (checkout.paymentMethod == 'podeli' ||
                  checkout.paymentMethod == 'yandex_split'))
            Container(
              margin: EdgeInsets.only(top: 4),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      context.formatPrice(
                        total,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isYandexSplit ? 'от 2 до 6 платежей' : '4 платежа',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: installments.asMap().entries.map((e) {
                      final index = e.key;
                      final amount = e.value;
                      final isActive = index == 0;
                      return Expanded(
                        child: Column(
                          children: [
                            Container(
                              height: 5,
                              decoration: BoxDecoration(
                                color: isActive
                                    ? (isYandexSplit
                                          ? Color(0xFF4CAF50)
                                          : Color(0xFFEE3124))
                                    : context.colors.border,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              dates[index],
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive
                                    ? context.colors.textPrimary
                                    : context.colors.textMuted,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            SizedBox(height: 4),
                            context.formatPrice(
                              amount,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: context.colors.border, width: 1),
                      ),
                    ),
                    child: Text(
                      isYandexSplit
                          ? 'Точный график зависит от решения Яндекса'
                          : 'Первые 2 недели — беспроцентный период',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (checkout.paymentMethod == 'invoice')
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFE8A3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Оплата через «Оплати»',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF595959),
                        height: 1.5,
                      ),
                      children: const [
                        TextSpan(text: 'Перевод в валюте покупателя. '),
                        TextSpan(
                          text:
                              'После оформления будет создан чат в приложении',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        TextSpan(
                          text:
                              ' для согласования оплаты. Может взиматься комиссия.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

}
