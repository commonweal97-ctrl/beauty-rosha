// lib/widgets/product/price_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import '../qr_popup.dart';

class PriceDetailSheet extends StatelessWidget {
  final double cardPrice;
  final double fullPrice;
  final bool hasCard;

  const PriceDetailSheet({
    super.key,
    required this.cardPrice,
    required this.fullPrice,
    required this.hasCard,
  });

  static void show(
    BuildContext context, {
    required double cardPrice,
    required double fullPrice,
    required bool hasCard,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (_) => PriceDetailSheet(
        cardPrice: cardPrice,
        fullPrice: fullPrice,
        hasCard: hasCard,
      ),
    );
  }

  String _formatPrice(double price) {
    if (price == price.roundToDouble()) return '${price.toInt()}';
    return price.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>();
    final symbolStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      fontFamily: currency.fontFamily,
    );

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {},
          child: DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.35,
            maxChildSize: 0.55,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(24, 20, 24, 4),
                      child: Text(
                        'Детализация цены',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Text(
                        hasCard ? 'Цены указаны с учётом вашей скидки' : 'Цены указаны с учётом скидки Б·Карты',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0F3),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        _formatPrice(cardPrice),
                                        style: const TextStyle(
                                          fontSize: 24, fontWeight: FontWeight.w800,
                                          color: Color(0xFFDD1847), height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        currency.symbol,
                                        style: symbolStyle.copyWith(color: const Color(0xFFDD1847)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'С Б-Картой',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Color(0xFFDD1847)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        _formatPrice(fullPrice),
                                        style: const TextStyle(
                                          fontSize: 24, fontWeight: FontWeight.w800,
                                          color: Color(0xFF1A1A1A), height: 1.1,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        currency.symbol,
                                        style: symbolStyle.copyWith(color: const Color(0xFF1A1A1A)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Без Б-Карты',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Color(0xFF1A1A1A)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 🔥 Контейнер "Подробнее о Б-Карте" с иконкой и стрелкой
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          QrPopup.show(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              SvgPicture.asset(
                                'assets/images/b-karta-photo.svg',
                                width: 64,
                                height: 64,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Подробнее о Б·Карте',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Color(0xFF999999),
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}