// lib/screens/checkout/widgets/city_currency_header.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/city_provider.dart';
import '../../../widgets/cart/free_delivery_progress_bar.dart';
import '../../../core/app_colors.dart';

class CityCurrencyHeader extends StatelessWidget {
  final String city;
  final double cartTotal;
  final VoidCallback onCityTap;

  const CityCurrencyHeader({
    super.key,
    required this.city,
    this.cartTotal = 0,
    required this.onCityTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surface,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: GestureDetector(
        onTap: onCityTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                color: context.colors.brand,
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            city.length > 18
                                ? '${city.substring(0, 15)}...'
                                : city,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: context.colors.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Builder(
                      builder: (ctx) {
                        final deliveryInfo = ctx
                            .watch<CityProvider>()
                            .deliveryInfo;
                        final providers = deliveryInfo?.providers ?? const [];
                        const logos = {
                          'yandex': 'YandexLogo.png',
                          'ozon': 'OzonLogo.png',
                          'cdek': 'CDEKLogo.png',
                          'fivepost': '5postlogo.png',
                          'russian_post': 'Pochalogo.png',
                          'russianpost': 'Pochalogo.png',
                        };
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (providers.isNotEmpty) ...[
                              Wrap(
                                spacing: 4,
                                children: providers.map((p) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(5),
                                    child: Image.asset(
                                      'assets/images/${logos[p] ?? 'YandexLogo.png'}',
                                      width: 16,
                                      height: 16,
                                      errorBuilder: (_, _, _) =>
                                          const SizedBox(width: 22, height: 22),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 6),
                            ],
                            const FreeDeliveryProgressBar(),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
