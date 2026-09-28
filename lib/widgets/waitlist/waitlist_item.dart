// lib/widgets/waitlist/waitlist_item.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/currency_provider.dart';
import '../../models/product_detail.dart';
import '../../screens/main_shell.dart';
import '../../screens/product/product_detail_screen.dart';
import '../../services/haptic_service.dart';
import '../product/cross_sells_sheet.dart';
import '../image_loader.dart';
import '../../core/app_colors.dart';

class WaitlistItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final List<ProductCrossSell> crossSells;
  final bool isSelected;
  final VoidCallback onToggleSelect;
  final VoidCallback onRemove;
  final VoidCallback onShare;

  const WaitlistItem({
    super.key,
    required this.item,
    required this.crossSells,
    this.isSelected = false,
    required this.onToggleSelect,
    required this.onRemove,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final pid = item['id'] as int;
    final name = item['name'] as String? ?? '';
    final brand = item['brand'] as String? ?? '';
    final price = (item['price'] ?? 0).toDouble();
    final salePrice = item['sale_price']?.toDouble();
    final cardPrice = item['card_price']?.toDouble();
    final mainImage = item['main_image'] as String?;
    final slug = item['slug'] as String? ?? '';
    final stock = item['stock'] as int? ?? 0;
    final inStock = stock > 0;
    final rating = (item['average_rating'] ?? 0).toDouble();
    final reviewCount = item['review_count'] as int? ?? 0;
    final attributes = _extractAttributes();

    final currency = context.watch<CurrencyProvider>();
    final auth = context.watch<AuthProvider>();
    final hasActiveCard = auth.isLoggedIn;
    final cart = context.watch<CartProvider>();
    final inCartQty = cart.getQuantity(pid);

    final symbolStyle = TextStyle(fontSize: currency.symbolFontSize, fontWeight: FontWeight.w700, fontFamily: currency.fontFamily);

    double displayPrice;
    double? oldPrice;
    bool oldPriceStrikethrough;

    if (salePrice != null && salePrice > 0 && salePrice < price) {
      displayPrice = salePrice;
      oldPrice = price;
      oldPriceStrikethrough = true;
    } else if (hasActiveCard && cardPrice != null && cardPrice < price) {
      displayPrice = cardPrice;
      oldPrice = price;
      oldPriceStrikethrough = true;
    } else if (hasActiveCard) {
      displayPrice = cardPrice ?? price;
      oldPrice = cardPrice != null && cardPrice < price ? price : null;
      oldPriceStrikethrough = oldPrice != null;
    } else {
      displayPrice = cardPrice != null && cardPrice < price ? cardPrice : price;
      oldPrice = cardPrice != null && cardPrice < price ? price : null;
      oldPriceStrikethrough = false;
    }

    void addToCart() {
      if (!inStock) return;
      if (inCartQty >= stock) return;
      HapticService.light();
      cart.addItemFull({
        'product_id': pid,
        'quantity': 1,
        'name': name,
        'slug': slug,
        'price': price,
        'sale_price': salePrice,
        'card_price': cardPrice ?? price,
        'main_image': mainImage ?? '',
        'stock': stock,
        'brand': brand,
        'category_id': null,
        'unavailable': false,
      }, 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name добавлен в корзину'), backgroundColor: context.colors.brand, behavior: SnackBarBehavior.floating, duration: Duration(seconds: 2)),
      );
    }

    void showActionsSheet() {
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  onShare();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    SvgPicture.asset(
                      'assets/icons/share.svg',
                      width: 22,
                      height: 22,
                      colorFilter: ColorFilter.mode(context.colors.textPrimary, BlendMode.srcIn),
                    ),
                    SizedBox(width: 12),
                    Text('Поделиться', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.colors.textPrimary)),
                  ]),
                ),
              ),
              Divider(height: 1, color: context.colors.border),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  onRemove();
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(Icons.delete_outline, size: 22, color: context.colors.brand),
                    SizedBox(width: 12),
                    Text('Убрать из листа ожидания', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.colors.brand)),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.colors.border.withValues(alpha: 0.5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => MainShell.push(context, ProductDetailScreen(slug: slug)),
                  child: Stack(
                    children: [
                      ImageLoader(
                        imageUrl: mainImage,
                        width: 96,
                        height: 128,
                        borderRadius: 12,
                      ),
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (_) => onToggleSelect(),
                            activeColor: context.colors.brand,
                            checkColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (salePrice != null && salePrice > 0 && salePrice < price)
                        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                          Text('% ${_formatPrice(displayPrice)} ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.error)),
                          Text(currency.symbol, style: symbolStyle.copyWith(color: context.colors.error, fontSize: 18)),
                          SizedBox(width: 6),
                          Text('${_formatPrice(price)} ', style: TextStyle(fontSize: 14, color: context.colors.textMuted, decoration: TextDecoration.lineThrough)),
                          Text(currency.symbol, style: symbolStyle.copyWith(fontSize: 14, color: context.colors.textMuted, decoration: TextDecoration.lineThrough)),
                        ])
                      else
                        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                          Transform.translate(offset: Offset(0, 2), child: Icon(Icons.credit_card_rounded, size: 22, color: context.colors.brand)),
                          SizedBox(width: 4),
                          Text('${_formatPrice(displayPrice)} ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.brand)),
                          Text(currency.symbol, style: symbolStyle.copyWith(color: context.colors.brand, fontSize: 18)),
                          if (oldPrice != null) ...[
                            SizedBox(width: 6),
                            Text('${_formatPrice(oldPrice)} ', style: TextStyle(fontSize: 14, color: context.colors.textMuted, decoration: oldPriceStrikethrough ? TextDecoration.lineThrough : null)),
                            Text(currency.symbol, style: symbolStyle.copyWith(fontSize: 14, color: context.colors.textMuted, decoration: oldPriceStrikethrough ? TextDecoration.lineThrough : null)),
                          ],
                        ]),
                      SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: brand.isNotEmpty
                              ? [
                                  TextSpan(text: '$brand ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                                  TextSpan(text: '/ ', style: TextStyle(fontSize: 13, color: context.colors.textPrimary)),
                                  TextSpan(text: name, style: TextStyle(fontSize: 13, color: context.colors.textPrimary)),
                                ]
                              : [
                                  TextSpan(text: name, style: TextStyle(fontSize: 13, color: context.colors.textPrimary)),
                                ],
                        ),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      ),
                      if (attributes.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(attributes.join(' · '), style: TextStyle(fontSize: 11, color: context.colors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                      if (reviewCount > 0) ...[
                        SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.star, size: 14, color: Color(0xFFFFCC00)),
                          SizedBox(width: 3),
                          Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                          SizedBox(width: 4),
                          Text('• $reviewCount', style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                        ]),
                      ],
                      SizedBox(height: 8),
                      if (inStock)
                        GestureDetector(
                          onTap: inCartQty < stock ? addToCart : null,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [context.colors.brand, context.colors.brandDark]),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: context.colors.brand.withValues(alpha: 0.3), blurRadius: 6, offset: Offset(0, 2))],
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(inCartQty > 0 ? 'В корзине ($inCartQty)' : 'В корзину', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        )
                      else
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(color: context.colors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
                          child: Text('Нет в наличии', style: TextStyle(color: context.colors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: showActionsSheet,
                  child: Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.more_vert, color: context.colors.textMuted, size: 20),
                  ),
                ),
              ],
            ),
          ),
          if (crossSells.isNotEmpty)
            _buildCrossSellsBlock(context),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCrossSellsBlock(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth - 24 - 12 - 5 * 6) / 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              useRootNavigator: true,
              builder: (ctx) => CrossSellsSheet(
                crossSells: crossSells,
                onTap: (slug) => MainShell.push(context, ProductDetailScreen(slug: slug)),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Похожие товары', style: TextStyle(fontSize: 13, color: context.colors.textMuted)),
                Text('Все ›', style: TextStyle(fontSize: 13, color: context.colors.textMuted)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: itemWidth * 4 / 3,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: crossSells.length.clamp(0, 6),
            itemBuilder: (context, index) {
              final item = crossSells[index];
              return Padding(
                padding: EdgeInsets.only(right: index < 5 ? 6 : 0),
                child: GestureDetector(
                  onTap: () => MainShell.push(context, ProductDetailScreen(slug: item.slug)),
                  child: ImageLoader(
                    imageUrl: item.mainImage,
                    width: itemWidth,
                    height: itemWidth * 4 / 3,
                    borderRadius: 8,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<String> _extractAttributes() {
    final attrs = <String>[];
    final attributes = item['attributes'];
    if (attributes is Map) {
      for (final value in attributes.values.take(3)) {
        if (value != null && value.toString().isNotEmpty) {
          attrs.add(value.toString());
        }
      }
    }
    return attrs;
  }

  String _formatPrice(double price) {
    if (price == price.roundToDouble()) return '${price.toInt()}';
    return price.toStringAsFixed(2);
  }
}