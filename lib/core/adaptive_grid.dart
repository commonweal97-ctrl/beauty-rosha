// lib/core/adaptive_grid.dart
//
// Адаптивные гриды для карточек товаров.
//
// Высота карточки = ширина_картинки × imageAspect + contentHeight
// imageAspect = 1350/1000 = 1.35 (соответствует product_card.dart)
// contentHeight = высота блока под картинкой (~90px)

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
    this.contentHeight = 90,
    this.imageAspect = 1.35,
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

/// Хелпер для расчёта aspectRatio
double adaptiveProductAspectRatio(BuildContext context, {
  int crossAxisCount = 2,
  double crossAxisSpacing = 1,
  double contentHeight = 90,
  double imageAspect = 1.35,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
  final cardWidth = (screenWidth - totalSpacing) / crossAxisCount;
  final cardHeight = cardWidth * imageAspect + contentHeight;
  return cardWidth / cardHeight;
}
