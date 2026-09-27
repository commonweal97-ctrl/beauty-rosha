// lib/screens/checkout/widgets/city_currency_header.dart
import 'package:flutter/material.dart';
import '../../../widgets/cart/free_delivery_progress_bar.dart';

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
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: GestureDetector(
        onTap: onCityTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, 
                color: Color(0xFFDD1847), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            city.length > 18 ? '${city.substring(0, 15)}...' : city,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right, 
                          color: Color(0xFF8F8F9A), size: 20),
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