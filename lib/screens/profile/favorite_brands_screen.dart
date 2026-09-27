// lib/screens/profile/favorite_brands_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_logger.dart';
import '../../providers/favorite_brands_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/image_loader.dart';
import '../catalog/catalog_screen.dart';

class FavoriteBrandsScreen extends StatefulWidget {
  const FavoriteBrandsScreen({super.key});

  @override
  State<FavoriteBrandsScreen> createState() => _FavoriteBrandsScreenState();
}

class _FavoriteBrandsScreenState extends State<FavoriteBrandsScreen> {
  static const _logTag = 'FavoriteBrandsScreen';

  List<Map<String, dynamic>> _brands = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 1;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _loadBrands();
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(_onScrollForTopButton);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onScrollForTopButton() {
    final show =
        _scrollController.hasClients && _scrollController.offset > 300;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  Future<void> _refresh() async {
    ApiService.invalidateCache(prefix: '/api/favorite-brands/');
    ApiService.invalidateCache(prefix: '/api/brands');

    setState(() {
      _brands = [];
      _page = 1;
      _hasMore = true;
      _isLoading = true;
    });

    await _loadBrands();
  }

  Future<void> _loadBrands() async {
    final result = await ApiService.getFavoriteBrands(page: _page);

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadBrands(page=$_page) failed: '
            '${result.errorOrNull?.message}',
      );
      setState(() => _isLoading = false);
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      setState(() => _isLoading = false);
      return;
    }

    final itemsRaw = data['items'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((i) => Map<String, dynamic>.from(i))
            .toList()
        : <Map<String, dynamic>>[];

    final brandIds = items
        .map<int?>((b) {
          final id = b['id'];
          if (id is int) return id;
          if (id is String) return int.tryParse(id);
          return null;
        })
        .whereType<int>()
        .toList();

    if (brandIds.isNotEmpty) {
      context.read<FavoriteBrandsProvider>().checkBatch(brandIds);
    }

    setState(() {
      _brands = items;
      _hasMore = data['has_more'] ?? false;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;
    _page++;

    final result = await ApiService.getFavoriteBrands(page: _page);

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadMore(page=$_page) failed: ${result.errorOrNull?.message}',
      );
      _page--;
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      _page--;
      return;
    }

    final itemsRaw = data['items'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((i) => Map<String, dynamic>.from(i))
            .toList()
        : <Map<String, dynamic>>[];

    setState(() {
      _brands.addAll(items);
      _hasMore = data['has_more'] ?? false;
    });
  }

  String _pluralItems(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'товар';
    if ([2, 3, 4].contains(m10) && ![12, 13, 14].contains(m100)) {
      return 'товара';
    }
    return 'товаров';
  }

  String _pluralNew(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'новинка';
    if ([2, 3, 4].contains(m10) && ![12, 13, 14].contains(m100)) {
      return 'новинки';
    }
    return 'новинок';
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: topPadding + 48),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    color: const Color(0xFFDD1847),
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFDD1847),
                            ),
                          )
                        : _brands.isEmpty
                            ? Center(
                                child: ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 200),
                                    Icon(
                                      Icons.favorite_border,
                                      size: 48,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Нет любимых брендов',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF999999),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Добавляйте бренды в избранное через поиск',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFFBBBBBB),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  0,
                                  12,
                                  0,
                                  100,
                                ),
                                itemCount: _brands.length,
                                itemBuilder: (context, index) =>
                                    _buildBrandCard(_brands[index]),
                              ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: Container(
                padding: EdgeInsets.only(top: topPadding, bottom: 4),
                color: Colors.white,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFFFF2E6E),
                        size: 22,
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Любимые бренды',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: bottomPadding > 0 ? bottomPadding + 90 : 106,
            right: 20,
            child: AnimatedOpacity(
              opacity: _showScrollToTop ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: AnimatedSlide(
                offset:
                    _showScrollToTop ? Offset.zero : const Offset(0, 0.5),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: GestureDetector(
                  onTap: _scrollToTop,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFDD1847).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFFDD1847).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_up,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandCard(Map<String, dynamic> brand) {
    final name = brand['name'] ?? '';
    final logoUrl = brand['logo_url'] ?? '';
    final totalProducts = brand['total_products'] as int? ?? 0;
    final inStockProducts = brand['in_stock_products'] as int? ?? 0;
    final newProducts = brand['new_products'] as int? ?? 0;
    final brandId = brand['id'] as int?;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CatalogScreen(initialBrand: name),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: logoUrl.isNotEmpty
                  ? ImageLoader(
                      imageUrl: logoUrl,
                      width: 48,
                      height: 48,
                      borderRadius: 10,
                      errorIcon: Icons.business,
                      errorIconSize: 20,
                    )
                  : Center(
                      child: Text(
                        name.isNotEmpty
                            ? name
                                .substring(0, min(2, name.length))
                                .toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$inStockProducts/$totalProducts '
                    '${_pluralItems(totalProducts)} в наличии',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF999999),
                    ),
                  ),
                  if (newProducts > 0)
                    Text(
                      '$newProducts ${_pluralNew(newProducts)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                ],
              ),
            ),
            if (brandId != null)
              Consumer<FavoriteBrandsProvider>(
                builder: (context, favProvider, _) {
                  final isFav = favProvider.isFavorite(brandId);
                  return GestureDetector(
                    onTap: () => favProvider.toggle(brandId),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isFav
                            ? const Color(0xFFFFE4E9)
                            : const Color(0xFFF5F5F5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        size: 18,
                        color: isFav
                            ? const Color(0xFFDD1847)
                            : const Color(0xFFCCCCCC),
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right,
              size: 22,
              color: Color(0xFFCCCCCC),
            ),
          ],
        ),
      ),
    );
  }
}