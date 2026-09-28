// lib/widgets/product/product_bottom_bar.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_detail.dart';
import '../../providers/cart_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/waitlist_provider.dart';
import '../../services/haptic_service.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/main_shell.dart';
import '../../core/app_colors.dart';

class ProductBottomBar extends StatefulWidget {
  final ProductDetail product;
  final VoidCallback onBuyNow;

  const ProductBottomBar({
    super.key,
    required this.product,
    required this.onBuyNow,
  });

  @override
  State<ProductBottomBar> createState() => _ProductBottomBarState();
}

class _ProductBottomBarState extends State<ProductBottomBar> {
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final inCart = cart.isInCart(widget.product.id);
    final cartQty = cart.getQuantity(widget.product.id);
    final canAddMore = widget.product.inStock && cartQty < widget.product.stock;

    // Товар в корзине — показываем счётчик
    if (inCart && cartQty > 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 0.8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 20,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: EdgeInsets.all(6),
          child: Row(
            children: [
              // Счётчик количества
              Container(
                decoration: BoxDecoration(
                  color: context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticService.light();
                        if (cartQty > 1) {
                          cart.updateQuantity(widget.product.id, cartQty - 1);
                        } else {
                          cart.removeFromCart(widget.product.id);
                        }
                      },
                      child: Icon(Icons.remove, size: 20, color: context.colors.textSecondary),
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
                      onTap: canAddMore
                          ? () {
                              HapticService.light();
                              cart.addItemFull(widget.product.toCartItem(), 1);
                            }
                          : null,
                      child: Icon(
                        Icons.add,
                        size: 20,
                        color: canAddMore ? context.colors.textSecondary : context.colors.textDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Кнопка "В корзине"
              Expanded(
                child: GestureDetector(
                  onTap: () {},
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 2),
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
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Товар не в корзине
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            if (widget.product.inStock) ...[
              // Кнопка "Купить сейчас"
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticService.heavy();
                    widget.onBuyNow();
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 2),
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
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Кнопка "В корзину"
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticService.medium();
                    cart.addItemFull(widget.product.toCartItem(), 1);
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 2),
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
                          'Добавить в корзину',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ] else
              // Кнопка "В лист ожидания" — красный градиент как у корзины
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticService.medium();
                    final auth = context.read<AuthProvider>();
                    if (!auth.isLoggedIn) {
                      MainShell.push(context, const LoginScreen());
                      return;
                    }
                    context.read<WaitlistProvider>().toggle(widget.product.id);
                  },
                  child: Consumer<WaitlistProvider>(
                    builder: (context, waitlist, _) {
                      final inWaitlist = waitlist.isInWaitlist(widget.product.id);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 2),
                        decoration: BoxDecoration(
                          gradient: inWaitlist
                              ? null
                              : LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [context.colors.brand, context.colors.brandDark],
                                ),
                          color: inWaitlist ? context.colors.success.withValues(alpha: 0.15) : null,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: inWaitlist
                              ? null
                              : [
                                  BoxShadow(
                                    color: context.colors.brand.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              inWaitlist ? 'В листе ожидания ✓' : 'В лист ожидания',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: inWaitlist ? context.colors.success : Colors.white,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}