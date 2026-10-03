// lib/widgets/product/product_cross_sells.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_colors.dart';
import '../../models/product_detail.dart';
import 'cross_sells_sheet.dart';

class ProductCrossSells extends StatelessWidget {
  final List<ProductCrossSell> crossSells;
  final Function(String slug) onTap;

  const ProductCrossSells({
    super.key,
    required this.crossSells,
    required this.onTap,
  });

  String _imageUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://xn--80abvyjk6cts.xn--p1ai/$url';
  }

  @override
  Widget build(BuildContext context) {
    final itemWidth = (MediaQuery.of(context).size.width - 32 - 30) / 6;
    final showScroll = crossSells.length > 6;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Изображения
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
            child: showScroll
                ? SizedBox(
                    height: itemWidth * 4 / 3,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: crossSells.length,
                      itemBuilder: (context, index) {
                        final item = crossSells[index];
                        return Padding(
                          padding: EdgeInsets.only(right: index < crossSells.length - 1 ? 6 : 0),
                          child: GestureDetector(
                            onTap: () => onTap(item.slug),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: itemWidth,
                                child: AspectRatio(
                                  aspectRatio: 3 / 4,
                                  child: CachedNetworkImage(
                                    imageUrl: _imageUrl(
                                      (item.mainImage ?? '')
                                          .replaceAll('main.webp', 'main_card.webp')
                                          .replaceAll('main_detail.webp', 'main_card.webp'),
                                    ),
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => Container(color: context.colors.surfaceAlt),
                                    errorWidget: (_, _, _) => Container(
                                      color: context.colors.surfaceAlt,
                                      child: Icon(Icons.image, color: context.colors.textDisabled),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: crossSells.take(6).toList().asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final isLast = index == crossSells.length - 1;

                        return Padding(
                          padding: EdgeInsets.only(right: isLast ? 0 : 6),
                          child: GestureDetector(
                            onTap: () => onTap(item.slug),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: itemWidth,
                                child: AspectRatio(
                                  aspectRatio: 3 / 4,
                                  child: CachedNetworkImage(
                                    imageUrl: _imageUrl(
                                      (item.mainImage ?? '')
                                          .replaceAll('main.webp', 'main_card.webp')
                                          .replaceAll('main_detail.webp', 'main_card.webp'),
                                    ),
                                    fit: BoxFit.cover,
                                    placeholder: (_, _) => Container(color: context.colors.surfaceAlt),
                                    errorWidget: (_, _, _) => Container(
                                      color: context.colors.surfaceAlt,
                                      child: Icon(Icons.image, color: context.colors.textDisabled),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),

          // Подпись: слева количество, справа "Все X"
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${crossSells.length} похожих товаров',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textMuted,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      useRootNavigator: true,
                      builder: (ctx) => CrossSellsSheet(
                        crossSells: crossSells,
                        onTap: (slug) {
                          onTap(slug);
                        },
                      ),
                    );
                  },
                  child: Text(
                    'Все ${crossSells.length} ›',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}