// lib/screens/product/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_logger.dart';
import '../../models/product.dart';
import '../../models/product_detail.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/city_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/api_service.dart';
import '../../services/cdn_service.dart';
import '../../services/haptic_service.dart';
import '../../services/product_service.dart';
import '../../services/smart_image_loader.dart';
import '../../widgets/product/product_about_panel.dart';
import '../../widgets/product/product_bottom_bar.dart';
import '../../widgets/product/product_cross_sells.dart';
import '../../widgets/product/product_delivery_estimate.dart';
import '../../widgets/product/product_gallery.dart';
import '../../widgets/product/product_price_block.dart';
import '../../widgets/product/product_purchased_banner.dart';
import '../../widgets/product/product_rating_section.dart';
import '../../widgets/product/podeli_banner.dart';
import '../../widgets/product_card.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../auth/login_screen.dart';
import '../catalog/catalog_screen.dart';
import '../checkout/checkout_screen.dart';
import '../main_shell.dart';
import 'product_questions_screen.dart';
import 'product_reviews_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final String slug;

  const ProductDetailScreen({super.key, required this.slug});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const _logTag = 'ProductDetailScreen';

  ProductDetail? _product;
  bool _loading = true;
  String? _error;
  final ScrollController _scrollController = ScrollController();
  String _currentSlug = '';
  double _contentOpacity = 1.0;
  double _headerOpacity = 0.0;
  bool _showAlsoTab = true;
  bool _disposed = false;

  double _bottomBarOpacity = 1.0;
  double _bannerOpacity = 1.0;
  final GlobalKey _tabsHeaderKey = GlobalKey();
  double _tabsHeaderY = double.infinity;

  List<Product> _alsoProducts = [];
  bool _alsoLoading = false;
  bool _alsoHasMore = true;
  int _alsoPage = 1;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen('product_${widget.slug}');
    _currentSlug = widget.slug;
    _loadProduct();
    _scrollController.addListener(_onScroll);
    _updateStatusBar();
  }

  @override
  void dispose() {
    _disposed = true;
    _scrollController.dispose();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!_disposed && mounted) setState(fn);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final offset = _scrollController.offset;
    final maxExtent = _scrollController.position.maxScrollExtent;

    final headerOpacity = (offset / 150).clamp(0.0, 1.0);
    if (headerOpacity != _headerOpacity) {
      _safeSetState(() => _headerOpacity = headerOpacity);
      _updateStatusBar();
    }

    if (_tabsHeaderY == double.infinity &&
        _tabsHeaderKey.currentContext != null) {
      final renderObject = _tabsHeaderKey.currentContext!.findRenderObject();
      if (renderObject is RenderBox) {
        try {
          RenderObject? parent = renderObject.parent;
          RenderObject? viewport;
          while (parent != null) {
            if (parent.runtimeType.toString() == 'RenderViewport' ||
                parent.runtimeType.toString() == 'RenderViewportBase') {
              viewport = parent;
              break;
            }
            parent = parent.parent;
          }
          if (viewport != null) {
            final position =
                renderObject.localToGlobal(Offset.zero, ancestor: viewport);
            _tabsHeaderY = position.dy;
          }
        } catch (_) {
          // Не удалось вычислить позицию — пропускаем.
        }
      }
    }

    if (_tabsHeaderY != double.infinity && _tabsHeaderY > 0) {
      final viewportHeight = _scrollController.position.viewportDimension;

      final startHide = _tabsHeaderY - viewportHeight * 0.3;
      final endHide = _tabsHeaderY;
      final progress =
          ((offset - startHide) / (endHide - startHide)).clamp(0.0, 1.0);
      final barOpacity = (1.0 - progress).clamp(0.0, 1.0);

      if ((barOpacity - _bottomBarOpacity).abs() > 0.01) {
        _safeSetState(() {
          _bottomBarOpacity = barOpacity;
          _bannerOpacity = barOpacity;
        });
      }
    }

    if (_showAlsoTab &&
        offset >= maxExtent - 500 &&
        !_alsoLoading &&
        _alsoHasMore) {
      _loadAlsoProducts();
    }
  }

  void _updateStatusBar() {
    final isTransparent = _headerOpacity < 0.5;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isTransparent ? Brightness.dark : Brightness.light,
        statusBarBrightness:
            isTransparent ? Brightness.light : Brightness.dark,
      ),
    );
  }

  Future<void> _loadProduct() async {
    if (_currentSlug.isEmpty) return;
    _safeSetState(() {
      _loading = _product == null;
      _error = null;
    });

    final city = context.read<CityProvider>().city;
    ApiService.invalidateCache(prefix: '/api/products/detail');
    final product = await ProductService.getDetail(_currentSlug, city);

    if (_disposed || !mounted) return;

    _safeSetState(() {
      _product = product;
      _loading = false;
    });

    if (product != null) {
      if (product.allImages.isNotEmpty) {
        SmartImageLoader().load(
          CdnService.imageUrl(product.allImages.first),
          priority: 0,
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (_disposed || !mounted) return;
          for (final image in product.allImages.skip(1).take(3)) {
            SmartImageLoader().load(
              CdnService.imageUrl(image),
              priority: 80,
            );
          }
        });
      }

      AnalyticsService.logProductView(
        product.id,
        product.name,
        product.price,
      );
      ProductService.trackView(product.id);
      if (product.crossSells.isNotEmpty) {
        context
            .read<WishlistProvider>()
            .checkBatch(product.crossSells.map((cs) => cs.id).toList());
      }
      if (product.upsells.isNotEmpty) {
        context
            .read<WishlistProvider>()
            .checkBatch(product.upsells.map((u) => u.id).toList());
      }
    }
  }

  void _navigateToProduct(String slug) {
    if (_currentSlug == slug) return;
    _currentSlug = slug;
    _scrollController.jumpTo(0);
    _safeSetState(() {
      _contentOpacity = 0.0;
      _headerOpacity = 0.0;
      _bottomBarOpacity = 1.0;
      _bannerOpacity = 1.0;
      _tabsHeaderY = double.infinity;
      _alsoProducts = [];
      _alsoPage = 1;
      _alsoHasMore = true;
      _showAlsoTab = true;
    });
    _updateStatusBar();
    _loadProduct().then((_) {
      if (!_disposed && mounted) {
        _safeSetState(() => _contentOpacity = 1.0);
      }
    });
  }

  void _showAboutPanel() {
    if (_product == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => ProductAboutPanel(product: _product!),
    );
  }

  void _navigateToBrand(String brand) {
    MainShell.push(context, CatalogScreen(initialBrand: brand));
  }

  Future<void> _loadAlsoProducts() async {
    if (_alsoLoading || !_alsoHasMore || _product == null) return;

    _safeSetState(() => _alsoLoading = true);

    final existingIds = <int>{};
    existingIds.add(_product!.id);
    existingIds.addAll(_alsoProducts.map((p) => p.id));

    List<Product> newProducts = [];
    bool hasMoreFromApi = true;

    if (_alsoPage == 1) {
      final result = await ApiService.get(
        '/api/recommendations/product',
        queryParams: {
          'product_id': _product!.id.toString(),
          'limit': '24',
        },
      );

      if (_disposed || !mounted) return;

      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'loadAlsoProducts(product) failed: '
              '${result.errorOrNull?.message}',
        );
        hasMoreFromApi = false;
      } else {
        final data = result.valueOrNull?['data'];
        final productsJson = _extractProductList(data);
        final allProducts = productsJson
            .whereType<Map>()
            .map((p) => Product.fromJson(Map<String, dynamic>.from(p)))
            .toList();
        newProducts = allProducts
            .where((p) => !existingIds.contains(p.id))
            .toList();
        _alsoPage = 2;
      }
    } else {
      final apiPage = _alsoPage - 1;

      final result = await ApiService.get(
        '/api/recommendations/user',
        queryParams: {
          'page': apiPage.toString(),
          'limit': '24',
        },
      );

      if (_disposed || !mounted) return;

      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'loadAlsoProducts(user, page=$apiPage) failed: '
              '${result.errorOrNull?.message}',
        );
        hasMoreFromApi = false;
      } else {
        final data = result.valueOrNull?['data'];
        final productsJson = _extractProductList(data);
        hasMoreFromApi = data is Map && data['has_more'] == true;

        final allProducts = productsJson
            .whereType<Map>()
            .map((p) => Product.fromJson(Map<String, dynamic>.from(p)))
            .toList();
        newProducts = allProducts
            .where((p) => !existingIds.contains(p.id))
            .toList();
      }
    }

    if (!mounted) return;

    _safeSetState(() {
      _alsoProducts.addAll(newProducts);
      _alsoLoading = false;

      if (newProducts.isNotEmpty) {
        _alsoPage++;
      } else if (_alsoPage == 2) {
        _alsoPage++;
      }

      _alsoHasMore = hasMoreFromApi;
    });

    if (newProducts.isNotEmpty) {
      context
          .read<WishlistProvider>()
          .checkBatch(newProducts.map((p) => p.id).toList());
    }
  }

  List<dynamic> _extractProductList(dynamic data) {
    if (data is Map) {
      final raw = data['products'];
      if (raw is List) return raw;
      return const [];
    }
    if (data is List) return data;
    return const [];
  }

  Future<void> _buyNow() async {
    if (_product == null) return;

    if (!context.read<AuthProvider>().isLoggedIn) {
      MainShell.push(context, const LoginScreen());
      return;
    }

    final cart = context.read<CartProvider>();
    final productId = _product!.id;

    cart.addItemFull(_product!.toCartItem(), 1);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await cart.syncFromServer();

    cart.toggleAll(false);
    cart.toggleItem(productId);

    final result = await ApiService.post(
      '/api/orders/initiate',
      {'product_ids': [productId]},
    );

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
  }

  String _formatPrice(double price) {
    if (price == price.roundToDouble()) return '${price.toInt()}';
    return price.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    final double bottomBarBottom = bottomPadding > 0 ? bottomPadding : 20;
    final double bannerBottom = bottomBarBottom + 80;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            _headerOpacity < 0.5 ? Brightness.dark : Brightness.light,
        statusBarBrightness:
            _headerOpacity < 0.5 ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Stack(
          children: [
            _buildBody(),
            if (_product != null && !keyboardOpen) ...[
              Positioned(
                bottom: bannerBottom,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  ignoring: _bannerOpacity < 0.05,
                  child: AnimatedOpacity(
                    opacity: _bannerOpacity,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: ProductPurchasedBanner(
                      productId: _product!.id,
                      purchased: _product!.purchased,
                      alreadyRated: _product!.alreadyRated,
                      item: {
                        'id': _product!.id,
                        'name': _product!.name,
                        'brand': _product!.brand,
                        'main_image': _product!.mainImage,
                        'order_date': _product!.purchaseItem?['order_date'] ??
                            '',
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: bottomBarBottom,
                left: 16,
                right: 16,
                child: IgnorePointer(
                  ignoring: _bottomBarOpacity < 0.05,
                  child: AnimatedOpacity(
                    opacity: _bottomBarOpacity,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: ProductBottomBar(
                      product: _product!,
                      onBuyNow: _buyNow,
                    ),
                  ),
                ),
              ),
            ],
            Positioned(
              bottom: bottomPadding + 20,
              right: 40,
              child: AnimatedOpacity(
                opacity: _bottomBarOpacity < 0.05 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: IgnorePointer(
                  ignoring: _bottomBarOpacity >= 0.05,
                  child: ScrollToTopButton(
                    scrollController: _scrollController,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFDD1847)),
      );
    }
    if (_error != null || _product == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Товар не найден',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF999999),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProduct,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDD1847),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    final product = _product!;

    return Stack(
      children: [
        AnimatedOpacity(
          opacity: _contentOpacity,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).padding.top - 8,
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                      ),
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              ProductGallery(
                                images: product.allImages,
                                heroTag: 'product_${product.id}',
                                videoUrl: product.videoUrl,
                                salePercent: product.hasSale
                                    ? product.salePercent
                                    : null,
                              ),
                              ProductPriceBlock(product: product),
                            ],
                          ),
                          if (product.badge != null &&
                              product.badge!.isNotEmpty)
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: product.badgeColor != null
                                      ? _parseColor(product.badgeColor!)
                                      : const Color(0xFFDD1847),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(10),
                                  ),
                                ),
                                child: Text(
                                  product.badge!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (product.crossSells.isNotEmpty)
                SliverToBoxAdapter(
                  child: ProductCrossSells(
                    crossSells: product.crossSells,
                    onTap: (slug) => _navigateToProduct(slug),
                  ),
                ),
              if (product.effectivePrice <= 30000)
                SliverToBoxAdapter(
                  child: PodeliBanner(
                    price: product.effectivePrice,
                    productImage: product.imageUrl,
                  ),
                ),

              /// 🔥 Тап по карточке рейтинга → экран отзывов.
              /// 🔥 Тап по карточке вопросов → экран вопросов.
              SliverToBoxAdapter(
                child: ProductRatingSection(
                  product: product,
                  reviewPhotos: product.reviewPhotos,
                  onReviewsTap: () => MainShell.push(
                    context,
                    ProductReviewsScreen(
                      productId: product.id,
                      productName: product.name,
                      initialReviewCount: product.reviewCount,
                      averageRating: product.averageRating,
                    ),
                  ),
                  onQuestionsTap: () => MainShell.push(
                    context,
                    ProductQuestionsScreen(
                      productId: product.id,
                      productName: product.name,
                      initialQuestionCount: product.questionCount,
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child:
                      ProductDeliveryEstimate(delivery: product.delivery),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (product.brand != null)
                        GestureDetector(
                          onTap: () => _navigateToBrand(product.brand!),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8E8EC),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              product.brand!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF555555),
                              ),
                            ),
                          ),
                        ),
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      if (product.description != null &&
                          product.description!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          product.description!
                                      .replaceAll(
                                        RegExp(r'<[^>]+>'),
                                        '',
                                      )
                                      .length >
                                  120
                              ? '${product.description!.replaceAll(RegExp(r'<[^>]+>'), '').substring(0, 120)}...'
                              : product.description!
                                  .replaceAll(RegExp(r'<[^>]+>'), ''),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF555555),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _showAboutPanel,
                          child: const Text(
                            'О товаре',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDD1847),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _buildTabsHeader(),
              if (_showAlsoTab)
                _buildAlsoGrid()
              else
                _buildUpsellsGrid(product),
              const SliverToBoxAdapter(child: SizedBox(height: 180)),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildAppBar(),
        ),
      ],
    );
  }

  Color _parseColor(String hex) {
    try {
      String colorStr = hex.replaceFirst('#', '');
      if (colorStr.length == 6) colorStr = 'FF$colorStr';
      return Color(int.parse(colorStr, radix: 16));
    } catch (_) {
      return const Color(0xFFDD1847);
    }
  }

  Widget _buildTabsHeader() {
    return SliverToBoxAdapter(
      child: Container(
        key: _tabsHeaderKey,
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildTab('Смотрите также', _showAlsoTab, () {
                _safeSetState(() => _showAlsoTab = true);
              }),
              const SizedBox(width: 8),
              _buildTab('Покупают вместе', !_showAlsoTab, () {
                _safeSetState(() => _showAlsoTab = false);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String text, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFF0F0F5)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF1A1A1A)
                    : const Color(0xFF8F8F9A),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlsoGrid() {
    if (_alsoProducts.isEmpty && !_alsoLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAlsoProducts();
      });
    }

    if (_alsoLoading && _alsoProducts.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFDD1847)),
        ),
      );
    }

    if (_alsoProducts.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Нет товаров',
              style: TextStyle(color: Color(0xFF999999)),
            ),
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.54,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= _alsoProducts.length) {
            return const ProductCardSkeleton();
          }
          return ProductCard(product: _alsoProducts[index]);
        },
        childCount: _alsoProducts.length + (_alsoLoading ? 4 : 0),
      ),
    );
  }

  Widget _buildUpsellsGrid(ProductDetail product) {
    final upsells = product.upsells;

    if (upsells.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Нет товаров',
              style: TextStyle(color: Color(0xFF999999)),
            ),
          ),
        ),
      );
    }

    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.54,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final u = upsells[index];
          return ProductCard(
            product: Product(
              id: u.id,
              name: u.name,
              slug: u.slug,
              price: u.price,
              salePrice: u.salePrice,
              cardPrice: u.cardPrice,
              stock: u.stock,
              mainImage: u.mainImage,
              gallery: u.gallery,
            ),
          );
        },
        childCount: upsells.length,
      ),
    );
  }

  Widget _buildAppBar() {
    final currency = context.watch<CurrencyProvider>();
    final symbolStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      fontFamily: currency.fontFamily,
      color: Colors.white70,
    );
    final isTransparent = _headerOpacity < 0.5;

    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: BoxDecoration(
        color: const Color(0xFFDD1847).withValues(alpha: _headerOpacity),
      ),
      child: SizedBox(
        height: 44,
        child: Stack(
          children: [
            Positioned(
              left: 8,
              top: 4,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isTransparent
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_product != null)
              Positioned(
                left: 48,
                right: 96,
                top: 0,
                bottom: 0,
                child: Opacity(
                  opacity: _headerOpacity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _product!.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _product!.hasSale
                                ? _formatPrice(_product!.salePrice!)
                                : _formatPrice(
                                    _product!.cardPrice ??
                                        _product!.price,
                                  ),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(currency.symbol, style: symbolStyle),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              right: 8,
              top: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Consumer<WishlistProvider>(
                    builder: (context, wishlist, _) {
                      final inWishlist = _product != null &&
                          wishlist.isInWishlist(_product!.id);
                      return Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isTransparent
                              ? Colors.black.withValues(alpha: 0.3)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            inWishlist
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: isTransparent && inWishlist
                                ? const Color(0xFFDD1847)
                                : Colors.white,
                            size: 18,
                          ),
                          onPressed: () {
                            if (_product != null) {
                              HapticService.medium();
                              final auth = context.read<AuthProvider>();
                              if (!auth.isLoggedIn) {
                                MainShell.push(
                                  context,
                                  const LoginScreen(),
                                );
                                return;
                              }
                              wishlist.toggle(_product!.id);
                            }
                          },
                          padding: EdgeInsets.zero,
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isTransparent
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: SvgPicture.asset(
                        'assets/icons/share.svg',
                        width: 18,
                        height: 18,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                      onPressed: () {
                        if (_product == null) return;
                        final url =
                            'https://xn--80abvyjk6cts.xn--p1ai/product/${_product!.slug}';
                        final text = '${_product!.name}\n$url';
                        final box =
                            context.findRenderObject() as RenderBox?;
                        Share.share(
                          text,
                          subject: _product!.name,
                          sharePositionOrigin: box != null
                              ? box.localToGlobal(Offset.zero) &
                                  box.size
                              : null,
                        );
                      },
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}