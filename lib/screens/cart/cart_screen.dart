// lib/screens/cart/cart_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_colors.dart';
import '../../core/app_logger.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/city_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/api_service.dart';
import '../../services/haptic_service.dart';
import '../../widgets/cart/card_banner.dart';
import '../../widgets/cart/first_order_discount_banner.dart';
import '../../widgets/cart/free_delivery_progress_bar.dart';
import '../../widgets/city_picker.dart';
import '../../widgets/image_loader.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../auth/login_screen.dart';
import '../catalog/home_screen.dart';
import '../checkout/checkout_screen.dart';
import '../main_shell.dart';
import '../product/product_detail_screen.dart';
import '../../widgets/common/gradient_button.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const _logTag = 'CartScreen';

  final Map<int, double> _swipeOffsets = {};
  final Set<int> _removingItems = {};

  final ScrollController _mainScrollController = ScrollController();

  static const Map<String, String> _providerLogos = {
    'yandex': 'YandexLogo.png',
    'ozon': 'OzonLogo.png',
    'cdek': 'CDEKLogo.png',
    'fivepost': '5postlogo.png',
    'russian_post': 'Pochalogo.png',
  };

    @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen('cart');
    final cart = context.read<CartProvider>();
    cart.addListener(_onCartChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      /// 🔥 ШАГ 4: если корзина загружена только частично (`loadCartCount`),
      /// догружаем promotions и loyalty/status при первом открытии вкладки.
      final cartProvider = context.read<CartProvider>();
      if (!cartProvider.isFullyLoaded && cartProvider.items.isNotEmpty) {
        cartProvider.loadFullCart();
      }

      context.read<CityProvider>().loadDeliveryInfo();
    });
  }

  @override
  void dispose() {
    try {
      context.read<CartProvider>().removeListener(_onCartChanged);
    } catch (_) {}
    _mainScrollController.dispose();
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  Widget _buildPriceWidget(
    double price, {
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    TextDecoration? decoration,
  }) {
    final currency = context.read<CurrencyProvider>();
    final formatted = price <= 0
        ? '0'
        : (price == price.roundToDouble()
            ? '${price.toInt()}'
            : price.toStringAsFixed(2));
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$formatted ',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              decoration: decoration,
            ),
          ),
          TextSpan(
            text: currency.symbol,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
              fontFamily: currency.fontFamily,
              decoration: decoration,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPricePlain(double price) {
    if (price <= 0) return '0';
    if (price == price.roundToDouble()) return '${price.toInt()}';
    return price.toStringAsFixed(2);
  }

  String _pluralItems(int n) {
    final m10 = n % 10;
    final m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'товар';
    if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) {
      return 'товара';
    }
    return 'товаров';
  }

  String _pluralRemoveItems(int n) {
    final m10 = n % 10;
    final m100 = n % 100;
    if (m10 == 1 && m100 != 11) return '$n товар будет удалён';
    if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) {
      return '$n товара будет удалено';
    }
    return '$n товаров будет удалено';
  }

  void _shareCart() {
    final box = context.findRenderObject() as RenderBox?;
    final rect =
        box != null ? box.localToGlobal(Offset.zero) & box.size : null;
    final cart = context.read<CartProvider>();
    final items = cart.details.values.toList();
    final selectedItems =
        items.where((i) => cart.isItemChecked(i['product_id'])).toList();
    final currency = context.read<CurrencyProvider>();
    final text = selectedItems.isNotEmpty
        ? 'Моя корзина в Б•Роща:\n'
            '${selectedItems.map((i) => '${i['name']} — '
                '${_formatPricePlain((i['card_price'] ?? i['price']).toDouble())} '
                '${currency.symbol}').join('\n')}'
        : 'Моя корзина в Б•Роща — '
            'https://xn--80abvyjk6cts.xn--p1ai/cart';
    SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: rect));
  }

  Future<void> _removeSelected() async {
    final cart = context.read<CartProvider>();
    if (cart.checkedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Удалить выбранные?'),
        content: Text(_pluralRemoveItems(cart.checkedIds.length)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Отмена',
              style: TextStyle(color: context.colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Удалить',
              style: TextStyle(
                color: context.colors.brand,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final toRemove = cart.checkedIds.toList();
      await cart.removeMultiple(toRemove);
    }
  }

  void _closeAllSwipes() {
    for (final key in _swipeOffsets.keys.toList()) {
      _swipeOffsets[key] = 0;
    }
    setState(() {});
  }

  Future<void> _proceedToCheckout(CartProvider cart) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      MainShell.push(context, const LoginScreen());
      return;
    }
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => Center(
        child: CircularProgressIndicator(color: context.colors.brand),
      ),
    );

    final result = await ApiService.post(
      '/api/orders/initiate',
      {'product_ids': cart.checkedIds.toList()},
    );

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'proceedToCheckout failed: ${result.errorOrNull?.message}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.errorOrNull?.userMessage ?? 'Ошибка создания заказа',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка создания заказа'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final orderId = data['order_id'];
    if (orderId is! int) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка создания заказа'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    MainShell.push(context, CheckoutScreen(orderId: orderId));
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (!cart.loaded) {
      return Center(
        child: CircularProgressIndicator(color: context.colors.brand),
      );
    }
    if (cart.items.isEmpty) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness:
              isDark ? Brightness.dark : Brightness.light,
        ),
        child: Material(
          color: context.colors.background,
          child: _buildEmpty(statusBarHeight),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            isDark ? Brightness.dark : Brightness.light,
      ),
      child: Material(
        color: context.colors.background,
        child: _buildCartContent(cart, statusBarHeight, bottomPadding),
      ),
    );
  }

  Widget _buildEmpty(double statusBarHeight) {
    final city = context.watch<CityProvider>().city;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(0, statusBarHeight + 12, 0, 0),
          child: _buildCityBlock(city),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🛒', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text(
                  'В корзине пока пусто',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Загляните на главную — собрали там товары,\n'
                  'которые могут вам понравиться',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: context.colors.textMuted,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () =>
                      MainShell.push(context, const HomeScreen()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.brand,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'На главную',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCityBlock(String city) {
    final deliveryInfo = context.watch<CityProvider>().deliveryInfo;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GestureDetector(
        onTap: _openCityPicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                color: context.colors.brand,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            city.length > 18
                                ? '${city.substring(0, 15)}...'
                                : city,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right,
                          color: context.colors.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (deliveryInfo != null) ...[
                      Text(
                        deliveryInfo.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.colors.brand,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            deliveryInfo.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textMuted,
                            ),
                          ),
                          if (deliveryInfo.providers.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            ...deliveryInfo.providers.map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.asset(
                                    'assets/images/'
                                    '${_providerLogos[p] ?? 'YandexLogo.png'}',
                                    width: 16,
                                    height: 16,
                                    errorBuilder: (_, _, _) => const SizedBox(
                                      width: 16,
                                      height: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    const FreeDeliveryProgressBar(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openCityPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => CityPicker(onSelect: (city, country) {}),
    );
  }

  Widget _buildCartContent(
    CartProvider cart,
    double statusBarHeight,
    double bottomPadding,
  ) {
    final items = cart.details.entries.map((e) => e.value).toList();
    final city = context.watch<CityProvider>().city;

    const headerHeight = 185.0;

    return Stack(
      children: [
        Column(
          children: [
            SizedBox(height: statusBarHeight + headerHeight),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  final cart = context.read<CartProvider>();
                  ApiService.invalidateCache(prefix: '/api/cart/');
                  ApiService.invalidateCache(prefix: '/api/promotions/');
                  await cart.loadFullCart();
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: _mainScrollController,
                  padding: const EdgeInsets.only(
                    top: 52,
                    bottom: 210,
                  ),
                  child: Column(
                    children: [
                      // Баннер Б-карты (может вернуть SizedBox.shrink)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: CardBanner(),
                      ),
                      const SizedBox(height: 8),
                      ...items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final pid = item['product_id'] as int;
                        final isLast = index == items.length - 1;
                        return Column(
                          key: ValueKey('cart_item_$pid'),
                          children: [
                            _buildCartItem(item, cart),
                            if (!isLast)
                              Divider(
                                height: 1,
                                thickness: 1,
                                indent: 16,
                                endIndent: 16,
                                color: context.colors.border,
                              ),
                          ],
                        );
                      }),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(0, statusBarHeight + 12, 0, 12),
            child: Column(
              children: [
                _buildCityBlock(city),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => cart.toggleAll(!cart.allChecked),
                        child: Container(
                          height: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(19),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: Checkbox(
                                  value: cart.allChecked,
                                  onChanged: (v) =>
                                      cart.toggleAll(v ?? false),
                                  activeColor: context.colors.brand,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Все',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      _buildIconButton(
                        icon: Icons.favorite_border,
                        onTap: () {
                          if (cart.checkedIds.isEmpty) return;
                          final auth = context.read<AuthProvider>();
                          if (!auth.isLoggedIn) {
                            MainShell.push(
                              context,
                              const LoginScreen(),
                            );
                            return;
                          }
                          final ids = cart.checkedIds.toList();
                          final wishlist =
                              context.read<WishlistProvider>();
                          ApiService.post(
                            '/api/wishlist/add-batch',
                            {'product_ids': ids},
                          ).then((result) {
                            if (result.isFailure) {
                              AppLogger.warning(
                                _logTag,
                                'wishlist add-batch failed: '
                                '${result.errorOrNull?.message}',
                              );
                              return;
                            }
                            for (final id in ids) {
                              wishlist.setInWishlist(id, true);
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 4),
                      _buildShareButton(onTap: _shareCart),
                      const SizedBox(width: 4),
                      _buildIconButton(
                        icon: Icons.delete_outline,
                        onTap: _removeSelected,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: bottomPadding > 0 ? bottomPadding + 5 : 16,
          left: 24,
          right: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8, right: 4),
                  child: ScrollToTopButton(
                    scrollController: _mainScrollController,
                    threshold: 300,
                    size: 40,
                    backgroundColor:
                        context.colors.brand.withValues(alpha: 0.9),
                    iconColor: Colors.white,
                    appearDelay: const Duration(milliseconds: 200),
                    animationDuration:
                        const Duration(milliseconds: 200),
                  ),
                ),
              ),
              const FirstOrderDiscountBanner(),
              const SizedBox(height: 8),
              _buildCheckoutButtonContent(cart),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCheckoutButtonContent(CartProvider cart) {
    final checkedCount = cart.checkedIds.fold(
      0,
      (sum, id) => sum + (cart.items[id] ?? 0),
    );

    return GradientButton(
      text: 'К оформлению $checkedCount ${_pluralItems(checkedCount)}',
      onPressed: cart.checkedIds.isNotEmpty
          ? () {
              HapticService.heavy();
              _proceedToCheckout(cart);
            }
          : null,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      trailing: _buildPriceWidget(
        cart.finalTotal,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
          ),
          child: Icon(
            icon,
            size: 22,
            color: context.colors.textSecondary,
          ),
        ),
      );

  Widget _buildShareButton({required VoidCallback onTap}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
          ),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: SvgPicture.asset(
              'assets/icons/share.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                context.colors.textSecondary,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      );

  List<String> _getAttributes(Map<String, dynamic> item) {
    final attributes = <String>[];
    final attrs = item['attributes'];

    if (attrs is Map) {
      final values = attrs.values.take(5);
      for (final value in values) {
        if (value != null && value.toString().isNotEmpty) {
          attributes.add(value.toString());
        }
      }
    }

    return attributes;
  }

  Widget _buildCartItem(Map<String, dynamic> item, CartProvider cart) {
    final auth = context.read<AuthProvider>();
    final cartProvider = context.read<CartProvider>();
    final pid = item['product_id'] as int;
    final qty = item['quantity'] as int;
    final name = item['name'] as String? ?? '';
    final brand = item['brand'] as String? ?? '';
    final price = (item['price'] ?? 0).toDouble();
    final cardPriceRaw = item['card_price'];
    final cardPrice =
        cardPriceRaw != null ? (cardPriceRaw as num).toDouble() : price;
    final salePrice = item['sale_price']?.toDouble();
    final imageRaw = (item['main_image_detail'] ?? item['main_image_card'] ?? item['main_image']) as String? ?? '';
    final image = imageRaw.replaceAll('main.webp', 'main_detail.webp');
    final stock = item['stock'] as int? ?? 0;
    final isUnavailable = item['unavailable'] == true || stock <= 0;
    final isChecked = cart.isItemChecked(pid);
    final freeQty = item['free_qty'] ?? cart.freeItemsMap[pid] ?? 0;
    final paidQty = (item['paid_qty'] ?? qty - freeQty).clamp(0, qty);
    final isAllFree = freeQty >= qty;
    final currency = context.read<CurrencyProvider>();
    final isRemoving = _removingItems.contains(pid);
    final attributes = _getAttributes(item);

    double displayPrice;
    double? oldPrice;
    bool oldPriceStrikethrough;

    if (salePrice != null && salePrice > 0 && salePrice < price) {
      displayPrice = salePrice;
      oldPrice = price;
      oldPriceStrikethrough = true;
    } else if (cartProvider.hasCard) {
      displayPrice = cardPrice;
      oldPrice = price;
      oldPriceStrikethrough = true;
    } else if (auth.isLoggedIn) {
      displayPrice = cardPrice < price ? cardPrice : price;
      oldPrice = cardPrice < price ? price : null;
      oldPriceStrikethrough = oldPrice != null;
    } else {
      displayPrice = cardPrice < price ? cardPrice : price;
      oldPrice = cardPrice < price ? price : null;
      oldPriceStrikethrough = false;
    }

    void toggleWishlist() {
      HapticService.light();
      if (!auth.isLoggedIn) {
        MainShell.push(context, const LoginScreen());
        return;
      }
      final wishlist = context.read<WishlistProvider>();
      final inWishlist = wishlist.isInWishlist(pid);
      if (inWishlist) {
        ApiService.post(
          '/api/wishlist/remove-batch',
          {
            'product_ids': [pid],
          },
        ).then((result) {
          if (result.isFailure) {
            AppLogger.warning(
              _logTag,
              'wishlist remove failed: ${result.errorOrNull?.message}',
            );
            return;
          }
          wishlist.setInWishlist(pid, false);
        });
      } else {
        ApiService.post(
          '/api/wishlist/add-batch',
          {
            'product_ids': [pid],
          },
        ).then((result) {
          if (result.isFailure) {
            AppLogger.warning(
              _logTag,
              'wishlist add failed: ${result.errorOrNull?.message}',
            );
            return;
          }
          wishlist.setInWishlist(pid, true);
        });
      }
    }

    void removeItem() {
      HapticService.medium();
      setState(() => _removingItems.add(pid));
      _closeAllSwipes();
      Future.delayed(const Duration(milliseconds: 300), () {
        cart.removeItem(pid);
        if (mounted) setState(() => _removingItems.remove(pid));
      });
    }

    return AnimatedOpacity(
      opacity: isRemoving ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(color: context.colors.brandLight),
          child: Stack(
            children: [
              Positioned.fill(
                child: Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    GestureDetector(
                      onTap: toggleWishlist,
                      child: Container(
                        width: 80,
                        color: context.colors.brand,
                        alignment: Alignment.center,
                        child: Consumer<WishlistProvider>(
                          builder: (context, wishlist, _) {
                            final inWishlist =
                                wishlist.isInWishlist(pid);
                            return Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                Icon(
                                  inWishlist
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  inWishlist
                                      ? 'В избранном'
                                      : 'В избранное',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: removeItem,
                      child: Container(
                        width: 80,
                        color: context.colors.brandDark,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                              size: 22,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Удалить',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onHorizontalDragUpdate: (details) {
                  if (isRemoving) return;
                  final o = _swipeOffsets[pid] ?? 0;
                  double no = o + details.delta.dx;
                  if (no > 0) no = 0;
                  if (no < -160) no = -160;
                  setState(() => _swipeOffsets[pid] = no);
                },
                onHorizontalDragEnd: (details) {
                  final o = _swipeOffsets[pid] ?? 0;
                  setState(() => _swipeOffsets[pid] = o < -80 ? -160 : 0);
                },
                child: GestureDetector(
                  onTap: () {
                    if ((_swipeOffsets[pid] ?? 0) < -40) {
                      setState(() => _swipeOffsets[pid] = 0);
                      return;
                    }
                    MainShell.push(
                      context,
                      ProductDetailScreen(
                        slug: item['slug'] as String? ?? '',
                      ),
                    );
                  },
                  child: Transform.translate(
                    offset: Offset(_swipeOffsets[pid] ?? 0, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        color: context.colors.surface,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  children: [
                                    ColorFiltered(
                                      colorFilter: isUnavailable
                                          ? const ColorFilter.matrix(
                                              <double>[
                                                0.2126, 0.7152, 0.0722,
                                                0, 0, 0.2126, 0.7152,
                                                0.0722, 0, 0, 0.2126,
                                                0.7152, 0.0722, 0, 0,
                                                0, 0, 0, 0.4, 0,
                                              ],
                                            )
                                          : const ColorFilter.mode(
                                              Colors.transparent,
                                              BlendMode.dst,
                                            ),
                                      child: ImageLoader(
                                        imageUrl: image,
                                        width: 96,
                                        height: 128,
                                        borderRadius: 0,
                                      ),
                                    ),
                                    if (!isUnavailable)
                                      Positioned(
                                        top: 6,
                                        left: 6,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white
                                                .withValues(alpha: 0.85),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          padding:
                                              const EdgeInsets.all(3),
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: Checkbox(
                                              value: isChecked,
                                              onChanged: (_) =>
                                                  cart.toggleItem(pid),
                                              activeColor: context.colors.brand,
                                              shape:
                                                  RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  6,
                                                ),
                                              ),
                                              materialTapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isUnavailable) ...[
                                      Text(
                                        'Нет в наличии',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: context.colors.textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ] else if (isAllFree) ...[
                                      Row(
                                        children: [
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: '0 ',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: context.colors.success,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: currency.symbol,
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: context.colors.success,
                                                    fontFamily:
                                                        currency.fontFamily,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 6,
                                            ),
                                            child: _buildPriceWidget(
                                              price * qty,
                                              fontSize: 14,
                                              color: const Color(
                                                0xFF868695,
                                              ),
                                              decoration:
                                                  TextDecoration.lineThrough,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else if (freeQty > 0 && paidQty > 0) ...[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline:
                                            TextBaseline.alphabetic,
                                        children: [
                                          if (salePrice != null &&
                                              salePrice > 0 &&
                                              salePrice < price)
                                            Text(
                                              '%',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: context.colors.error,
                                              ),
                                            )
                                          else
                                            Transform.translate(
                                              offset:
                                                  const Offset(0, 2),
                                              child: Icon(
                                                Icons
                                                    .credit_card_rounded,
                                                size: 22,
                                                color: context.colors.brand,
                                              ),
                                            ),
                                          const SizedBox(width: 4),
                                          _buildPriceWidget(
                                            displayPrice * paidQty,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: salePrice != null &&
                                                    salePrice > 0 &&
                                                    salePrice < price
                                                ? context.colors.error
                                                : context.colors.brand,
                                          ),
                                          if (oldPrice != null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(
                                                left: 6,
                                              ),
                                              child: _buildPriceWidget(
                                                oldPrice * qty,
                                                fontSize: 14,
                                                color: context.colors.textMuted,
                                                decoration:
                                                    oldPriceStrikethrough
                                                        ? TextDecoration
                                                            .lineThrough                                                        : null,
                                              ),
                                            ),
                                        ],
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 2),
                                        child: Text(
                                          '+$freeQty шт. бесплатно',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: context.colors.success,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.baseline,
                                        textBaseline:
                                            TextBaseline.alphabetic,
                                        children: [
                                          if (salePrice != null &&
                                              salePrice > 0 &&
                                              salePrice < price)
                                            Text(
                                              '%',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color: context.colors.error,
                                              ),
                                            )
                                          else
                                            Transform.translate(
                                              offset:
                                                  const Offset(0, 2),
                                              child: Icon(
                                                Icons
                                                    .credit_card_rounded,
                                                size: 22,
                                                color: context.colors.brand,
                                              ),
                                            ),
                                          const SizedBox(width: 4),
                                          _buildPriceWidget(
                                            displayPrice * qty,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: salePrice != null &&
                                                    salePrice > 0 &&
                                                    salePrice < price
                                                ? context.colors.error
                                                : context.colors.brand,
                                          ),
                                          if (oldPrice != null)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(
                                                left: 6,
                                              ),
                                              child: _buildPriceWidget(
                                                oldPrice * qty,
                                                fontSize: 14,
                                                color: context.colors.textMuted,
                                                decoration:
                                                    oldPriceStrikethrough
                                                        ? TextDecoration
                                                            .lineThrough
                                                        : null,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          if (brand.isNotEmpty) ...[
                                            TextSpan(
                                              text: brand,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: isUnavailable
                                                    ? context.colors.textDisabled
                                                    : context.colors.textPrimary,
                                              ),
                                            ),
                                            const TextSpan(text: ' / '),
                                          ],
                                          TextSpan(
                                            text: name,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isUnavailable
                                                  ? const Color(
                                                      0xFFBBBBBB,
                                                    )
                                                  : const Color(
                                                      0xFF242424,
                                                    ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (attributes.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        attributes.join(' · '),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isUnavailable
                                              ? context.colors.textDisabled
                                              : context.colors.textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    if (!isUnavailable) ...[
                                      const SizedBox(height: 8),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: context.colors.surfaceAlt,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                          vertical: 2,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildQtyBtn(
                                              Icons.remove,
                                              () => cart.updateQuantity(
                                                pid,
                                                qty - 1,
                                              ),
                                            ),
                                            SizedBox(
                                              width: 44,
                                              child: Text(
                                                '$qty',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            _buildQtyBtn(
                                              Icons.add,
                                              () => cart.updateQuantity(
                                                pid,
                                                qty + 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: () {
          HapticService.light();
          onTap();
        },
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 18,
            color: context.colors.textSecondary,
          ),
        ),
      );
}