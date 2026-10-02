// lib/widgets/product_card.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/image_cache.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/wishlist_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/rateable_provider.dart';
import '../screens/main_shell.dart';
import '../screens/product/product_detail_screen.dart';
import '../screens/auth/login_screen.dart';
import 'rate_product_sheet.dart';
import '../services/cdn_service.dart';
import '../services/api_service.dart';
import '../core/app_colors.dart';

class ProductCard extends StatefulWidget {
  final Product product;
  final String? searchQuery;
  final int? searchPosition;
  const ProductCard({
    super.key,
    required this.product,
    this.searchQuery,
    this.searchPosition,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  int _currentImage = 0;
  late final PageController _pageController;

  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _isVisible = false;
  bool _imagesPrecached = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.product.hasVideo) {
      _initVideo();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_imagesPrecached) {
      _imagesPrecached = true;
      _precacheImages();
    }
  }

  void _precacheImages() {
    for (final image in widget.product.allImages) {
      final url = CdnService.imageUrl(image);
      _precacheWithRetry(url, 3);
    }
  }

  void _precacheWithRetry(String url, int attempts) async {
    try {
      await precacheImage(CachedNetworkImageProvider(url), context);
    } catch (_) {
      if (attempts > 1) {
        Future.delayed(const Duration(seconds: 1), () => _precacheWithRetry(url, attempts - 1));
      }
    }
  }

