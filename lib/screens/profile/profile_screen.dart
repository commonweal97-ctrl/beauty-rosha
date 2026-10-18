// lib/screens/profile/profile_screen.dart
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/adaptive_grid.dart';
import '../../core/api_error.dart';
import '../../core/app_logger.dart';
import '../../core/result.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/bonus_provider.dart';
import '../../providers/favorite_brands_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../providers/waitlist_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../services/api_service.dart';
import '../../services/cdn_service.dart';
import '../../widgets/bonus_history_popup.dart';
import '../../widgets/order_preview.dart';
import '../../widgets/product_card.dart';
import '../../widgets/qr_popup.dart';
import '../../widgets/refresh_overlay.dart';
import '../../widgets/common/support_icon_with_badge.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../auth/login_screen.dart';
import '../main_shell.dart';
import '../notifications/notifications_screen.dart';
import '../service/service_screen.dart';
import 'favorite_brands_screen.dart';
import 'offline_purchases_screen.dart';
import 'orders_screen.dart';
import 'profile_banner.dart';
import 'profile_widgets.dart';
import 'purchases_screen.dart';
import 'reviews_screen.dart';
import 'settings_screen.dart';
import 'support_screen.dart';
import 'viewed_products_screen.dart';
import 'waitlist_screen.dart';
import 'wishlist_screen.dart';
import '../../core/app_colors.dart';

/// Общий таймаут на всю операцию загрузки профиля.
const Duration _kProfileLoadTimeout = Duration(seconds: 15);

enum _LoadPhase { idle, loading, loaded }

class ProfileScreen extends StatefulWidget {
  final String? initialTab;

  const ProfileScreen({super.key, this.initialTab});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static const _logTag = 'ProfileScreen';

  @override
  bool get wantKeepAlive => true;

  // ---- Данные профиля ----
  int _bonusBalance = 0;
  int _displayBonus = 0;
  int _wishlistCount = 0;
  int _purchasesCount = 0;
  int _toRateCount = 0;
  int _waitlistCount = 0;
  int _waitlistInStock = 0;
  String _cardStatus = 'Не активирована';
  bool _hasCard = false;
  String _cardNumber = '';

  // ---- Баннер ----
  String? _profileBannerUrl;
  String? _bannerLinkUrl;
  bool _bannerLoading = true;
  bool _bannerImageReady = false;
  ImageStreamListener? _bannerImageListener;
  ImageStream? _bannerImageStream;

  // ---- Состояние загрузки ----
  _LoadPhase _phase = _LoadPhase.idle;
  bool? _lastAuthState;

  Future<void>? _loadingFuture;

  // ---- Анимация бонусов ----
  AnimationController? _bonusAnimController;
  Animation<double>? _bonusAnimation;

  // ---- Скролл и рекомендации ----
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<OrderPreviewState> _orderPreviewKey =
      GlobalKey<OrderPreviewState>();

  bool _isRefreshing = false;
  bool _showRefreshOverlay = false;

  // ---- Просмотренные ----
  List<Product> _viewedProducts = [];
  bool _viewedLoading = false;
  PageController? _viewedPageController;
  Timer? _viewedTimer;
  bool _viewedAutoScrollEnabled = true;
  bool _viewedAutoScrollPaused = false;
  bool _viewedUserInteracting = false;

