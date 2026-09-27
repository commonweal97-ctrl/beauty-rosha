// lib/widgets/product/product_delivery_estimate.dart
import 'package:flutter/material.dart';
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 24,
          bottom: 24 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Text(delivery?.title ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFDD1847)), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(delivery?.subtitle ?? '',
              style: const TextStyle(fontSize: 16, color: Color(0xFF1A1A1A), height: 1.4), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFFFDF2F5), borderRadius: BorderRadius.circular(12)),
              child: RichText(
                text: TextSpan(
                  text: 'Город расчёта: ',
                  style: const TextStyle(fontSize: 16, color: Color(0xFF999999)),
                  children: [TextSpan(text: delivery?.city ?? 'Не определён',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFDD1847)))],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Дата доставки указана на основании выбранного или автоматически определенного города. Данные являются ориентировочными и зависят от транспортной компании, а также времени оформления заказа.',
              style: TextStyle(fontSize: 14, color: Color(0xFF999999), height: 1.5)),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(delivery?.title ?? 'Загрузка...',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFDD1847))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(delivery?.subtitle ?? '...',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF8F8F9A))),
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
            const Icon(Icons.chevron_right, color: Color(0xFF999999), size: 24),
          ],
        ),
      ),
    );
  }
}