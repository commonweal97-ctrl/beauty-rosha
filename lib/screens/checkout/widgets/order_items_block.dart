// lib/screens/checkout/widgets/order_items_block.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/cdn_service.dart';

class OrderItemsBlock extends StatelessWidget {
  const OrderItemsBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    
    // ✅ Только отмеченные товары
    final items = cart.details.entries
        .where((e) => cart.checkedIds.contains(e.key))
        .map((e) => e.value)
        .toList();
    
    if (items.isEmpty) return const SizedBox();
    
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ваш заказ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
          ),
          const SizedBox(height: 12),
          
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final item = items[i];
                final image = item['main_image'] as String? ?? '';
                final qty = item['quantity'] as int;
                final cdnUrl = CdnService.imageUrl(image);
                final fallbackUrl = CdnService.imageUrlFallback(image);
                
                return GestureDetector(
                  onTap: () {},
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 80,
                          height: 106,
                          color: const Color(0xFFF6F6F9),
                          child: image.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: cdnUrl,
                                  fit: BoxFit.cover,
                                  fadeInDuration: Duration.zero,
                                  placeholder: (_, _) => Container(
                                    color: const Color(0xFFF6F6F9),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: Color(0xFFDD1847),
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, _, _) => CachedNetworkImage(
                                    imageUrl: fallbackUrl,
                                    fit: BoxFit.cover,
                                    fadeInDuration: Duration.zero,
                                    placeholder: (_, _) => Container(
                                      color: const Color(0xFFF6F6F9),
                                      child: const Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: Color(0xFFDD1847),
                                          ),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, _, _) => Container(
                                      color: const Color(0xFFF6F6F9),
                                      child: const Icon(Icons.image, color: Color(0xFFCCCCCC), size: 28),
                                    ),
                                  ),
                                )
                              : const Icon(Icons.image, color: Color(0xFFCCCCCC)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '×$qty',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8F8F9A)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}