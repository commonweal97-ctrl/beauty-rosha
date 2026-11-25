// lib/widgets/product/product_variant_buttons.dart
import 'package:flutter/material.dart';

import '../../models/product_detail.dart';

/// Кнопки переключения объёма (как на WB).
/// Показываются только если [variants].length >= 2.
class ProductVariantButtons extends StatelessWidget {
  final List<VariantItem> variants;
  final int currentId;
  final void Function(VariantItem variant) onSelect;

  const ProductVariantButtons({
    super.key,
    required this.variants,
    required this.currentId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (variants.length < 2) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: variants.map((v) {
            final isActive = v.id == currentId;
            final disabled = !v.inStock && !isActive;

            final borderColor = isActive
                ? activeColor
                : (disabled ? Colors.grey.shade300 : Colors.grey.shade400);
            final bgColor = isActive
                ? activeColor.withValues(alpha: 0.08)
                : Colors.transparent;
            final textColor = isActive
                ? activeColor
                : (disabled ? Colors.grey.shade400 : Colors.black87);

            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: (isActive || disabled) ? null : () => onSelect(v),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(color: borderColor, width: isActive ? 2 : 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  v.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Text(
          'Объем товара',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
