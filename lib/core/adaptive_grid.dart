// lib/core/adaptive_grid.dart
//
// Адаптивные гриды для карточек товаров.
//
// Проблема: childAspectRatio — жёсткая константа, ломается на узких экранах.
//
// Решение: фиксируем высоту контента под картинкой, ширина картинки
// зависит от ширины экрана → высота автоматически подстраивается.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Адаптивный делегат для SliverGrid с ProductCard.
///
/// [contentHeight] — фиксированная высота контента под картинкой
/// (название, бренд, цена, отступы). По умолчанию 190pt.
///
/// Картинка = 4:3 от ширины карточки.
/// Итого высота карточки = ширина × 0.75 + contentHeight.
class AdaptiveProductGridDelegate extends SliverGridDelegate {
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double contentHeight;
  final double imageAspect;

  const AdaptiveProductGridDelegate({
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 1,
    this.mainAxisSpacing = 1,
    this.contentHeight = 190,
    this.imageAspect = 0.75, // 4:3 (ширина/высота = 4/3 → высота = 0.75 * ширина)
  });

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final totalCrossSpacing = crossAxisSpacing * (crossAxisCount - 1);
    final cardWidth =
        (constraints.crossAxisExtent - totalCrossSpacing) / crossAxisCount;
    final imageHeight = cardWidth * imageAspect;
    final cardHeight = imageHeight + contentHeight;

    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: cardHeight + mainAxisSpacing,
      crossAxisStride: cardWidth + crossAxisSpacing,
      childMainAxisExtent: cardHeight,
      childCrossAxisExtent: cardWidth,
      reverseCrossAxis:
          axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(AdaptiveProductGridDelegate oldDelegate) {
    return oldDelegate.crossAxisCount != crossAxisCount ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing ||
        oldDelegate.mainAxisSpacing != mainAxisSpacing ||
        oldDelegate.contentHeight != contentHeight ||
        oldDelegate.imageAspect != imageAspect;
  }
}

/// Хелпер: рассчитать aspectRatio если нужен "сырой" childAspectRatio.
double adaptiveProductAspectRatio(BuildContext context, {
  int crossAxisCount = 2,
  double crossAxisSpacing = 1,
  double contentHeight = 190,
  double imageAspect = 0.75,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
  final cardWidth = (screenWidth - totalSpacing) / crossAxisCount;
  final cardHeight = cardWidth * imageAspect + contentHeight;
  return cardWidth / cardHeight;
}
