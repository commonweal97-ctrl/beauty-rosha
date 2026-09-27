// lib/widgets/product/podeli_banner.dart
import 'package:flutter/material.dart';
import 'podeli_sheet.dart';

class PodeliBanner extends StatelessWidget {
  final double price;
  final String? productImage;

  const PodeliBanner({super.key, required this.price, this.productImage});

  double get _monthlyPayment => (price / 4).roundToDouble();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        PodeliSheet.show(context, price: price, productImage: productImage);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              // Иконка Подели
              Image.asset(
                'assets/payment/logo_podeli.png',
                width: 28,
                height: 28,
              ),
              const SizedBox(width: 12),
              // Текст
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Подели на 4 платежа',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Без переплат, первый платёж ${_formatPrice(_monthlyPayment)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8F8F9A),
                      ),
                    ),
                  ],
                ),
              ),
              // 🔥 Стрелка по центру справа
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.chevron_right, color: Color(0xFF999999), size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    if (price == price.roundToDouble()) return '${price.toInt()} ₽';
    return '${price.toStringAsFixed(2)} ₽';
  }
}