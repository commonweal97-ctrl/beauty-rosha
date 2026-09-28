// lib/screens/checkout/widgets/city_currency_header.dart
import 'package:flutter/material.dart';
import '../../../widgets/cart/free_delivery_progress_bar.dart';
import '../../../core/app_colors.dart';

class CityCurrencyHeader extends StatelessWidget {
  final String city;
  final VoidCallback onCityTap;

  const CityCurrencyHeader({
    super.key,
    required this.city,
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
              Icon(Icons.location_on_outlined, 
                color: context.colors.brand, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            city.length > 18 ? '${city.substring(0, 15)}...' : city,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right, 
                          color: context.colors.textMuted, size: 20),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const FreeDeliveryProgressBar(),
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