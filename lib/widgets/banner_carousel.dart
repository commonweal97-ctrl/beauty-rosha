// lib/widgets/banner_carousel.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/banner.dart';
import '../screens/catalog/catalog_screen.dart';
import '../screens/profile/profile_screen.dart';
import 'package:provider/provider.dart';
import '../../providers/catalog_provider.dart';

class BannerCarousel extends StatefulWidget {
  final List<BannerItem> banners;
  const BannerCarousel({super.key, required this.banners});

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
    _currentPage = 1;
    
    if (widget.banners.length > 1) {
      Future.delayed(const Duration(seconds: 3), _autoScroll);
    }
  }

  @override
  void didUpdateWidget(BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length ||
        oldWidget.banners.hashCode != widget.banners.hashCode) {
      _currentPage = 1;
      _pageController.dispose();
      _pageController = PageController(initialPage: 1);
      if (widget.banners.length > 1) {
        Future.delayed(const Duration(seconds: 3), _autoScroll);
      }
    }
  }

    void _autoScroll() {
    if (!mounted || !_pageController.hasClients) return;
    
    _currentPage++;
    
    _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    ).then((_) {
      // 🔥 Проверяем, что PageController всё ещё прикреплён
      if (!mounted || !_pageController.hasClients) return;
      
      if (_currentPage >= widget.banners.length + 1) {
        _currentPage = 1;
        _pageController.jumpToPage(_currentPage);
      }
    });
    
    Future.delayed(const Duration(seconds: 3), _autoScroll);
  }

  int _getRealIndex(int pageIndex) {
    if (widget.banners.isEmpty) return 0;
    if (pageIndex == 0) return widget.banners.length - 1;
    if (pageIndex >= widget.banners.length + 1) return 0;
    return pageIndex - 1;
  }

  void _onBannerTap(BannerItem banner) {
    final linkUrl = banner.linkUrl;
    if (linkUrl == null || linkUrl.isEmpty) return;

    final uri = Uri.tryParse(linkUrl);
    if (uri == null) return;

    final host = uri.host.toLowerCase();
    final isOurSite = host.contains('бьютироща.рф') || 
                      host.contains('xn--80abvyjk6cts') ||
                      host.contains('%d0%b1%d1%8c%d1%8e%d1%82%d0%b8%d1%80%d0%be%d1%89%d0%b0.%d1%80%d1%84') ||
                      host.isEmpty;

    if (!isOurSite) {
      _openExternalLink(linkUrl);
      return;
    }

    final fragment = uri.fragment;
    final path = uri.path;

    if (path == '/profile' && fragment.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileScreen(initialTab: fragment),
        ),
      );
      return;
    }

    if (path == '/profile') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
        ),
      );
      return;
    }

    final params = uri.queryParameters;
    
    int? categoryId;
    String? sort;
    String? search;
    String? brand;

    if (params['category'] != null) {
      categoryId = int.tryParse(params['category']!);
    }
    
    if (params['sort'] != null) {
      sort = params['sort'];
    }
    
    if (params['search'] != null) {
      search = params['search'];
    }
    
    if (params['brand'] != null) {
      brand = params['brand'];
    }

    final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (pathSegments.length >= 2 && pathSegments[0] == 'catalog') {
      final pathId = int.tryParse(pathSegments[1]);
      if (pathId != null) {
        categoryId = pathId;
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CatalogProvider(),
          child: CatalogScreen(
            initialCategoryId: categoryId,
            initialSort: sort,
            searchQuery: search,
            initialBrand: brand,
          ),
        ),
      ),
    );
  } // 🔥 Закрывающая скобка метода _onBannerTap

  Future<void> _openExternalLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    if (widget.banners.length == 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 160,
            child: GestureDetector(
              onTap: () => _onBannerTap(widget.banners[0]),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: widget.banners[0].fullImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: Colors.grey[200]),
                    errorWidget: (_, _, _) => Container(color: Colors.grey[200]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (page) {
              if (mounted) {
                setState(() => _currentPage = page);
              }
            },
            itemCount: widget.banners.length + 2,
            itemBuilder: (context, index) {
              final realIndex = _getRealIndex(index);
              final banner = widget.banners[realIndex];
              return GestureDetector(
                onTap: () => _onBannerTap(banner),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: banner.fullImageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => Container(color: Colors.grey[200]),
                      errorWidget: (_, _, _) => Container(color: Colors.grey[200]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}