// lib/widgets/product/product_attributes.dart
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class ProductAttributes extends StatelessWidget {
  final Map<String, dynamic> attributes;
  final String? sku;
  final VoidCallback? onShowAll;

  const ProductAttributes({
    super.key,
    required this.attributes,
    this.sku,
    this.onShowAll,
  });

  // Маппинг ключей атрибутов на русские названия
  static const _labels = {
    'Цвет': 'Цвет',
    'Объем': 'Объем',
    'Страна производства': 'Страна',
    'Бренд': 'Бренд',
    'Состав': 'Состав',
    'Гарантия': 'Гарантия',
    'cvet': 'Цвет',
    'obem': 'Объем',
    'strana': 'Страна',
    'sostav': 'Состав',
    'garantia': 'Гарантия',
    'kollektsiya': 'Коллекция',
    'effekt': 'Эффект',
    'tip': 'Тип',
    'obem-ml': 'Объем',
    'ves': 'Вес',
    'tsvet': 'Цвет',
    'color': 'Цвет',
    'material': 'Материал',
    'pokritie': 'Покрытие',
    'forma': 'Форма',
    'dlina': 'Длина',
    'shirina': 'Ширина',
    'visota': 'Высота',
    'primenenie': 'Применение',
    'naznachenie': 'Назначение',
    'osobennosti': 'Особенности',
    'komplektatsiya': 'Комплектация',
    'srok-godnosti': 'Срок годности',
    'proizvoditel': 'Производитель',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ...attributes.entries
              .where((e) => e.value != null && e.value.toString().isNotEmpty && e.key != 'Бренд')
              .take(5)
              .map((entry) => _buildAttrRow(context, entry.key, entry.value.toString())),
          
          if (sku != null)
            _buildAttrRow(context, 'Артикул', sku!),
          
          const SizedBox(height: 12),
          
          // Кнопка показать все
          if (onShowAll != null)
            GestureDetector(
              onTap: onShowAll,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Характеристики и описание',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttrRow(BuildContext context, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              _labels[key] ?? key,
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
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