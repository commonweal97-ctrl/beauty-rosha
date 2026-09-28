// lib/widgets/product/cross_sells_sheet.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_logger.dart';
import '../../models/product_detail.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/checkout/checkout_screen.dart';
import '../../screens/main_shell.dart';
import '../../services/api_service.dart';
import '../../core/app_colors.dart';

class CrossSellsSheet extends StatefulWidget {
  final List<ProductCrossSell> crossSells;
  final Function(String slug) onTap;

  const CrossSellsSheet({
    super.key,
    required this.crossSells,
    required this.onTap,
  });

  @override
  State<CrossSellsSheet> createState() => _CrossSellsSheetState();
}

class _CrossSellsSheetState extends State<CrossSellsSheet> {
  static const _logTag = 'CrossSellsSheet';

  late ProductCrossSell _selectedItem;
  final DraggableScrollableController _draggableController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.crossSells.first;
  }

  String _imageUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://xn--80abvyjk6cts.xn--p1ai/$url';
  }

  void _close() {
    final shouldNavigate = _selectedItem.id != widget.crossSells.first.id;
    final slug = _selectedItem.slug;

    Navigator.of(context, rootNavigator: true).pop();

    if (shouldNavigate) {
      Future.delayed(const Duration(milliseconds: 300), () {
        widget.onTap(slug);
      });
    }
  }

  void _buyNow(ProductCrossSell item) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      _close();
      MainShell.push(context, const LoginScreen());
      return;
    }

    final cart = context.read<CartProvider>();
    cart.addItemFull(item.toCartItem(), 1);

    _close();

    Future.delayed(const Duration(milliseconds: 300), () async {
      await cart.syncFromServer();
      cart.toggleAll(false);
      cart.toggleItem(item.id);

      final result = await ApiService.post('/api/orders/initiate', {
        'product_ids': [item.id],
      });

      if (!mounted) return;
      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'buyNow/initiate failed: ${result.errorOrNull?.message}',
        );
        return;
      }

      final data = result.valueOrNull?['data'];
      if (data is! Map) return;

      final orderId = data['order_id'];
      if (orderId is! int) return;

      MainShell.push(context, CheckoutScreen(orderId: orderId));
    });
  }

  void _addToCart(ProductCrossSell item) {
    final cart = context.read<CartProvider>();
    cart.addItemFull(item.toCartItem(), 1);

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} добавлен в корзину'),
        backgroundColor: context.colors.brand,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return DraggableScrollableSheet(
      controller: _draggableController,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return GestureDetector(
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null &&
                details.primaryVelocity! > 500) {
              _close();
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Похожие товары',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      GestureDetector(
                        onTap: _close,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: context.colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 3 / 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: widget.crossSells.length,
                    itemBuilder: (context, index) {
                      final item = widget.crossSells[index];
                      final isSelected = item.id == _selectedItem.id;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedItem = item);
                        },
                        onDoubleTap: () {
                          _close();
                          widget.onTap(item.slug);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(
                                    color: context.colors.brand,
                                    width: 2.5,
                                  )
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: _imageUrl(item.mainImage ?? ''),
                              fit: BoxFit.cover,
                              memCacheWidth: 160,
                              memCacheHeight: 220,
                              placeholder: (_, _) => Container(
                                color: context.colors.surfaceAlt,
                              ),
                              errorWidget: (_, _, _) => Container(
                                color: context.colors.surfaceAlt,
                                child: Icon(
                                  Icons.image,
                                  color: context.colors.border,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _buildFooter(context, bottomPadding),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context, double bottomPadding) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final item = _selectedItem;
        final inStock = item.stock > 0;
        final cartQty = cart.getQuantity(item.id);
        final inCart = cartQty > 0;

        if (!inStock) {
          return Container(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPadding),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              border: Border(
                top: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
              ),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item.cardPrice?.toInt() ?? item.price.toInt()} ₽',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.colors.brand,
                      ),
                    ),
                    Text(
                      '${item.price.toInt()} ₽',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textMuted,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Нет в наличии',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPadding),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
            ),
          ),
          child: inCart
              ? Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.cardPrice?.toInt() ?? item.price.toInt()} ₽',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.colors.brand,
                          ),
                        ),
                        Text(
                          '${item.price.toInt()} ₽',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                    Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (cartQty > 1) {
                                cart.updateQuantity(item.id, cartQty - 1);
                              } else {
                                cart.removeItem(item.id);
                              }
                              setState(() {});
                            },
                            child: Icon(
                              Icons.remove,
                              size: 20,
                              color: context.colors.textSecondary,
                            ),
                          ),
                          SizedBox(width: 16),
                          Text(
                            '$cartQty',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              if (cartQty < item.stock) {
                                cart.addItemFull(item.toCartItem(), 1);
                                setState(() {});
                              }
                            },
                            child: Icon(
                              Icons.add,
                              size: 20,
                              color: cartQty < item.stock
                                  ? context.colors.textSecondary
                                  : context.colors.textDisabled,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [context.colors.brand, context.colors.brandDark],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'В корзине ›',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.cardPrice?.toInt() ?? item.price.toInt()} ₽',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.colors.brand,
                          ),
                        ),
                        Text(
                          '${item.price.toInt()} ₽',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _buyNow(item),
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.textPrimary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Купить сейчас',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _addToCart(item),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [context.colors.brand, context.colors.brandDark],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'В корзину',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}