  void _initVideo() {
    final videoUrl = widget.product.videoUrlForPlayback;
    if (videoUrl == null) return;

    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );
    _videoController!.initialize().then((_) {
      if (mounted) {
        setState(() => _videoInitialized = true);
        _videoController!.setLooping(true);
        _videoController!.setVolume(0);
        _videoController!.play();
      }
    }).catchError((_) {
      if (mounted) setState(() => _videoInitialized = false);
    });
  }

  void _onVisibilityChanged(bool visible) {
    if (_isVisible == visible) return;
    _isVisible = visible;

    if (!mounted || _disposed) return;

    if (visible && _videoInitialized && _videoController != null) {
      _videoController!.play();
    } else if (!visible && _videoController != null && _videoInitialized) {
      _videoController!.pause();
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _logSearchClick() async {
    final query = widget.searchQuery;
    final position = widget.searchPosition;
    if (query == null || query.isEmpty || position == null) return;

    try {
      await ApiService.post(
        '/api/search/log-click',
        {
          'query': query,
          'product_id': widget.product.id,
          'position': position,
        },
        retry: false,
        timeout: const Duration(seconds: 3),
      );
    } catch (_) {
      // Не ломаем UX, если логирование упало
    }
  }

  void _addToCart() {
    final product = widget.product;
    if (!product.inStock) return;

    final cart = context.read<CartProvider>();
    final currentQty = cart.getQuantity(product.id);
    if (currentQty >= product.stock) return;

    cart.addItemFull({
      'product_id': product.id,
      'quantity': 1,
      'name': product.name,
      'slug': product.slug,
      'price': product.price,
      'sale_price': product.salePrice,
      'card_price': product.cardPrice,
      'main_image': product.mainImage ?? '',
      'stock': product.stock,
      'brand': product.brand ?? '',
      'category_id': null,
      'unavailable': false,
    }, 1);
  }

  String _formatPrice(double price) {
    if (price == price.roundToDouble()) {
      return '${price.toInt()}';
    }
    return price.toStringAsFixed(2);
  }

  String _pluralReviews(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'оценка';
    if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) return 'оценки';
    return 'оценок';
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final images = product.allImages;
    final maxDots = (product.hasVideo ? 1 : 0) + images.length;
    final displayDots = maxDots > 5 ? 5 : maxDots;
    final auth = context.watch<AuthProvider>();
    final currency = context.watch<CurrencyProvider>();
    final hasActiveCard = auth.isLoggedIn;
    final cart = context.watch<CartProvider>();
    final inCartQty = cart.getQuantity(product.id);
    final canAddMore = product.inStock && inCartQty < product.stock;

    final symbolStyle = TextStyle(
      fontSize: currency.symbolFontSize,
      fontWeight: FontWeight.w700,
      fontFamily: currency.fontFamily,
    );

    return VisibilityDetector(
      key: ValueKey('product_${product.id}'),
      onVisibilityChanged: (info) {
        _onVisibilityChanged(info.visibleFraction > 0.1);
      },
      child: GestureDetector(
        onTap: () {
          _logSearchClick();
          MainShell.push(context, ProductDetailScreen(slug: product.slug));
        },
        child: ClipRect(
          child: Container(
            color: context.colors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 1000 / 1350,
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) => setState(() => _currentImage = index % (displayDots > 0 ? displayDots : 1)),
                          itemCount: _getTotalSlides(),
                          itemBuilder: (context, index) {
                            if (product.hasVideo && index == 0) {
                              return _buildVideoSlide();
                            }
                            final imageIndex = product.hasVideo ? index - 1 : index;
                            final url = imageIndex < images.length ? images[imageIndex] : product.imageUrl;

                            final cdnUrl = CdnService.imageUrl(url);
                            final fallbackUrl = CdnService.imageUrlFallback(url);

                            // Логический размер карточки в сетке 2x2 ≈ 180×240.
                            // imageCacheSize учитывает devicePixelRatio.
                            final cacheW = imageCacheSize(context, size: 180);
                            final cacheH = imageCacheSize(context, size: 240);

                            return CachedNetworkImage(
                              imageUrl: cdnUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: cacheW,
                              memCacheHeight: cacheH,
                              filterQuality: FilterQuality.high,
                              fadeInDuration: Duration.zero,
                              placeholder: (_, _) => const ShimmerBox(height: double.infinity, borderRadius: 0),
                              errorWidget: (_, _, error) {
                                return CachedNetworkImage(
                                  imageUrl: fallbackUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: cacheW,
                                  memCacheHeight: cacheH,
                                  filterQuality: FilterQuality.high,
                                  fadeInDuration: Duration.zero,
                                  placeholder: (_, _) => const ShimmerBox(height: double.infinity, borderRadius: 0),
                                  errorWidget: (_, _, fallbackError) {
                                    return const ShimmerBox(height: double.infinity, borderRadius: 0);
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),

                    // ⭐ ОВЕРЛЕЙ ОЦЕНКИ
                    Positioned.fill(
                      child: Consumer2<AuthProvider, RateableProvider>(
                        builder: (context, auth, rateable, _) {
                          if (!auth.isLoggedIn) return const SizedBox.shrink();
                          if (!rateable.canRate(product.id)) return const SizedBox.shrink();

                          return _RateOverlay(
                            product: product,
                            onRate: () async {
                              final item = {
                                'id': product.id,
                                'name': product.name,
                                'brand': product.brand,
                                'main_image': product.mainImage,
                                'order_date': '',
                                'price': product.price,
                              };
                              final result = await RateProductSheet.show(context, item, () {
                                rateable.markRated(product.id);
                              });
                              if (result == true) {
                                rateable.markRated(product.id);
                              }
                            },
                            onDismiss: () {
                              rateable.markRated(product.id);
                            },
                          );
                        },
                      ),
                    ),

                    // Шильдик акции
                    if (product.badge != null && product.badge!.isNotEmpty)
                      Positioned(
                        top: 0, left: 0,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: context.colors.brand,
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), bottomRight: Radius.circular(8)),
                          ),
                          child: Text(product.badge!, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ),

                    // Сердечко избранного
                    Positioned(
                      top: 0, right: 0,
                      child: Consumer2<AuthProvider, WishlistProvider>(
                        builder: (context, auth, wishlist, _) {
                          final inWishlist = wishlist.isInWishlist(product.id);
                          return GestureDetector(
                            onTap: () {
                              if (!auth.isLoggedIn) {
                                MainShell.push(context, const LoginScreen());
                                return;
                              }
                              wishlist.toggle(product.id);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: 48, height: 48,
                              alignment: Alignment.center,
                              child: CustomPaint(
                                size: const Size(24, 22),
                                painter: inWishlist
                                    ? _HeartFilledPainter(color: context.colors.brand)
                                    : _HeartOutlinePainter(color: context.colors.textPrimary),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Скидка
                    if (product.hasSale)
                      Positioned(
                        bottom: 5, left: 6,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(color: context.colors.error, borderRadius: BorderRadius.circular(5)),
                          child: Text('−${product.salePercent}%', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),

                    // Корзина — с расширенной зоной нажатия
                    Positioned(
                      right: 0,
                      bottom: -22,
                      child: AbsorbPointer(
                        absorbing: !canAddMore,
                        child: GestureDetector(
                          onTap: () {
                            _addToCart();
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 72,
                            height: 72,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: canAddMore
                                    ? (inCartQty > 0 ? context.colors.brand.withValues(alpha: 0.15) : context.colors.brand)
                                    : context.colors.textDisabled,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: canAddMore && inCartQty == 0
                                    ? [
                                        BoxShadow(
                                          color: context.colors.brand.withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: CustomPaint(
                                  size: Size(22, 22),
                                  painter: _CartIconPainter(
                                    color: canAddMore
                                        ? (inCartQty > 0 ? context.colors.brand : Colors.white)
                                        : context.colors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Точки пагинации
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 0),
                  child: SizedBox(
                    height: 5,
                    child: displayDots > 1
                        ? Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(displayDots, (index) {
                                final isActive = _currentImage == index;
                                return AnimatedContainer(
                                  duration: Duration(milliseconds: 200),
                                  width: isActive ? 16 : 5,
                                  height: 5,
                                  margin: EdgeInsets.symmetric(horizontal: 2),
                                  decoration: BoxDecoration(
                                    color: isActive ? context.colors.brand : context.colors.border,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),

                // 🔥 Цена и название — устойчивая вёрстка
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        // Цена — фиксированной высоты
                        SizedBox(
                          height: 24,
                          child: product.hasSale
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '% ${_formatPrice(product.salePrice!)} ',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.error),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(currency.symbol, style: symbolStyle.copyWith(color: context.colors.error, fontSize: 18)),
                                    SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '${_formatPrice(product.price)} ',
                                        style: TextStyle(fontSize: 14, color: context.colors.textMuted, decoration: TextDecoration.lineThrough),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(currency.symbol, style: symbolStyle.copyWith(fontSize: 14, color: context.colors.textMuted, decoration: TextDecoration.lineThrough)),
                                  ],
                                )
                              : hasActiveCard && product.cardPrice != null && product.cardPrice! < product.price
                                  ? Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Transform.translate(
                                          offset: Offset(0, 2),
                                          child: Icon(Icons.credit_card_rounded, size: 22, color: context.colors.brand),
                                        ),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '${_formatPrice(product.cardPrice!)} ',
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.brand),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(currency.symbol, style: symbolStyle.copyWith(color: context.colors.brand, fontSize: 18)),
                                        SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            '${_formatPrice(product.price)} ',
                                            style: TextStyle(fontSize: 14, color: context.colors.textMuted, decoration: TextDecoration.lineThrough),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(currency.symbol, style: symbolStyle.copyWith(fontSize: 14, color: context.colors.textMuted, decoration: TextDecoration.lineThrough)),
                                      ],
                                    )
                                  : Row(
                                      crossAxisAlignment: CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Transform.translate(
                                          offset: Offset(0, 2),
                                          child: Icon(Icons.credit_card_rounded, size: 22, color: context.colors.brand),
                                        ),
                                        SizedBox(width: 4),
                                        Flexible(
                                          child: Text(
                                            '${_formatPrice(product.cardPrice ?? product.effectivePrice)} ',
                                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.brand),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(currency.symbol, style: symbolStyle.copyWith(color: context.colors.brand, fontSize: 18)),
                                        SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            '${_formatPrice(product.price)} ',
                                            style: TextStyle(fontSize: 14, color: context.colors.textMuted),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(currency.symbol, style: symbolStyle.copyWith(fontSize: 14, color: context.colors.textMuted)),
                                      ],
                                    ),
                        ),
                        SizedBox(height: 4),
                        // Название — одна строка
                        Text.rich(
                          TextSpan(
                            children: product.brand != null && product.brand!.isNotEmpty
                                ? [
                                    TextSpan(text: '${product.brand} ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: context.colors.textPrimary)),
                                    TextSpan(text: '/ ', style: TextStyle(fontSize: 13)),
                                    TextSpan(text: product.name, style: TextStyle(fontSize: 13, color: context.colors.textMuted)),
                                  ]
                                : [
                                    TextSpan(text: product.name, style: TextStyle(fontSize: 13, color: context.colors.textMuted)),
                                  ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Рейтинг — одна строка
                        if (product.reviewCount > 0) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.star, size: 14, color: context.colors.warning),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  '${product.averageRating.toStringAsFixed(1)} • ${product.reviewCount} ${_pluralReviews(product.reviewCount)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.colors.textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _getTotalSlides() {
    final images = widget.product.allImages;
    final count = (widget.product.hasVideo ? 1 : 0) + images.length;
    return count > 0 ? count : 1;
  }

  Widget _buildVideoSlide() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (widget.product.allImages.isNotEmpty)
          CachedNetworkImage(
            imageUrl: CdnService.imageUrl(widget.product.imageUrl),
            fit: BoxFit.cover,
            memCacheWidth: imageCacheSize(context, size: 300),
            memCacheHeight: imageCacheSize(context, size: 400),
            filterQuality: FilterQuality.high,
            fadeInDuration: Duration.zero,
            placeholder: (_, _) => const ShimmerBox(height: double.infinity, borderRadius: 0),
            errorWidget: (_, _, _) => CachedNetworkImage(
              imageUrl: CdnService.imageUrlFallback(widget.product.imageUrl),
              fit: BoxFit.cover,
              memCacheWidth: imageCacheSize(context, size: 300),
              memCacheHeight: imageCacheSize(context, size: 400),
              filterQuality: FilterQuality.high,
              fadeInDuration: Duration.zero,
              errorWidget: (_, _, _) => ShimmerBox(height: double.infinity, borderRadius: 0),
            ),
          )
        else
          Container(color: context.colors.surfaceAlt),

        if (_videoInitialized && _videoController != null)
          AnimatedOpacity(
            opacity: _videoInitialized ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            child: VideoPlayer(_videoController!),
          ),

        Positioned(
          top: 6, left: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Видео',
              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ========== ОВЕРЛЕЙ ДЛЯ ОЦЕНКИ ==========

class _RateOverlay extends StatefulWidget {
  final Product product;
  final VoidCallback onRate;
  final VoidCallback onDismiss;

  const _RateOverlay({
    required this.product,
    required this.onRate,
    required this.onDismiss,
  });

  @override
  State<_RateOverlay> createState() => _RateOverlayState();
}

class _RateOverlayState extends State<_RateOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _opacityAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return GestureDetector(
          onTap: widget.onRate,
          behavior: HitTestBehavior.opaque,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Opacity(
                    opacity: _opacityAnim.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 28, color: context.colors.border),
                              SizedBox(width: 3),
                              Icon(Icons.star_rounded, size: 28, color: context.colors.border),
                              SizedBox(width: 3),
                              Icon(Icons.star_rounded, size: 28, color: context.colors.border),
                              SizedBox(width: 3),
                              Icon(Icons.star_rounded, size: 28, color: context.colors.border),
                              SizedBox(width: 3),
                              Icon(Icons.star_rounded, size: 28, color: context.colors.border),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.95),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Оценить товар',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: GestureDetector(
                    onTap: widget.onDismiss,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ========== ИКОНКИ ==========

class _CartIconPainter extends CustomPainter {
  final Color color;
  _CartIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final scale = size.width / 24;
    canvas.scale(scale);

    canvas.drawCircle(const Offset(8, 20.5), 2, paint);
    canvas.drawCircle(const Offset(19, 20.5), 2, paint);

    final path = Path()
      ..moveTo(2, 2)
      ..lineTo(5, 2)
      ..lineTo(7.5, 14.5)
      ..cubicTo(7.7, 15.3, 8.5, 16, 9.5, 16)
      ..lineTo(19, 16)
      ..cubicTo(20, 16, 20.8, 15.3, 21, 14.5)
      ..lineTo(22.5, 6.5)
      ..lineTo(6.5, 6.5);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeartOutlinePainter extends CustomPainter {
  final Color color;

  _HeartOutlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final scaleX = size.width / 23;
    final scaleY = size.height / 21;
    canvas.drawPath(
      Path()
        ..moveTo(11.5 * scaleX, 19.5 * scaleY)
        ..cubicTo(5.5 * scaleX, 15 * scaleY, 1 * scaleX, 10.8 * scaleY, 1 * scaleX, 7 * scaleY)
        ..cubicTo(1 * scaleX, 4.2 * scaleY, 3.1 * scaleX, 1.5 * scaleY, 6.5 * scaleX, 1.5 * scaleY)
        ..cubicTo(8 * scaleX, 1.5 * scaleY, 9.5 * scaleX, 2 * scaleY, 10.7 * scaleX, 3 * scaleY)
        ..lineTo(11.5 * scaleX, 3 * scaleY)
        ..lineTo(12.3 * scaleX, 2.2 * scaleY)
        ..cubicTo(13.5 * scaleX, 1.3 * scaleY, 15 * scaleX, 1.5 * scaleY, 16.5 * scaleX, 1.5 * scaleY)
        ..cubicTo(19.9 * scaleX, 1.5 * scaleY, 22 * scaleX, 4.2 * scaleY, 22 * scaleX, 7 * scaleY)
        ..cubicTo(22 * scaleX, 10.8 * scaleY, 17.5 * scaleX, 15 * scaleY, 11.5 * scaleX, 19.5 * scaleY)
        ..close(),
      paint,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeartFilledPainter extends CustomPainter {
  final Color color;

  _HeartFilledPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final scaleX = size.width / 23;
    final scaleY = size.height / 21;
    canvas.drawPath(
      Path()
        ..moveTo(11.5 * scaleX, 19.5 * scaleY)
        ..cubicTo(5.5 * scaleX, 15 * scaleY, 1 * scaleX, 10.8 * scaleY, 1 * scaleX, 7 * scaleY)
        ..cubicTo(1 * scaleX, 4.2 * scaleY, 3.1 * scaleX, 1.5 * scaleY, 6.5 * scaleX, 1.5 * scaleY)
        ..cubicTo(8 * scaleX, 1.5 * scaleY, 9.5 * scaleX, 2 * scaleY, 10.7 * scaleX, 3 * scaleY)
        ..lineTo(11.5 * scaleX, 3 * scaleY)
        ..lineTo(12.3 * scaleX, 2.2 * scaleY)
        ..cubicTo(13.5 * scaleX, 1.3 * scaleY, 15 * scaleX, 1.5 * scaleY, 16.5 * scaleX, 1.5 * scaleY)
        ..cubicTo(19.9 * scaleX, 1.5 * scaleY, 22 * scaleX, 4.2 * scaleY, 22 * scaleX, 7 * scaleY)
        ..cubicTo(22 * scaleX, 10.8 * scaleY, 17.5 * scaleX, 15 * scaleY, 11.5 * scaleX, 19.5 * scaleY)
        ..close(),
      paint,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ========== СКЕЛЕТОНЫ ==========

class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Container(
        color: context.colors.surface,
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(height: 180, borderRadius: 20),
            const SizedBox(height: 10),
            const ShimmerBox(height: 18, width: 80, borderRadius: 6),
            const SizedBox(height: 6),
            const ShimmerBox(height: 14, width: 100, borderRadius: 4),
            const SizedBox(height: 4),
            const ShimmerBox(height: 14, width: 70, borderRadius: 4),
          ],
        ),
      );
}

class BannerSkeleton extends StatelessWidget {
  const BannerSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: const ShimmerBox(height: 140, borderRadius: 16),
      );
}

class QuickActionsSkeleton extends StatelessWidget {
  const QuickActionsSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSkeletonAction(),
            _buildSkeletonAction(),
            const ShimmerBox(height: 60, width: 60, borderRadius: 16),
            _buildSkeletonAction(),
            _buildSkeletonAction(),
          ],
        ),
      );
  Widget _buildSkeletonAction() => const Column(
        children: [
          ShimmerBox(height: 28, width: 28, borderRadius: 8),
          SizedBox(height: 4),
          ShimmerBox(height: 10, width: 40, borderRadius: 3),
        ],
      );
}

class ShimmerBox extends StatefulWidget {
  final double height;
  final double? width;
  final double borderRadius;
  const ShimmerBox({super.key, required this.height, this.width, this.borderRadius = 8});
  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)..repeat(reverse: true);
    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(_controller);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [context.colors.surfaceAlt, context.colors.border, context.colors.surfaceAlt],
            ),
          ),
        ),
      );
}