  @override
  void initState() {
    super.initState();

    if (widget.initialTab == 'reviews' || widget.initialTab == 'questions') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleRestrictedAction(const ReviewsScreen());
      });
    } else if (widget.initialTab == 'wishlist') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleRestrictedAction(const WishlistScreen());
      });
    } else if (widget.initialTab == 'waitlist') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleRestrictedAction(const WaitlistScreen());
      });
    }
    _initAnimationControllers();
    _scrollController.addListener(_onScrollForRecommendations);
    _initViewedPageController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
  }

  // ============================================================
  //  ANIMATION / SCROLL INIT
  // ============================================================

  void _initAnimationControllers() {
    _bonusAnimController?.dispose();
    _bonusAnimController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _bonusAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _bonusAnimController!, curve: Curves.easeOut),
    );
  }

  void _initViewedPageController() {
    _viewedPageController?.dispose();
    _viewedPageController = PageController(
      viewportFraction: 0.5,
      initialPage: 0,
    );

    _viewedPageController!.addListener(() {
      if (!mounted) return;
      final isUserScrolling =
          _viewedPageController!.position.isScrollingNotifier.value;
      if (isUserScrolling && !_viewedUserInteracting) {
        _viewedUserInteracting = true;
        _pauseViewedAutoScroll();
      }
    });
  }

  void _startViewedAutoScroll() {
    _viewedTimer?.cancel();

    if (_viewedProducts.length <= 2) {
      _viewedAutoScrollEnabled = false;
      return;
    }

    _viewedAutoScrollEnabled = true;
    _viewedAutoScrollPaused = false;

    _viewedTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted ||
          !_viewedAutoScrollEnabled ||
          _viewedAutoScrollPaused ||
          _viewedUserInteracting) {
        return;
      }
      if (_viewedPageController == null ||
          !_viewedPageController!.hasClients) {
        return;
      }

      final currentPage = (_viewedPageController!.page ?? 0).round();
      int nextPage = currentPage + 1;
      if (nextPage >= _viewedProducts.length) nextPage = 0;

      _viewedPageController!.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _pauseViewedAutoScroll() {
    _viewedAutoScrollPaused = true;
    _viewedTimer?.cancel();
    _viewedTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _viewedUserInteracting = false;
        _viewedAutoScrollPaused = false;
        _startViewedAutoScroll();
      }
    });
  }

  void _resetViewedAutoScroll() {
    _viewedTimer?.cancel();
    _viewedAutoScrollPaused = false;
    _viewedUserInteracting = false;
    if (_viewedPageController != null && _viewedPageController!.hasClients) {
      _viewedPageController!.jumpToPage(0);
    }
    _startViewedAutoScroll();
  }

  // ============================================================
  //  REFRESH ALL
  // ============================================================

  Future<void> _refreshAll() async {
    if (_isRefreshing) return;
    _isRefreshing = true;

    if (mounted) setState(() => _showRefreshOverlay = true);

    try {
      await Future.wait([
        _loadData(),
        _safeRefreshRecommendations(),
        _safeRefreshOrderPreview(),
      ]);
      _resetViewedAutoScroll();
    } finally {
      _isRefreshing = false;
      if (mounted) setState(() => _showRefreshOverlay = false);
    }
  }

  Future<void> _safeRefreshRecommendations() async {
    try {
      await context.read<ProfileRecommendationProvider>().refresh();
    } catch (e, st) {
      AppLogger.error(_logTag, 'refresh recommendations failed', e, st);
    }
  }

  Future<void> _safeRefreshOrderPreview() async {
    try {
      await _orderPreviewKey.currentState?.refresh();
    } catch (e, st) {
      AppLogger.error(_logTag, 'refresh order preview failed', e, st);
    }
  }

  // ============================================================
  //  LOAD DATA — ядро
  // ============================================================

  Future<void> _loadData() {
    if (_loadingFuture != null) return _loadingFuture!;
    _loadingFuture = _doLoadData().whenComplete(() {
      _loadingFuture = null;
    });
    return _loadingFuture!;
  }

  Future<void> _doLoadData() async {
    final auth = context.read<AuthProvider>();

    if (!auth.isLoggedIn) {
      if (mounted) setState(() => _phase = _LoadPhase.loaded);
      return;
    }

    if (mounted) {
      setState(() {
        _phase = _LoadPhase.loading;
        _bannerLoading = true;
        _bannerImageReady = false;
      });
    }

    try {
      await _loadAllParts().timeout(_kProfileLoadTimeout);
    } on TimeoutException {
      AppLogger.warning(_logTag, 'Profile load timed out, showing partial');
    } catch (e, st) {
      AppLogger.error(_logTag, 'Profile load failed', e, st);
    }

    if (!mounted) return;
    setState(() => _phase = _LoadPhase.loaded);
  }

  Future<void> _loadAllParts() async {
    unawaited(_prepareSession());

    await _loadStats();
    await _loadBanner();

    await Future.wait([
      _loadViewedProducts(),
      _loadProviderCounts(),
    ]);

    await _safeLoadRecommendations();
  }

  Future<void> _safeLoadRecommendations() async {
    try {
      final rec = context.read<ProfileRecommendationProvider>();
      if (!rec.isLoaded && !rec.isLoading) {
        await rec.loadRecommendations();
      }
    } catch (e, st) {
      AppLogger.error(_logTag, 'loadRecommendations failed', e, st);
    }
  }

  Future<void> _prepareSession() async {
    try {
      await ApiService.loadCookies();
      ApiService.invalidateCache(prefix: '/api/orders/');
      ApiService.invalidateCache(prefix: '/api/profile/');
    } catch (e) {
      AppLogger.warning(_logTag, 'prepareSession failed', e);
    }
  }

  Future<void> _loadStats() async {
    final result = await _getWithRetry('/api/profile/stats');
    if (!mounted) return;

    result
        .onSuccess((data) {
          final payload = data['data'] ?? {};
          setState(() {
            _bonusBalance = payload['bonus_balance'] ?? 0;
            _purchasesCount = payload['purchases_count'] ?? 0;
            _toRateCount = payload['to_rate_count'] ?? 0;
            _hasCard = payload['has_card'] ?? false;
            _cardNumber = payload['card_number'] ?? '';
            _waitlistCount = payload['waitlist_count'] ?? 0;
            _waitlistInStock = payload['waitlist_in_stock'] ?? 0;
            if (_hasCard) {
              _cardStatus = payload['card_status'] == 'active'
                  ? 'Активна'
                  : 'Ожидает активации';
            }
          });
          _animateBonus();
        })
        .onFailure((e) {
          AppLogger.warning(_logTag, 'profile/stats failed: ${e.message}');
        });
  }

  Future<void> _loadBanner() async {
    final result = await _getWithRetry('/api/banners/profile');
    if (!mounted) return;

    if (result.isFailure) {
      setState(() => _bannerLoading = false);
      return;
    }

    final banners = (result.valueOrNull?['data']?['banners'] as List?) ??
        const [];
    if (banners.isEmpty) {
      setState(() => _bannerLoading = false);
      return;
    }

    final banner = banners.first;
    final rawUrl = banner['image_url'] ?? '';
    final fullUrl = rawUrl.isNotEmpty && !rawUrl.startsWith('http')
        ? CdnService.imageUrl(rawUrl)
        : rawUrl;

    if (fullUrl.isEmpty) {
      setState(() => _bannerLoading = false);
      return;
    }

    setState(() {
      _profileBannerUrl = fullUrl;
      _bannerLinkUrl = banner['link_url'] ?? '';
    });
    _preloadBannerImage();
  }

  Future<void> _loadViewedProducts() async {
    if (_viewedLoading) return;
    _viewedLoading = true;

    try {
      final result = await _getWithRetry(
        '/api/products/viewed',
        queryParams: {'limit': '10'},
        maxAttempts: 2,
      );

      if (!mounted) return;
      result.onSuccess((data) {
        final list = (data['data']?['products'] as List?) ?? const [];
        setState(() {
          _viewedProducts =
              list.map((p) => Product.fromJson(p)).toList();
        });
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _resetViewedAutoScroll();
        });
      });
    } finally {
      _viewedLoading = false;
    }
  }

  Future<void> _loadProviderCounts() async {
    await Future.wait([
      _safeProviderCall(
          () => context.read<NotificationProvider>().loadUnreadCount()),
      _safeProviderCall(
          () => context.read<WishlistProvider>().loadCount()),
    ]);

    if (!mounted) return;
    try {
      final c = context.read<WishlistProvider>().count;
      if (mounted) setState(() => _wishlistCount = c);
    } catch (_) {}
  }

  Future<void> _safeProviderCall(Future<void> Function() call) async {
    try {
      await call();
    } catch (e) {
      AppLogger.warning(_logTag, 'provider call failed', e);
    }
  }

  // ============================================================
  //  RETRY HELPER
  // ============================================================

  Future<Result<Map<String, dynamic>>> _getWithRetry(
    String path, {
    int maxAttempts = 3,
    Map<String, dynamic>? queryParams,
  }) async {
    Result<Map<String, dynamic>>? last;
    for (int i = 0; i < maxAttempts; i++) {
      final result = await ApiService.get(
        path,
        forceRefresh: i > 0,
        queryParams: queryParams,
      );
      if (result.isSuccess) return result;
      last = result;

      final err = result.errorOrNull;
      if (err is BusinessError) return result;

      if (i < maxAttempts - 1) {
        await Future.delayed(Duration(milliseconds: 500 * (i + 1)));
      }
    }
    return last ??
        Result.failure(UnknownError('Exhausted retries for $path'));
  }

  // ============================================================
  //  BANNER IMAGE PRELOAD
  // ============================================================

  void _preloadBannerImage() {
    _disposeBannerListener();

    if (_profileBannerUrl == null || _profileBannerUrl!.isEmpty) {
      if (mounted) setState(() => _bannerLoading = false);
      return;
    }

    final provider = CachedNetworkImageProvider(_profileBannerUrl!);
    final stream = provider.resolve(ImageConfiguration.empty);
    _bannerImageStream = stream;

    _bannerImageListener = ImageStreamListener(
      (info, sync) {
        if (mounted) {
          setState(() {
            _bannerImageReady = true;
            _bannerLoading = false;
          });
        }
        _disposeBannerListener();
      },
      onError: (error, st) {
        AppLogger.warning(_logTag, 'banner image load failed', error);
        if (mounted) {
          setState(() {
            _bannerImageReady = false;
            _bannerLoading = false;
          });
        }
        _disposeBannerListener();
      },
    );

    stream.addListener(_bannerImageListener!);

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && _bannerLoading && !_bannerImageReady) {
        setState(() {
          _bannerLoading = false;
          _bannerImageReady = false;
        });
        _disposeBannerListener();
      }
    });
  }

  void _disposeBannerListener() {
    if (_bannerImageListener != null && _bannerImageStream != null) {
      _bannerImageStream!.removeListener(_bannerImageListener!);
      _bannerImageListener = null;
      _bannerImageStream = null;
    }
  }

  void _animateBonus() {
    if (_bonusAnimController == null || !mounted) return;
    _displayBonus = 0;
    _bonusAnimController!.forward(from: 0);
    _bonusAnimation?.addListener(() {
      if (mounted) {
        setState(() =>
            _displayBonus = (_bonusBalance * _bonusAnimation!.value).round());
      }
    });
  }

  void _onScrollForRecommendations() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      final rec = context.read<ProfileRecommendationProvider>();
      if (!rec.isLoading && rec.hasMore) rec.loadRecommendations();
    }
  }

  // ============================================================
  //  UTIL
  // ============================================================

  String _formatExpiryDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      const months = [
        'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
        'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
      ];
      return '${date.day} ${months[date.month - 1]}';
    } catch (_) {
      return dateStr;
    }
  }

  String _pluralize(int n, String one, String two, String five) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return one;
    if ([2, 3, 4].contains(m10) && ![12, 13, 14].contains(m100)) return two;
    return five;
  }

  String _pluralItems(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'товар';
    if ([2, 3, 4].contains(m10) && ![12, 13, 14].contains(m100)) {
      return 'товара';
    }
    return 'товаров';
  }

  String _pluralizeBrands(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'бренд добавлен';
    if ([2, 3, 4].contains(m10) && ![12, 13, 14].contains(m100)) {
      return 'бренда добавлено';
    }
    return 'брендов добавлено';
  }

  // ============================================================
  //  NAVIGATION
  // ============================================================

  void _onBannerTap() {
    if (_bannerLinkUrl == null || _bannerLinkUrl!.isEmpty) return;
    final uri = Uri.tryParse(_bannerLinkUrl!);
    if (uri == null) return;
    if (_bannerLinkUrl!.contains('/service')) {
      _handleRestrictedAction(const ServiceScreen());
      return;
    }
    launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _openNotifications() {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      MainShell.push(context, const LoginScreen());
      return;
    }
    MainShell.push(context, const NotificationsScreen());
  }

  void _openSupport() {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      MainShell.push(context, const LoginScreen());
      return;
    }
    MainShell.push(context, const SupportScreen());
  }

  void _openSettings() => MainShell.push(context, const SettingsScreen());

  void _openCardPopup() {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      MainShell.push(context, const LoginScreen());
      return;
    }
    QrPopup.show(context);
  }

  void _handleRestrictedAction(Widget screen) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      MainShell.push(context, const LoginScreen());
      return;
    }
    MainShell.push(context, screen);
  }

  @override
  void dispose() {
    _viewedTimer?.cancel();
    _viewedPageController?.dispose();
    _bonusAnimController?.dispose();
    _scrollController.dispose();
    _disposeBannerListener();
    super.dispose();
  }

  // ============================================================
  //  BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final auth = context.watch<AuthProvider>();

    if (_lastAuthState != null && _lastAuthState != auth.isLoggedIn) {
      _phase = _LoadPhase.idle;
      _bannerLoading = true;
      _bannerImageReady = false;
      if (auth.isLoggedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadData();
        });
      }
    }
    _lastAuthState = auth.isLoggedIn;

    if (!auth.isLoggedIn && !auth.isLoading) {
      return _buildUnauthorizedScreen();
    }

    if (auth.isLoggedIn && _phase != _LoadPhase.loaded) {
      return Scaffold(
        backgroundColor: context.colors.surfaceAlt,
        body: _buildSkeleton(),
      );
    }

    final user = auth.user;
    final notifications = context.watch<NotificationProvider>();
    final rec = context.watch<ProfileRecommendationProvider>();
    final wishlist = context.watch<WishlistProvider>();
    final waitlist = context.watch<WaitlistProvider>();
    final name = user.name ?? '';
    final initials = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'К';
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              Theme.of(context).brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
          statusBarBrightness:
              Theme.of(context).brightness == Brightness.dark
                  ? Brightness.dark
                  : Brightness.light,
        ),
      child: Scaffold(
        backgroundColor: context.colors.surfaceAlt,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refreshAll,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: statusBarHeight + 72),
                    const SizedBox(height: 12),
                    _buildBonusAndCard(),
                    SizedBox(height: 12),
                    OrderPreview(key: _orderPreviewKey),
                    SizedBox(height: 12),
                    _buildStatsRow(wishlist.count, waitlist.count),
                    SizedBox(height: 16),
                    _buildBanner(),
                    SizedBox(height: 16),
                    _buildMenuSection(),
                    SizedBox(height: 20),
                    _buildViewedProductsRow(),
                    SizedBox(height: 20),
                    _buildLogoutButton(),
                    SizedBox(height: 20),
                    Padding(
                      padding: EdgeInsets.only(left: 12),
                      child: Text('Подобрали для вас',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary)),
                    ),
                    const SizedBox(height: 12),
                    _buildRecentlyViewed(rec),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildHeader(statusBarHeight, initials, name, notifications),
            Positioned(
              bottom: bottomPadding + 20,
              right: 40,
              child: ScrollToTopButton(
                scrollController: _scrollController,
                threshold: 500,
              ),
            ),
            Positioned.fill(
              child: RefreshOverlay(
                visible: _showRefreshOverlay,
                message: 'Обновляем профиль...',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  //  UI BUILDERS
  // ============================================================

  Widget _buildShimmerBox({double height = 100, double margin = 0}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: margin),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: const ProfileShimmerWidget(),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 72),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(child: _buildShimmerBox(height: 160)),
                const SizedBox(width: 10),
                Expanded(child: _buildShimmerBox(height: 160)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildShimmerBox(height: 140, margin: 12),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: List.generate(
                  3,
                  (_) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: _buildShimmerBox(height: 90),
                        ),
                      )),
            ),
          ),
          SizedBox(height: 16),
          _buildShimmerBox(height: 160, margin: 12),
          SizedBox(height: 16),
          _buildShimmerBox(height: 300, margin: 12),
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.only(left: 12),
            child: Text('Подобрали для вас',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const AdaptiveProductGridDelegate(
                crossAxisCount: 2,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
                contentHeight: 90,
              ),
              itemCount: 6,
              itemBuilder: (_, _) => const ProductCardSkeleton(),
            ),
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildUnauthorizedScreen() {
    return Scaffold(
      backgroundColor: context.colors.surfaceAlt,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.brand.withValues(alpha: 0.06),
                  ),
                  child: Icon(Icons.person_outline_rounded,
                      size: 36, color: context.colors.brand),
                ),
                SizedBox(height: 24),
                Text(
                  'Войдите в профиль',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                      letterSpacing: -0.3),
                ),
                SizedBox(height: 8),
                Text(
                  'Отслеживайте заказы, копите бонусы\nи сохраняйте любимые товары',
                  style: TextStyle(
                      fontSize: 14, color: context.colors.textMuted, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [context.colors.brand, context.colors.brandDark],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.brand.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () =>
                          MainShell.push(context, const LoginScreen()),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: const Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Войти или зарегистрироваться',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () async {
                        try {
                          await launchUrl(
                            Uri.parse('https://vk.ru/im?sel=-211300534'),
                            mode: LaunchMode.externalApplication,
                          );
                        } catch (_) {}
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Поддержка',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textSecondary,
                              ),
                              maxLines: 1,
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
      ),
    );
  }

  Widget _buildHeader(double topPadding, String initials, String name,
      NotificationProvider notifications) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(top: topPadding),
        child: GestureDetector(
          onTap: _openSettings,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: context.colors.brandLight,
                      borderRadius: BorderRadius.circular(14)),
                  child: Center(
                      child: Text(initials,
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: context.colors.brand))),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name.isNotEmpty ? name : 'Пользователь',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600,
                                color: context.colors.textPrimary)),
                        SizedBox(height: 2),
                        Text('Данные и настройки',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: context.colors.textMuted)),
                      ]),
                ),
                GestureDetector(
                  onTap: _openSupport,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Center(
                      child: SupportIconWithBadge(
                        size: 20,
                        padding: 0,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: _openNotifications,
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: context.colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12)),
                      child: Center(
                          child: SvgPicture.asset('assets/icons/kolokol.svg',
                              width: 20,
                              height: 20,
                              fit: BoxFit.contain,
                              colorFilter: ColorFilter.mode(
                                  context.colors.textPrimary, BlendMode.srcIn))),
                    ),
                    if (notifications.unreadCount > 0)
                      Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                              color: context.colors.brand, shape: BoxShape.circle),
                          constraints: const BoxConstraints(
                              minWidth: 18, minHeight: 18),
                          child: Center(
                              child: Text(
                                  notifications.unreadCount > 99
                                      ? '99+'
                                      : '${notifications.unreadCount}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700))),
                        ),
                      ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBonusAndCard() {
    final bonusProvider = context.watch<BonusProvider>();
    final expiringBatches = bonusProvider.expiringBatches;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 160,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                final auth = context.read<AuthProvider>();
                if (!auth.isLoggedIn) {
                  MainShell.push(context, LoginScreen());
                  return;
                }
                BonusHistoryPopup.show(context);
              },
              child: Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [context.colors.brand, context.colors.brandDark]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: context.colors.brand.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: SvgPicture.asset(
                                    'assets/icons/bonus-logo.svg',
                                    width: 18,
                                    height: 18))),
                        const Spacer(),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20)),
                            child: const Text('Бонусы',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600))),
                      ]),
                      const SizedBox(height: 12),
                      Text('${_displayBonus.toInt()}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1)),
                      const SizedBox(height: 4),
                      Text(
                          _pluralize(_displayBonus.toInt(), 'бонус',
                              'бонуса', 'бонусов'),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      Spacer(),
                      if (expiringBatches.isNotEmpty) ...[
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.local_fire_department,
                                  size: 14, color: Color(0xFFFF6B00)),
                              SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${expiringBatches.first['amount']} сгорят ${_formatExpiryDate(expiringBatches.first['expires_at'] ?? '')}',
                                  style: TextStyle(
                                      color: context.colors.textPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ]),
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: _openCardPopup,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: _cardStatus == 'Активна'
                      ? null
                      : Border.all(
                          color: _cardStatus == 'Ожидает активации'
                              ? Color(0xFFFF9800).withValues(alpha: 0.3)
                              : context.colors.border,
                          width: 1.5),
                ),
                child: _cardStatus == 'Активна'
                    ? _buildActiveCard()
                    : _buildInactiveCard(),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildActiveCard() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: QrImageView(
          data: _cardNumber.isNotEmpty ? _cardNumber : '0000',
          version: QrVersions.auto,
          size: 120,
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square, color: const Color(0xFF1A1A1A)),
          dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: const Color(0xFF1A1A1A)),
        ),
      ),
    );
  }

  Widget _buildInactiveCard() {
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(_cardStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _cardStatus == 'Ожидает активации'
                      ? Color(0xFFFF9800)
                      : context.colors.textMuted,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1)),
          SizedBox(height: 4),
          Text('Б-карта',
              style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ]);
  }

  Widget _buildStatsRow(int wishlistCount, int waitlistCount) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        Row(children: [
          Expanded(
              child: ProfileTabCard(
                  customIcon: CustomPaint(
                      size: Size(28, 25), painter: HeartPainter(color: context.colors.brand)),
                  count: wishlistCount,
                  label: 'Избранные',
                  onTap: () =>
                      _handleRestrictedAction(WishlistScreen()))),
          SizedBox(width: 8),
          Expanded(
              child: ProfileTabCard(
                  customIcon: CustomPaint(
                      size: Size(28, 26), painter: StarPainter(color: context.colors.brand)),
                  count: _toRateCount,
                  label: 'Ждут оценки',
                  onTap: () =>
                      _handleRestrictedAction(ReviewsScreen()))),
        ]),
        SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: ProfileTabCard(
                  customIcon: CustomPaint(
                      size: Size(24, 24),
                      painter: PurchasesIconPainter(color: context.colors.brand)),
                  count: _purchasesCount,
                  label: 'Куплено',
                  onTap: () =>
                      _handleRestrictedAction(PurchasesScreen()))),
          SizedBox(width: 8),
          Expanded(
              child: ProfileTabCard(
            customIcon: CustomPaint(
                size: Size(28, 28), painter: WaitlistIconPainter(color: context.colors.brand)),
            count: waitlistCount,
            label: 'Лист ожидания',
            onTap: () => _handleRestrictedAction(const WaitlistScreen()),
          )),
        ]),
      ]),
    );
  }

  Widget _buildBanner() {
    return ProfileBanner(
      bannerUrl: _profileBannerUrl,
      linkUrl: _bannerLinkUrl,
      isLoading: _bannerLoading,
      imageReady: _bannerImageReady,
      onTap: _onBannerTap,
    );
  }

  Widget _buildMenuSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
            color: context.colors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          ProfileMenuItem(
              title: 'Заказы',
              onTap: () => _handleRestrictedAction(const OrdersScreen())),
          const ProfileDivider(),
          ProfileMenuItem(
              title: 'Офлайн покупки',
              subtitle: 'Покупки в магазине',
              onTap: () =>
                  _handleRestrictedAction(const OfflinePurchasesScreen())),
          const ProfileDivider(),
          ProfileMenuItem(
              title: 'Купленные товары',
              subtitle: 'Все купленные товары в одном месте',
              onTap: () => _handleRestrictedAction(const PurchasesScreen())),
          const ProfileDivider(),
          ProfileMenuItem(
            title: 'Избранное',
            subtitle: '$_wishlistCount ${_pluralItems(_wishlistCount)}',
            onTap: () => _handleRestrictedAction(const WishlistScreen()),
          ),
          const ProfileDivider(),
          ProfileMenuItem(
            title: 'Лист ожидания',
            subtitle: '$_waitlistInStock из $_waitlistCount в наличии',
            onTap: () => _handleRestrictedAction(const WaitlistScreen()),
          ),
          const ProfileDivider(),
          ProfileMenuItem(
            title: 'Любимые бренды',
            subtitle:
                '${context.read<FavoriteBrandsProvider>().count} ${_pluralizeBrands(context.read<FavoriteBrandsProvider>().count)} добавлено',
            onTap: () =>
                _handleRestrictedAction(const FavoriteBrandsScreen()),
          ),
          const ProfileDivider(),
          ProfileMenuItem(
              title: 'Отзывы и вопросы',
              subtitle: 'Делитесь мнением и узнайте о товарах',
              onTap: () => _handleRestrictedAction(const ReviewsScreen())),
        ]),
      ),
    );
  }

  Widget _buildViewedProductsRow() {
    if (_viewedProducts.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 1) / 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: GestureDetector(
            onTap: () {
              _pauseViewedAutoScroll();
              _handleRestrictedAction(ViewedProductsScreen());
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Недавно смотрели',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary)),
                Text('Все ›',
                    style: TextStyle(
                        fontSize: 14, color: context.colors.textMuted)),
              ],
            ),
          ),
        ),
        SizedBox(
          height: cardWidth * 1.35 + 100,
          child: GestureDetector(
            onPanDown: (_) {
              _viewedUserInteracting = true;
              _pauseViewedAutoScroll();
            },
            child: PageView.builder(
              controller: _viewedPageController,
              physics: const ClampingScrollPhysics(),
              padEnds: false,
              itemCount: _viewedProducts.length,
              itemBuilder: (context, index) {
                final isFirst = index == 0;
                final isLast = index == _viewedProducts.length - 1;
                return Padding(
                  padding: EdgeInsets.only(
                    left: isFirst ? 0 : 0.5,
                    right: isLast ? 0 : 0.5,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ProductCard(product: _viewedProducts[index]),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        width: double.infinity,
        child: TextButton(
          onPressed: () async {
            await context.read<AuthProvider>().logout();
            if (mounted) {
              setState(() {
                _phase = _LoadPhase.idle;
                _bannerLoading = true;
                _bannerImageReady = false;
                _profileBannerUrl = null;
                _bannerLinkUrl = null;
                _viewedProducts = [];
                _viewedTimer?.cancel();
                _viewedAutoScrollEnabled = false;
              });
            }
          },
          child: Text('Выйти',
              style: TextStyle(color: context.colors.textMuted, fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildRecentlyViewed(ProfileRecommendationProvider rec) {
    if (rec.isLoading && rec.products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: const AdaptiveProductGridDelegate(
            crossAxisCount: 2,
            crossAxisSpacing: 1,
            mainAxisSpacing: 1,
            contentHeight: 90,
          ),
          itemCount: 6,
          itemBuilder: (_, _) => const ProductCardSkeleton(),
        ),
      );
    }
    if (rec.products.isEmpty && !rec.isLoading) {
      return Padding(
        padding: EdgeInsets.all(20),
        child: Center(
            child: Text('Нет рекомендаций',
                style: TextStyle(color: context.colors.textMuted))),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const AdaptiveProductGridDelegate(
        crossAxisCount: 2,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
        contentHeight: 90,
      ),
      itemCount: rec.products.length + (rec.hasMore ? 4 : 0),
      itemBuilder: (context, index) {
        if (index >= rec.products.length) return const ProductCardSkeleton();
        return ProductCard(product: rec.products[index]);
      },
    );
  }
}