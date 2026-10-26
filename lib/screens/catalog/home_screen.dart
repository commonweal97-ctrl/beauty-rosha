import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../providers/recommendation_provider.dart';
import '../../providers/banner_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/app_header.dart';
import '../../widgets/banner_carousel.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../../services/analytics_service.dart';
import '../../core/app_colors.dart';
import '../../core/adaptive_grid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  bool _wasPaused = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen('home');
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final rec = context.read<HomeRecommendationProvider>();
      if (!rec.isLoaded && !rec.isLoading) {
        rec.loadRecommendations();
      }
      context.read<BannerProvider>().loadBanners();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _wasPaused) {
      _wasPaused = false;
      if (mounted) {
        context.read<BannerProvider>().loadBanners(forceRefresh: true);
        context.read<HomeRecommendationProvider>().refresh();
      }
    } else if (state == AppLifecycleState.paused) {
      _wasPaused = true;
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 1000) {
      context.read<HomeRecommendationProvider>().loadRecommendations();
    }
    setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    final rec = context.read<HomeRecommendationProvider>();
    final bannerProvider = context.read<BannerProvider>();
    
    await Future.wait([
      rec.refresh(),
      bannerProvider.refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: context.colors.brandDark,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.colors.surface,
        body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: Consumer2<HomeRecommendationProvider, BannerProvider>(
                  builder: (context, rec, bannerProvider, _) {
                    if (rec.products.isEmpty && rec.isLoading) {
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 178),
                            const BannerSkeleton(),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Подобрали для вас',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ),
                            GridView.builder(
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
                          ],
                        ),
                      );
                    }
                    
                    return RefreshIndicator(
                      onRefresh: _handleRefresh,
                      child: CustomScrollView(
                        controller: _scrollController,
                          slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.only(top: 182),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                if (bannerProvider.hasBanners)
                                  RepaintBoundary(
                                    child: BannerCarousel(
                                      banners: bannerProvider.banners,
                                    ),
                                  )
                                else
                                  const BannerSkeleton(),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                                  child: Text(
                                    'Подобрали для вас',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: context.colors.textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                GridView.builder(
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
                                ),
                                const SizedBox(height: 80),
                              ]),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: 0, left: 0, right: 0,
                child: AppHeader(scrollOffset: _scrollController.hasClients ? _scrollController.offset : 0),
              ),
              Positioned(
                bottom: bottomPadding + 20,
                right: 40,
                child: ScrollToTopButton(
                  scrollController: _scrollController,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}