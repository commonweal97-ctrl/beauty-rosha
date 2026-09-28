// lib/screens/catalog/catalog_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_logger.dart';
import '../../models/brand.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/favorite_brands_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/api_service.dart';
import '../../widgets/image_loader.dart';
import '../../widgets/product_card.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'search_screen.dart';

class CatalogScreen extends StatefulWidget {
  final int? initialCategoryId;
  final String? initialBrand;
  final String? initialSort;
  final String? searchQuery;
  final bool fromMenu;

  const CatalogScreen({
    super.key,
    this.initialCategoryId,
    this.initialBrand,
    this.initialSort,
    this.searchQuery,
    this.fromMenu = false,
  });

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  static const _logTag = 'CatalogScreen';

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _priceFromController = TextEditingController();
  final TextEditingController _priceToController = TextEditingController();
  List<Product> _alsoProducts = [];
  bool _alsoLoading = false;
  bool _alsoHasMore = true;
  int _alsoPage = 1;
  int? _brandId;
  String? _brandLogo;

  Future<void> _loadBrandId(String brandName) async {
    final result = await ApiService.get('/api/brands');

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadBrandId failed: ${result.errorOrNull?.message}',
      );
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! List) return;

    for (final b in data.whereType<Map>()) {
      if (b['name'].toString().toLowerCase() == brandName.toLowerCase()) {
        final id = b['id'];
        final brandId =
            id is int ? id : int.tryParse(id?.toString() ?? '');
        if (!mounted) return;
        setState(() => _brandId = brandId);
        if (brandId != null) {
          context.read<FavoriteBrandsProvider>().checkBatch([brandId]);
        }
        return;
      }
    }
  }

  Future<void> _loadBrandLogo(String brandName) async {
    final result = await ApiService.get('/api/brands');

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadBrandLogo failed: ${result.errorOrNull?.message}',
      );
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! List) return;

    for (final b in data.whereType<Map>()) {
      if (b['name'].toString().toLowerCase() == brandName.toLowerCase()) {
        final logo = (b['logo_url'] ?? b['image_url'] ?? '').toString();
        final id = b['id'];
        final brandId =
            id is int ? id : int.tryParse(id?.toString() ?? '');
        if (!mounted || logo.isEmpty) return;
        setState(() {
          _brandLogo = logo;
          if (brandId != null) _brandId = brandId;
        });
        return;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen('catalog');
    final catalog = context.read<CatalogProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialCategoryId != null) {
        catalog.loadWithParams(
          context,
          categoryId: widget.initialCategoryId,
        );
      } else if (widget.initialBrand != null) {
        catalog.loadWithParams(context, brand: widget.initialBrand);
        _loadBrandId(widget.initialBrand!);
        _loadBrandLogo(widget.initialBrand!);
      } else {
        catalog.loadProducts(context);
        catalog.loadCategories();
        catalog.loadBrands();
      }

      if (widget.initialSort != null) {
        catalog.setSort(widget.initialSort!);
        catalog.refreshProducts();
      }

      if (catalog.stock == 'all') {
        catalog.setStock('in_stock');
      }
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (currentScroll >= maxScroll - 1000) {
      final catalog = context.read<CatalogProvider>();

      if (catalog.isLoading || _alsoLoading) return;

      if (catalog.hasMore) {
        catalog.loadProducts(context);
      } else if (catalog.products.isNotEmpty && _alsoHasMore) {
        _loadAlsoProducts();
      }
    }
  }

  Future<void> _loadAlsoProducts() async {
    if (_alsoLoading || !_alsoHasMore) return;

    _alsoLoading = true;
    if (mounted) setState(() {});

    try {
      final catalog = context.read<CatalogProvider>();

      final existingIds = <int>{};
      existingIds.addAll(catalog.products.map((p) => p.id));
      existingIds.addAll(_alsoProducts.map((p) => p.id));

      List<Product> newProducts = [];
      bool hasMoreFromApi = true;

      if (_alsoPage == 1) {
        final firstProductId = catalog.products.isNotEmpty
            ? catalog.products.first.id
            : null;

        if (firstProductId != null) {
          final rec = context.read<HomeRecommendationProvider>();
          final similarProducts =
              await rec.loadSimilarProducts(firstProductId);

          newProducts = similarProducts
              .where((p) => !existingIds.contains(p.id))
              .toList();
        }

        _alsoPage = 2;
        hasMoreFromApi = true;
      } else {
        final apiPage = _alsoPage - 1;

        final result = await ApiService.get(
          '/api/recommendations/user',
          queryParams: {
            'page': apiPage.toString(),
            'limit': '24',
          },
        );

        if (!mounted) return;

        if (result.isFailure) {
          AppLogger.warning(
            _logTag,
            'loadAlsoProducts(page=$apiPage) failed: '
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

      setState(() {
        _alsoProducts.addAll(newProducts);
        _alsoLoading = false;

        if (newProducts.isNotEmpty) {
          _alsoPage++;
        } else if (_alsoPage == 2) {
          _alsoPage++;
          _alsoHasMore = true;
        } else {
          _alsoHasMore = hasMoreFromApi;
        }
      });
    } catch (e, st) {
      AppLogger.error(_logTag, 'loadAlsoProducts failed', e, st);
      if (!mounted) return;
      setState(() {
        _alsoLoading = false;
        _alsoHasMore = false;
      });
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

  void _resetAlsoProducts() {
    setState(() {
      _alsoProducts = [];
      _alsoPage = 1;
      _alsoHasMore = true;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _priceFromController.dispose();
    _priceToController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showSortSheet() {
    final catalog = context.read<CatalogProvider>();
    final sorts = [
      {'key': 'popular', 'label': 'Популярные'},
      {'key': 'price_asc', 'label': 'Дешевле'},
      {'key': 'price_desc', 'label': 'Дороже'},
      {'key': 'newest', 'label': 'Новинки'},
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Какие товары показывать сначала',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            ...sorts.map(
              (s) => _buildSortOption(
                s['label']!,
                catalog.sort == s['key'],
                () {
                  Navigator.pop(ctx);
                  catalog.setSort(s['key']!);
                  _resetAlsoProducts();
                  _scrollToTop();
                  catalog.loadProducts(context, refresh: true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.brandLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? context.colors.brand
                      : context.colors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: context.colors.brand,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showPriceSheet() {
    final catalog = context.read<CatalogProvider>();
    _priceFromController.text = catalog.priceFrom?.toString() ?? '';
    _priceToController.text = catalog.priceTo?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Цена, ₽',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child:
                      _buildPriceInput('От', _priceFromController),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '—',
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 18,
                    ),
                  ),
                ),
                Expanded(child: _buildPriceInput('До', _priceToController)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (catalog.priceFrom != null ||
                    catalog.priceTo != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        catalog.setPriceRange(null, null);
                        _resetAlsoProducts();
                        _scrollToTop();
                        catalog.loadProducts(context, refresh: true);
                      },
                      style: OutlinedButton.styleFrom(
                        padding:
                            EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: context.colors.border),
                      ),
                      child: Text(
                        'Сбросить',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                if (catalog.priceFrom != null ||
                    catalog.priceTo != null)
                  SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final from =
                          double.tryParse(_priceFromController.text);
                      final to =
                          double.tryParse(_priceToController.text);
                      Navigator.pop(ctx);
                      catalog.setPriceRange(from, to);
                      _resetAlsoProducts();
                      _scrollToTop();
                      catalog.loadProducts(context, refresh: true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Применить',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showBrandSheet() {
    final catalog = context.read<CatalogProvider>();
    final brands = catalog.brandsList;
    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          List<Brand> filteredBrands = List.from(brands);

          return GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Container(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: () {},
                child: DraggableScrollableSheet(
                  initialChildSize: 0.7,
                  minChildSize: 0.4,
                  maxChildSize: 0.95,
                  builder: (ctx, scrollController) => Container(
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding:
                              EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Column(
                            children: [
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: context.colors.border,
                                    borderRadius:
                                        BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Бренд',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                              ),
                              SizedBox(height: 12),
                              Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: context.colors.surfaceAlt,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: TextField(
                                  controller: searchController,
                                  onChanged: (val) => setSheetState(() {
                                    filteredBrands = val.isEmpty
                                        ? List.from(brands)
                                        : brands
                                            .where((b) => b.name
                                                .toLowerCase()
                                                .contains(
                                                  val.toLowerCase(),
                                                ))
                                            .toList();
                                  }),
                                  decoration: InputDecoration(
                                    hintText: 'Поиск бренда...',
                                    hintStyle: TextStyle(
                                      color: context.colors.textDisabled,
                                      fontSize: 14,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: context.colors.textDisabled,
                                      size: 20,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding:
                                        EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                            ],
                          ),
                        ),
                        Expanded(
                          child: filteredBrands.isEmpty
                              ? Center(
                                  child: Text(
                                    'Бренды не найдены',
                                    style: TextStyle(
                                      color: context.colors.textMuted,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: scrollController,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  itemCount: filteredBrands.length + 1,
                                  itemBuilder: (_, i) {
                                    if (i == 0) {
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: ListTile(
                                            leading: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: catalog.brand == null
                                                    ? context.colors.brand
                                                    : context.colors.surfaceAlt,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  12,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.grid_view,
                                                size: 20,
                                                color: catalog.brand == null
                                                    ? Colors.white
                                                    : context.colors.textMuted,
                                              ),
                                            ),
                                            title: Text(
                                              'Все бренды',
                                              style: TextStyle(
                                                fontWeight:
                                                    catalog.brand == null
                                                        ? FontWeight.w700
                                                        : FontWeight.w500,
                                                fontSize: 15,
                                              ),
                                            ),
                                            trailing:
                                                catalog.brand == null
                                                    ? Icon(
                                                        Icons.check,
                                                        color: context.colors.brand,
                                                      )
                                                    : null,
                                            onTap: () {
                                              Navigator.pop(ctx);
                                              catalog.setBrand(null);
                                              _resetAlsoProducts();
                                              _scrollToTop();
                                              catalog.loadProducts(
                                                context,
                                                refresh: true,
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                    final brand = filteredBrands[i - 1];
                                    final isSelected =
                                        catalog.brand == brand.name;
                                    return Material(
                                      color: Colors.transparent,
                                      child: ListTile(
                                        leading: Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: context.colors.surface,
                                            borderRadius:
                                                BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Center(
                                            child: brand.logoUrl != null &&
                                                    brand.logoUrl!
                                                        .isNotEmpty
                                                ? ImageLoader(
                                                    imageUrl:
                                                        brand.logoUrl,
                                                    width: 32,
                                                    height: 32,
                                                    borderRadius: 8,
                                                    errorIcon:
                                                        Icons.business,
                                                    errorIconSize: 12,
                                                  )
                                                : Text(
                                                    brand.name.isNotEmpty
                                                        ? brand.name
                                                            .substring(
                                                            0,
                                                            min(
                                                              2,
                                                              brand.name
                                                                  .length,
                                                            ),
                                                          )
                                                            .toUpperCase()
                                                        : '?',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: isSelected
                                                          ? context.colors.brand
                                                          : context.colors.textMuted,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        title: Text(
                                          brand.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: isSelected
                                                ? context.colors.brand
                                                : context.colors.textPrimary,
                                          ),
                                        ),
                                        trailing: isSelected
                                            ? Icon(
                                                Icons.check,
                                                color: context.colors.brand,
                                              )
                                            : null,
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          catalog.setBrand(brand.name);
                                          _resetAlsoProducts();
                                          _scrollToTop();
                                          catalog.loadProducts(
                                            context,
                                            refresh: true,
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showStockSheet() {
    final catalog = context.read<CatalogProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Наличие',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildStockOption('Все товары', 'all', catalog.stock, () {
              Navigator.pop(ctx);
              catalog.setStock('all');
              _resetAlsoProducts();
              _scrollToTop();
              catalog.loadProducts(context, refresh: true);
            }),
            _buildStockOption('В наличии', 'in_stock', catalog.stock, () {
              Navigator.pop(ctx);
              catalog.setStock('in_stock');
              _resetAlsoProducts();
              _scrollToTop();
              catalog.loadProducts(context, refresh: true);
            }),
            _buildStockOption(
              'Нет в наличии',
              'out_of_stock',
              catalog.stock,
              () {
                Navigator.pop(ctx);
                catalog.setStock('out_of_stock');
                _resetAlsoProducts();
                _scrollToTop();
                catalog.loadProducts(context, refresh: true);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildStockOption(
    String label,
    String value,
    String current,
    VoidCallback onTap,
  ) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.brandLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? context.colors.brand
                      : context.colors.textPrimary,
                ),
              ),
            ),
            if (isSelected)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: context.colors.brand,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCategorySheet() async {
    final catalog = context.read<CatalogProvider>();
    if (catalog.categories.isEmpty) {
      await catalog.loadCategories();
    }
    if (!mounted) return;

    List<Category> filteredCategories = catalog.categories;
    if (catalog.brand != null && catalog.brand!.isNotEmpty) {
      final result = await ApiService.get(
        '/api/categories',
        queryParams: {'brand': catalog.brand},
      );

      if (!mounted) return;

      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'loadCategories(brand) failed: ${result.errorOrNull?.message}',
        );
      } else {
        final data = result.valueOrNull?['data'];
        if (data is List) {
          filteredCategories = data
              .whereType<Map>()
              .map((c) => Category.fromJson(Map<String, dynamic>.from(c)))
              .toList();
        }
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (ctx) => _CategorySheetContent(
        currentCategoryId: catalog.categoryId,
        allCategories: filteredCategories,
        onSelect: (categoryId) {
          Navigator.pop(ctx);
          catalog.setCategory(categoryId);
          _resetAlsoProducts();
          _scrollToTop();
          catalog.loadProducts(context, refresh: true);
        },
      ),
    );
  }

  void _showFiltersSheet() {
    final catalog = context.read<CatalogProvider>();
    final brands = catalog.brandsList;
    List<Category> categories = catalog.categories;
    _priceFromController.text = catalog.priceFrom?.toString() ?? '';
    _priceToController.text = catalog.priceTo?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (ctx, scrollController) => Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.all(20),
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Все фильтры',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
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
                  SizedBox(height: 24),
                  if (categories.isNotEmpty) ...[
                    Text(
                      'Категория',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _showCategorySheet();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                catalog.categoryId != null
                                    ? categories
                                        .firstWhere(
                                          (c) =>
                                              c.id == catalog.categoryId,
                                          orElse: () => categories.first,
                                        )
                                        .name
                                    : 'Все категории',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: catalog.categoryId != null
                                      ? context.colors.textPrimary
                                      : context.colors.textMuted,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down,
                              color: context.colors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                  ],
                  Text(
                    'Наличие',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildFilterOption(
                        'Все',
                        'all',
                        catalog.stock,
                        () {
                          setSheetState(() {
                            catalog.setStock('all');
                          });
                        },
                      ),
                      _buildFilterOption(
                        'В наличии',
                        'in_stock',
                        catalog.stock,
                        () {
                          setSheetState(() {
                            catalog.setStock('in_stock');
                          });
                        },
                      ),
                      _buildFilterOption(
                        'Нет в наличии',
                        'out_of_stock',
                        catalog.stock,
                        () {
                          setSheetState(() {
                            catalog.setStock('out_of_stock');
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Text(
                    'Цена, ₽',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPriceInput(
                          'От',
                          _priceFromController,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '—',
                          style: TextStyle(color: context.colors.textMuted),
                        ),
                      ),
                      Expanded(
                        child:
                            _buildPriceInput('До', _priceToController),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final from =
                            double.tryParse(_priceFromController.text);
                        final to =
                            double.tryParse(_priceToController.text);
                        catalog.setPriceRange(from, to);
                        setSheetState(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Применить цену',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  if (brands.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Бренд',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setSheetState(() {
                              catalog.setBrand(null);
                            });
                          },
                          child: Text(
                            'Сбросить',
                            style: TextStyle(
                              color: context.colors.brand,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Container(
                      height: 44,
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Поиск бренда...',
                          hintStyle: TextStyle(
                            color: context.colors.textDisabled,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: context.colors.textDisabled,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (val) {
                          setSheetState(() {});
                        },
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBrandChip(
                          'Все бренды',
                          null,
                          catalog.brand,
                          () {
                            setSheetState(() {
                              catalog.setBrand(null);
                            });
                          },
                        ),
                        ...brands.map(
                          (brand) => _buildBrandChip(
                            brand.name,
                            brand.logoUrl,
                            catalog.brand,
                            () {
                              setSheetState(() {
                                catalog.setBrand(brand.name);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            catalog.resetFilters();
                            catalog.setStock('in_stock');
                            setSheetState(() {});
                          },
                          style: OutlinedButton.styleFrom(
                            padding:
                                EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(color: context.colors.border),
                          ),
                          child: Text(
                            'Сбросить',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            final from =
                                double.tryParse(_priceFromController.text);
                            final to =
                                double.tryParse(_priceToController.text);
                            catalog.setPriceRange(from, to);
                            _resetAlsoProducts();
                            _scrollToTop();
                            catalog.loadProducts(context, refresh: true);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colors.brand,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Применить',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterOption(
    String label,
    String value,
    String current,
    VoidCallback onTap,
  ) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.brand
              : context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? Colors.white
                : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildBrandChip(
    String name,
    String? logoUrl,
    String? selectedBrand,
    VoidCallback onTap,
  ) {
    final isSelected = selectedBrand == name ||
        (name == 'Все бренды' && selectedBrand == null);
    final initials = name == 'Все бренды'
        ? '⊕'
        : name.isNotEmpty
            ? name.substring(0, 2).toUpperCase()
            : '?';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.brandLight
              : context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? context.colors.brand
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: logoUrl != null && logoUrl.isNotEmpty
                    ? ImageLoader(
                        imageUrl: logoUrl,
                        width: 24,
                        height: 24,
                        borderRadius: 6,
                        errorIcon: Icons.business,
                        errorIconSize: 12,
                      )
                    : Text(
                        initials,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? context.colors.brand
                              : context.colors.textMuted,
                        ),
                      ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? context.colors.brand
                    : context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceInput(
    String label,
    TextEditingController controller,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: context.colors.textMuted),
        filled: true,
        fillColor: context.colors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        isDense: true,
      ),
    );
  }

  String _getTitle(CatalogProvider catalog) {
    return catalog.categoryName;
  }

  String _pluralItems(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'товар';
    if ([2, 3, 4].contains(m10) && ![12, 13, 14].contains(m100)) {
      return 'товара';
    }
    return 'товаров';
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final hasBrand = catalog.brand != null && catalog.brand!.isNotEmpty;

    String? brandLogo;
    int? brandId;
    if (hasBrand) {
      brandId = _brandId;
      brandLogo = _brandLogo;

      if (brandLogo == null || brandLogo.isEmpty) {
        for (final b in catalog.brandsList) {
          if (b.name == catalog.brand) {
            brandLogo = b.logoUrl;
            brandId ??= b.id;
            break;
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: hasBrand
            ? SizedBox.shrink()
            : Text(
                _getTitle(catalog),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        centerTitle: true,
        backgroundColor: context.colors.brand,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.swap_vert, color: Colors.white),
            onPressed: _showSortSheet,
          ),
          IconButton(
            icon: Icon(Icons.tune, color: Colors.white),
            onPressed: () => _showFiltersSheet(),
          ),
        ],
        bottom: hasBrand
            ? PreferredSize(
                preferredSize: Size.fromHeight(52),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SearchScreen(
                              initialQuery: catalog.brand,
                              initialBrand: catalog.brand,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        children: [
                          SizedBox(width: 12),
                          Icon(
                            Icons.search,
                            color: context.colors.textMuted,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              catalog.brand!,
                              style: TextStyle(
                                color: context.colors.textPrimary,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Container(
                  color: context.colors.background,
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      if (catalog.products.isEmpty && catalog.isLoading)
                        SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: context.colors.brand,
                            ),
                          ),
                        )
                      else ...[
                        SliverToBoxAdapter(
                          child: SizedBox(height: 12),
                        ),
                        if (hasBrand) ...[
                          SliverToBoxAdapter(
                            child: Consumer<FavoriteBrandsProvider>(
                              builder: (context, favProvider, _) {
                                final isFav = brandId != null
                                    ? favProvider.isFavorite(brandId)
                                    : false;
                                return Container(
                                  margin: EdgeInsets.symmetric(
                                    horizontal: 0,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.surface,
                                    borderRadius:
                                        BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 42,
                                        height: 42,
                                        decoration: BoxDecoration(
                                          color: context.colors.surfaceAlt,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: brandLogo != null &&
                                                brandLogo.isNotEmpty
                                            ? ImageLoader(
                                                imageUrl: brandLogo,
                                                width: 42,
                                                height: 42,
                                                borderRadius: 8,
                                                errorIcon:
                                                    Icons.business,
                                                errorIconSize: 16,
                                              )
                                            : Center(
                                                child: Text(
                                                  catalog.brand!.isNotEmpty
                                                      ? catalog.brand!
                                                          .substring(
                                                          0,
                                                          min(
                                                            2,
                                                            catalog
                                                                .brand!
                                                                .length,
                                                          ),
                                                        )
                                                          .toUpperCase()
                                                      : '?',
                                                  style:
                                                      TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: context.colors.textMuted,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          children: [
                                            Text(
                                              catalog.brand!,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight:
                                                    FontWeight.w600,
                                                color: context.colors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              '${catalog.total} '
                                              '${_pluralItems(catalog.total)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: context.colors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (brandId != null)
                                        GestureDetector(
                                          onTap: () => favProvider
                                              .toggle(brandId!),
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: isFav
                                                  ? context.colors.brandLight
                                                  : context.colors.surfaceAlt,
                                              shape: BoxShape.circle,
                                            ),
                                            child:
                                                favProvider.isLoading(
                                              brandId,
                                            )
                                                    ? SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child:
                                                            CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: context.colors.brand,
                                                        ),
                                                      )
                                                    : Icon(
                                                        isFav
                                                            ? Icons.favorite
                                                            : Icons
                                                                .favorite_border,
                                                        size: 18,
                                                        color: isFav
                                                            ? context.colors.brand
                                                            : context.colors.textDisabled,
                                                      ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 8),
                          ),
                        ],
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics:
                                  const ClampingScrollPhysics(),
                              child: Row(
                                children: [
                                  _buildFilterChip(
                                    'Цена',
                                    catalog.priceFrom != null ||
                                        catalog.priceTo != null,
                                    _showPriceSheet,
                                  ),
                                  const SizedBox(width: 8),
                                  if (!hasBrand) ...[
                                    _buildFilterChip(
                                      'Бренд',
                                      catalog.brand != null,
                                      _showBrandSheet,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  _buildFilterChip(
                                    'Категория',
                                    catalog.categoryId != null,
                                    _showCategorySheet,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    'Наличие',
                                    catalog.stock != 'all',
                                    _showStockSheet,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (catalog.products.isEmpty &&
                            !catalog.isLoading)
                          SliverFillRemaining(
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 64,
                                    color: context.colors.border,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'Товары не найдены',
                                    style: TextStyle(
                                      color: context.colors.textMuted,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Попробуйте изменить фильтры',
                                    style: TextStyle(
                                      color: context.colors.textDisabled,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else ...[
                          SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.54,
                              crossAxisSpacing: 1,
                              mainAxisSpacing: 1,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (ctx, index) {
                                if (index >= catalog.products.length) {
                                  if (!catalog.hasMore) return null;
                                  return ProductCardSkeleton();
                                }
                                return ProductCard(
                                  product: catalog.products[index],
                                );
                              },
                              childCount: catalog.products.length +
                                  (catalog.hasMore ? 4 : 0),
                            ),
                          ),
                          if (!catalog.hasMore &&
                              catalog.products.isNotEmpty) ...[
                            SliverToBoxAdapter(
                              child: Container(
                                color: context.colors.background,
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  24,
                                  16,
                                  12,
                                ),
                                child: Text(
                                  'Смотрите также',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            SliverGrid(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.54,
                                crossAxisSpacing: 1,
                                mainAxisSpacing: 1,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (ctx, index) {
                                  if (index >= _alsoProducts.length) {
                                    if (!_alsoHasMore && !_alsoLoading) {
                                      return null;
                                    }
                                    return const ProductCardSkeleton();
                                  }
                                  return ProductCard(
                                    product: _alsoProducts[index],
                                  );
                                },
                                childCount: _alsoProducts.length +
                                    (_alsoHasMore || _alsoLoading ? 4 : 0),
                              ),
                            ),
                          ],
                        ],
                        SliverToBoxAdapter(
                          child: SizedBox(height: 100 + bottomPadding),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
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
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isActive,
    VoidCallback onTap,
  ) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color:
                isActive ? context.colors.brand : context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? context.colors.brand
                  : context.colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color:
                      isActive ? Colors.white : context.colors.textSecondary,
                ),
              ),
              SizedBox(width: 4),
              Icon(
                isActive ? Icons.close : Icons.keyboard_arrow_down,
                size: 16,
                color: isActive ? Colors.white : context.colors.textMuted,
              ),
            ],
          ),
        ),
      );
}

class _CategorySheetContent extends StatefulWidget {
  final int? currentCategoryId;
  final List<Category> allCategories;
  final Function(int?) onSelect;

  const _CategorySheetContent({
    required this.currentCategoryId,
    required this.allCategories,
    required this.onSelect,
  });

  @override
  State<_CategorySheetContent> createState() => _CategorySheetContentState();
}

class _CategorySheetContentState extends State<_CategorySheetContent> {
  static const _logTag = 'CategorySheet';

  final TextEditingController _searchController = TextEditingController();
  final Map<int, List<Category>> _subcategoriesCache = {};
  final Map<int, bool> _loadingSubcategories = {};
  List<Category> _filteredCategories = [];
  final Map<int, bool> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _filteredCategories = widget.allCategories;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredCategories = widget.allCategories;
      } else {
        _filteredCategories = widget.allCategories
            .where((cat) => cat.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _toggleExpand(int parentId) async {
    if (_subcategoriesCache.containsKey(parentId)) {
      setState(() {
        _expandedCategories[parentId] =
            !(_expandedCategories[parentId] ?? false);
      });
      return;
    }

    setState(() => _loadingSubcategories[parentId] = true);

    final result = await ApiService.get(
      '/api/mobile-menu/subcategories?parent_id=$parentId',
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'toggleExpand($parentId) failed: ${result.errorOrNull?.message}',
      );
      setState(() => _loadingSubcategories[parentId] = false);
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      setState(() => _loadingSubcategories[parentId] = false);
      return;
    }

    final subJson = data['subcategories'];
    if (subJson is! List) {
      setState(() => _loadingSubcategories[parentId] = false);
      return;
    }

    setState(() {
      _subcategoriesCache[parentId] = subJson
          .whereType<Map>()
          .map((s) => Category.fromJson(Map<String, dynamic>.from(s)))
          .toList();
      _expandedCategories[parentId] = true;
      _loadingSubcategories[parentId] = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {},
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (ctx, scrollController) => Container(
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding:
                        EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: context.colors.border,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Категория',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 16),
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: context.colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Поиск категорий...',
                              hintStyle: TextStyle(
                                color: context.colors.textDisabled,
                                fontSize: 15,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: context.colors.textDisabled,
                                size: 22,
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  EdgeInsets.symmetric(
                                vertical: 14,
                              ),
                            ),
                            style: TextStyle(
                              fontSize: 15,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _filteredCategories.isEmpty
                        ? Center(
                            child: Text(
                              'Категории не найдены',
                              style: TextStyle(
                                color: context.colors.textMuted,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding:
                                EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _filteredCategories.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                final isSelected =
                                    widget.currentCategoryId == null;
                                return Padding(
                                  padding:
                                      EdgeInsets.only(bottom: 8),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? context.colors.brand
                                              : context.colors.surfaceAlt,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.grid_view,
                                          size: 20,
                                          color: isSelected
                                              ? Colors.white
                                              : context.colors.textMuted,
                                        ),
                                      ),
                                      title: Text(
                                        'Все категории',
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontSize: 15,
                                          color: context.colors.textPrimary,
                                        ),
                                      ),
                                      trailing: isSelected
                                          ? Icon(
                                              Icons.check,
                                              color: context.colors.brand,
                                            )
                                          : null,
                                      onTap: () =>
                                          widget.onSelect(null),
                                    ),
                                  ),
                                );
                              }

                              final parent =
                                  _filteredCategories[index - 1];
                              final isSelected =
                                  widget.currentCategoryId == parent.id;
                              final isExpanded =
                                  _expandedCategories[parent.id] ?? false;
                              final isLoading =
                                  _loadingSubcategories[parent.id] == true;
                              final subs =
                                  _subcategoriesCache[parent.id];

                              return Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: ListTile(
                                      leading: _buildLeading(
                                        parent,
                                        isSelected,
                                      ),
                                      title: Text(
                                        parent.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected
                                              ? context.colors.brand
                                              : context.colors.textPrimary,
                                        ),
                                      ),
                                      trailing: isLoading
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: context.colors.brand,
                                              ),
                                            )
                                          : Icon(
                                              isExpanded
                                                  ? Icons
                                                      .keyboard_arrow_up
                                                  : Icons
                                                      .keyboard_arrow_down,
                                              size: 20,
                                              color: context.colors.textDisabled,
                                            ),
                                      onTap: () {
                                        if (isSelected) {
                                          widget.onSelect(null);
                                        } else {
                                          widget.onSelect(parent.id);
                                        }
                                      },
                                    ),
                                  ),
                                  if (isSelected &&
                                      !isExpanded &&
                                      !isLoading)
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: 52,
                                        bottom: 4,
                                      ),
                                      child: GestureDetector(
                                        onTap: () =>
                                            _toggleExpand(parent.id),
                                        child: Text(
                                          'Показать подкатегории',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: context.colors.brand
                                                .withValues(alpha: 0.7),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (isExpanded && subs != null)
                                    ...subs.map(
                                      (sub) {
                                        final isSubSelected = widget
                                                .currentCategoryId ==
                                            sub.id;
                                        return Padding(
                                          padding: EdgeInsets.only(
                                            left: 16,
                                          ),
                                          child: Material(
                                            color: Colors.transparent,
                                            child: ListTile(
                                              dense: true,
                                              leading:
                                                  _buildSmallLeading(sub),
                                              title: Text(
                                                sub.name,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isSubSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                  color: isSubSelected
                                                      ? context.colors.brand
                                                      : context.colors.textPrimary,
                                                ),
                                              ),
                                              trailing: isSubSelected
                                                  ? Icon(
                                                      Icons.check,
                                                      color: context.colors.brand,
                                                      size: 18,
                                                    )
                                                  : null,
                                              onTap: () => widget
                                                  .onSelect(sub.id),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  const SizedBox(height: 4),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeading(Category cat, bool isSelected) {
    if (cat.imageUrl != null && cat.imageUrl!.isNotEmpty) {
      return ImageLoader(
        imageUrl: cat.imageUrl,
        width: 36,
        height: 36,
        borderRadius: 10,
        errorIcon: Icons.category,
        errorIconSize: 15,
      );
    }
    return _buildDefaultLeading(cat.name, isSelected);
  }

  Widget _buildSmallLeading(Category cat) {
    if (cat.imageUrl != null && cat.imageUrl!.isNotEmpty) {
      return ImageLoader(
        imageUrl: cat.imageUrl,
        width: 32,
        height: 32,
        borderRadius: 8,
        errorIcon: Icons.category,
        errorIconSize: 13,
      );
    }
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          cat.name.isNotEmpty ? cat.name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.textMuted,
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultLeading(String name, bool isSelected) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color:
            isSelected ? context.colors.brand : context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : context.colors.textMuted,
          ),
        ),
      ),
    );
  }
}