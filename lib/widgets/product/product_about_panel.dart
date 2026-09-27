// lib/widgets/product/product_about_panel.dart
import 'package:flutter/material.dart';
import '../../models/product_detail.dart';

class ProductAboutPanel extends StatelessWidget {
  final ProductDetail product;

  const ProductAboutPanel({
    super.key,
    required this.product,
  });

  static const _labels = {
    'Цвет': 'Цвет', 'Объем': 'Объем', 'Страна производства': 'Страна',
    'Бренд': 'Бренд', 'Состав': 'Состав', 'Гарантия': 'Гарантия',
    'cvet': 'Цвет', 'obem': 'Объем', 'strana': 'Страна',
    'sostav': 'Состав', 'garantia': 'Гарантия',
  };

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Полоска
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Заголовок
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'О товаре',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.close, size: 18, color: Color(0xFF999999)),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Содержимое
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // Описание
                    if (product.description != null && product.description!.isNotEmpty) ...[
                      const Text(
                        'Описание',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.description!.replaceAll(RegExp(r'<[^>]+>'), ''),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF555555),
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Характеристики
                    const Text(
                      'Характеристики',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (product.attributes != null)
                      ...product.attributes!.entries
                          .where((e) => e.value != null && e.value.toString().isNotEmpty)
                          .map((entry) => _buildSpecRow(
                                _labels[entry.key] ?? entry.key,
                                entry.value.toString(),
                              )),
                    
                    if (product.sku != null)
                      _buildSpecRow('Артикул', product.sku!),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF888888),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}