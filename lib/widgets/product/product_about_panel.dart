// lib/widgets/product/product_about_panel.dart
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
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
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Полоска
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Заголовок
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'О товаре',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.close, size: 18, color: context.colors.textMuted),
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
                      Text(
                        'Описание',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.description!.replaceAll(RegExp(r'<[^>]+>'), ''),
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    
                    // Характеристики
                    Text(
                      'Характеристики',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (product.attributes != null)
                      ...product.attributes!.entries
                          .where((e) => e.value != null && e.value.toString().isNotEmpty)
                          .map((entry) => _buildSpecRow(
                                context,
                                _labels[entry.key] ?? entry.key,
                                entry.value.toString(),
                              )),
                    
                    if (product.sku != null)
                      _buildSpecRow(context, 'Артикул', product.sku!),
                    
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

  Widget _buildSpecRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: context.colors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.colors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}