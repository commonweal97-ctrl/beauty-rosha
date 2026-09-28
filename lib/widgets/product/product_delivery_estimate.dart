// lib/widgets/product/product_delivery_estimate.dart
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/product_detail.dart';

class ProductDeliveryEstimate extends StatelessWidget {
  final DeliveryEstimate? delivery;

  const ProductDeliveryEstimate({super.key, this.delivery});

  final Map<String, String> _providerLogos = const {
    'yandex': 'assets/images/YandexLogo.png',
    'ozon': 'assets/images/OzonLogo.png',
    'cdek': 'assets/images/CDEKLogo.png',
    'fivepost': 'assets/images/5postlogo.png',
    'russian_post': 'assets/images/Pochalogo.png',
  };

  void _showDeliveryInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 24,
          bottom: 24 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2))),
            Text(delivery?.title ?? '',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.colors.brand), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(delivery?.subtitle ?? '',
              style: TextStyle(fontSize: 16, color: context.colors.textPrimary, height: 1.4), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: context.colors.brandLight, borderRadius: BorderRadius.circular(12)),
              child: RichText(
                text: TextSpan(
                  text: 'Город расчёта: ',
                  style: TextStyle(fontSize: 16, color: context.colors.textMuted),
                  children: [TextSpan(text: delivery?.city ?? 'Не определён',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.brand))],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Дата доставки указана на основании выбранного или автоматически определенного города. Данные являются ориентировочными и зависят от транспортной компании, а также времени оформления заказа.',
              style: TextStyle(fontSize: 14, color: context.colors.textMuted, height: 1.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final providers = delivery?.providers ?? [];
    
    return GestureDetector(
      onTap: () => _showDeliveryInfo(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(delivery?.title ?? 'Загрузка...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.brand)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(delivery?.subtitle ?? '...',
                        style: TextStyle(fontSize: 14, color: context.colors.textMuted)),
                      if (providers.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: providers.map((p) {
                            // 🔥 Безопасная загрузка логотипа
                            final logoAsset = _providerLogos[p];
                            return Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: logoAsset != null
                                    ? Image.asset(logoAsset, width: 18, height: 18,
                                        errorBuilder: (_, _, _) => const SizedBox(width: 18, height: 18))
                                    : const SizedBox(width: 18, height: 18),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: context.colors.textMuted, size: 24),
          ],
        ),
      ),
    );
  }
}