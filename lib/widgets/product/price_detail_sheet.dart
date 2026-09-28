// lib/widgets/product/price_detail_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/currency_provider.dart';
import '../qr_popup.dart';
import '../../core/app_colors.dart';

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
                          color: context.colors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 20, 24, 4),
                      child: Text(
                        'Детализация цены',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 0, 24, 16),
                      child: Text(
                        hasCard ? 'Цены указаны с учётом вашей скидки' : 'Цены указаны с учётом скидки Б·Карты',
                        style: TextStyle(fontSize: 13, color: context.colors.textMuted),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              decoration: BoxDecoration(
                                color: context.colors.brandLight,
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
                                        style: TextStyle(
                                          fontSize: 24, fontWeight: FontWeight.w800,
                                          color: context.colors.brand, height: 1.1,
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        currency.symbol,
                                        style: symbolStyle.copyWith(color: context.colors.brand),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'С Б-Картой',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: context.colors.brand),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              decoration: BoxDecoration(
                                color: context.colors.surfaceAlt,
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
                                        style: TextStyle(
                                          fontSize: 24, fontWeight: FontWeight.w800,
                                          color: context.colors.textPrimary, height: 1.1,
                                        ),
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        currency.symbol,
                                        style: symbolStyle.copyWith(color: context.colors.textPrimary),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Без Б-Карты',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: context.colors.textPrimary),
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
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: context.colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: context.colors.brandLight,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.credit_card,
                                  size: 32,
                                  color: context.colors.brand,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Подробнее о Б·Карте',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: context.colors.textMuted,
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