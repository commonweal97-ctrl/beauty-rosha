// lib/screens/checkout/widgets/order_items_block.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/image_cache.dart';
import 'package:provider/provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../services/cdn_service.dart';
import '../../../core/app_colors.dart';

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
    
    if (items.isEmpty) return SizedBox();
    
    return Container(
      color: context.colors.surface,
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ваш заказ',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
          ),
          const SizedBox(height: 12),
          
          SizedBox(
            height: 130,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => SizedBox(width: 8),
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
                          color: context.colors.surfaceAlt,
                          child: image.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: cdnUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: imageCacheSize(context, size: 80),
                                  memCacheHeight: imageCacheSize(context, size: 110),
                                  fadeInDuration: Duration.zero,
                                  placeholder: (_, _) => Container(
                                    color: context.colors.surfaceAlt,
                                    child: Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: context.colors.brand,
                                        ),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (_, _, _) => CachedNetworkImage(
                                    imageUrl: fallbackUrl,
                                    fit: BoxFit.cover,
                                    memCacheWidth: imageCacheSize(context, size: 80),
                                    memCacheHeight: imageCacheSize(context, size: 110),
                                    fadeInDuration: Duration.zero,
                                    placeholder: (_, _) => Container(
                                      color: context.colors.surfaceAlt,
                                      child: Center(
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 1.5,
                                            color: context.colors.brand,
                                          ),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (_, _, _) => Container(
                                      color: context.colors.surfaceAlt,
                                      child: Icon(Icons.image, color: context.colors.textDisabled, size: 28),
                                    ),
                                  ),
                                )
                              : Icon(Icons.image, color: context.colors.textDisabled),
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '×$qty',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.textMuted),
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