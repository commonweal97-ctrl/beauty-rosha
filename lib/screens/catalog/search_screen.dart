// lib/screens/catalog/search_screen.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_logger.dart';
import '../../models/brand.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorite_brands_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../services/api_service.dart';
import '../../services/catalog_service.dart';
import '../../services/search_service.dart';
import '../../widgets/image_loader.dart';
import '../../widgets/product_card.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'catalog_screen.dart';
import '../../core/app_colors.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final String? initialBrand;

  const SearchScreen({
    super.key,
    this.initialQuery,
    this.initialBrand,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _logTag = 'SearchScreen';

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocus = FocusNode();
  final TextEditingController _priceFromController = TextEditingController();
  final TextEditingController _priceToController = TextEditingController();

  Timer? _debounceTimer;
  bool _isSearching = false;
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  String _query = '';

  List<Product> _products = [];
  int _total = 0;

  List<dynamic> _suggestions = [];
  List<String> _history = [];
  List<dynamic> _popular = [];

  String _sort = 'popular';
  String? _brand;
  double? _priceFrom;
  double? _priceTo;
  String _stock = 'in_stock';
  List<Brand> _brandsList = [];

  List<Product> _alsoProducts = [];
  bool _alsoLoading = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    if (widget.initialBrand != null) {
      _brand = widget.initialBrand;
    }
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  Future<void> _loadInitialData() async {
    final data = await SearchService.getSuggestions('', brand: _brand);
    if (!mounted) return;
    setState(() {
      _popular = data['popular'] ?? [];
      _history = List<String>.from(data['history'] ?? []);
    });
  }

  Future<void> _loadBrands() async {
    final brandsFromResults = <String>{};
    for (final p in _products) {
      if (p.brand != null && p.brand!.isNotEmpty) {
        brandsFromResults.add(p.brand!);
      }
    }

    try {
      final allBrands = await CatalogService.getBrandsList();
      if (!mounted) return;
      setState(() {
        _brandsList = brandsFromResults.isNotEmpty
            ? allBrands
                .where((b) => brandsFromResults.contains(b.name))
                .toList()
            : allBrands;
      });
    } catch (e) {
      AppLogger.warning(_logTag, 'loadBrands failed', e);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position.pixels;
    final max = _scrollController.position.maxScrollExtent;

    if (pos >= max - 1000) {
      if (_hasMore && !_isLoading) {
        _loadMore();
      } else if (!_hasMore && !_alsoLoading) {
        _loadAlsoProducts();
      }
    }
  }

  void _onSearchChanged(String value) {
    _debounceTimer?.cancel();
    if (value.length < 2) {
      _loadInitialData();
      setState(() {
        _suggestions = [];
        _products = [];
        _total = 0;
        _isSearching = false;
      });
      return;
    }
    _debounceTimer =
        Timer(const Duration(milliseconds: 300), () async {
      final data =
          await SearchService.getSuggestions(value, brand: _brand);
      if (!mounted) return;
      if (_searchController.text != value) return;
      setState(() {
        _suggestions = data['suggestions'] ?? [];
        _history = List<String>.from(data['history'] ?? []);
        _popular = data['popular'] ?? [];
      });
      _checkFavoriteBrands(data);
    });
  }

  void _checkFavoriteBrands(dynamic data) {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;

    final brands = data['brands'] as List? ?? [];
    final brandIds = <int>[];
    for (final b in brands) {
      final id = b['brand_id'];
      if (id is int && id > 0) {
        brandIds.add(id);
      }
    }
    if (brandIds.isNotEmpty) {
      context.read<FavoriteBrandsProvider>().checkBatch(brandIds);
    }
  }

  void _performSearch(String query) {
    if (query.length < 2) return;
    _searchFocus.unfocus();
    setState(() {
      _query = query;
      _isSearching = true;
      _isLoading = true;
      _page = 1;
      _hasMore = true;
      _products = [];
      _suggestions = [];
      _brandsList = [];
      _alsoProducts = [];
    });
    _search();
  }

  Future<void> _search() async {
    if (_isLoading && _page > 1) return;
    if (!_hasMore && _page > 1) return;
    setState(() => _isLoading = true);

    try {
      final data = await SearchService.search(
        _query,
        page: _page,
        sort: _sort,
        brand: _brand,
        priceFrom: _priceFrom,
        priceTo: _priceTo,
        stock: _stock,
      );

      final productsRaw = data['products'];
      final products = productsRaw is List
          ? productsRaw
              .whereType<Map>()
              .map((p) => Product.fromJson(Map<String, dynamic>.from(p)))
              .toList()
          : <Product>[];

      final badgesRaw = data['badges'];
      final List<dynamic> badgesList;
      if (badgesRaw is List) {
        badgesList = badgesRaw;
      } else if (badgesRaw is Map) {
        badgesList = badgesRaw.entries
            .map((e) => {
                  'product_id': int.tryParse(e.key.toString()),
                  'text': e.value is Map
                      ? ((e.value as Map)['text'] ??
                              (e.value as Map)['title'] ??
                              '')
                          .toString()
                      : e.value.toString(),
                })
            .toList();
      } else {
        badgesList = [];
      }

      final badgesMap = <int, String>{};
      for (final b in badgesList) {
        if (b is Map) {
          final pidRaw = b['product_id'];
          final pid = pidRaw is int
              ? pidRaw
              : int.tryParse(pidRaw?.toString() ?? '');
          if (pid != null) {
            badgesMap[pid] =
                (b['text'] ?? b['title'] ?? '').toString();
          }
        }
      }
      for (final product in products) {
        product.badge = badgesMap[product.id];
      }

      if (!mounted) return;

      setState(() {
        if (_page == 1) {
          _products = products;
          _loadBrands();
        } else {
          _products.addAll(products);
        }
        _total = data['total'] ?? 0;
        _hasMore = _products.length < _total && _total > 0;
        _isLoading = false;
        if (_hasMore) _page++;
      });

      if (!_hasMore && _alsoProducts.isEmpty && !_alsoLoading) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _loadAlsoProducts(),
        );
      }

      final ids = _products.map((p) => p.id).toList();
      if (ids.isNotEmpty) {
        context.read<WishlistProvider>().checkBatch(ids);
      }
    } catch (e) {
      AppLogger.warning(_logTag, 'search failed', e);
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _loadMore() {
    if (_isLoading || !_hasMore) return;
    _search();
  }

  Future<void> _loadAlsoProducts() async {
    if (_alsoLoading) return;
    _alsoLoading = true;

    final result = await ApiService.get(
      '/api/recommendations/popular?limit=24',
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadAlsoProducts failed: ${result.errorOrNull?.message}',
      );
      setState(() => _alsoLoading = false);
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      setState(() => _alsoLoading = false);
      return;
    }

    final productsRaw = data['products'];
    final products = productsRaw is List
        ? productsRaw
            .whereType<Map>()
            .map((p) => Product.fromJson(Map<String, dynamic>.from(p)))
            .toList()
        : <Product>[];

    products.shuffle();

    final alsoBadgesRaw = data['badges'];
    final List<dynamic> alsoBadgesList;
    if (alsoBadgesRaw is List) {
      alsoBadgesList = alsoBadgesRaw;
    } else if (alsoBadgesRaw is Map) {
      alsoBadgesList = alsoBadgesRaw.entries
          .map((e) => {
                'product_id': int.tryParse(e.key.toString()),
                'text': e.value is Map
                    ? ((e.value as Map)['text'] ??
                            (e.value as Map)['title'] ??
                            '')
                        .toString()
                    : e.value.toString(),
              })
          .toList();
    } else {
      alsoBadgesList = [];
    }

    final alsoBadgesMap = <int, String>{};
    for (final b in alsoBadgesList) {
      if (b is Map) {
        final pidRaw = b['product_id'];
        final pid = pidRaw is int
            ? pidRaw
            : int.tryParse(pidRaw?.toString() ?? '');
        if (pid != null) {
          alsoBadgesMap[pid] =
              (b['text'] ?? b['title'] ?? '').toString();
        }
      }
    }
    for (final product in products) {
      product.badge = alsoBadgesMap[product.id];
    }

    if (!mounted) return;

    setState(() {
      _alsoProducts.addAll(products);
      _alsoLoading = false;
    });

    final ids = products.map((p) => p.id).toList();
    if (ids.isNotEmpty) {
      context.read<WishlistProvider>().checkBatch(ids);
    }
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Какие товары показывать сначала',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ...sorts.map(
              (s) => _buildSortOption(
                s['label']!,
                _sort == s['key'],
                () {
                  Navigator.pop(ctx);
                  setState(() {
                    _sort = s['key']!;
                    _page = 1;
                    _hasMore = true;
                    _products = [];
                    _alsoProducts = [];
                  });
                  _search();
                  _scrollToTop();
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
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.w400,
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
    _priceFromController.text = _priceFrom?.toString() ?? '';
    _priceToController.text = _priceTo?.toString() ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Цена, Р',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildPriceInput('От', _priceFromController),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '—',
                    style:
                        TextStyle(color: context.colors.textMuted, fontSize: 18),
                  ),
                ),
                Expanded(
                  child: _buildPriceInput('До', _priceToController),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (_priceFrom != null || _priceTo != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _priceFrom = null;
                          _priceTo = null;
                          _page = 1;
                          _hasMore = true;
                          _products = [];
                          _alsoProducts = [];
                        });
                        _search();
                        _scrollToTop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
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
                if (_priceFrom != null || _priceTo != null)
                  const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final from =
                          double.tryParse(_priceFromController.text);
                      final to = double.tryParse(_priceToController.text);
                      Navigator.pop(ctx);
                      setState(() {
                        _priceFrom = from;
                        _priceTo = to;
                        _page = 1;
                        _hasMore = true;
                        _products = [];
                        _alsoProducts = [];
                      });
                      _search();
                      _scrollToTop();
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
    final TextEditingController brandSearch = TextEditingController();
    List<Brand> filteredBrands = List.from(_brandsList);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Container(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: () {},
              child: DraggableScrollableSheet(
                initialChildSize: 0.7,
                minChildSize: 0.4,
                maxChildSize: 0.9,
                builder: (ctx, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Бренд',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: brandSearch,
                          onChanged: (val) => setSheetState(() {
                            filteredBrands = val.isEmpty
                                ? List.from(_brandsList)
                                : _brandsList
                                    .where((b) => b.name
                                        .toLowerCase()
                                        .contains(val.toLowerCase()))
                                    .toList();
                          }),
                          decoration: InputDecoration(
                            hintText: 'Поиск бренда...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: context.colors.textMuted,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: context.colors.surfaceAlt,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            _buildBrandTile(
                              'Все бренды',
                              null,
                              _brand == null,
                              () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _brand = null;
                                  _page = 1;
                                  _hasMore = true;
                                  _products = [];
                                  _alsoProducts = [];
                                });
                                _search();
                                _scrollToTop();
                              },
                            ),
                            ...filteredBrands.map(
                              (b) => _buildBrandTile(
                                b.name,
                                b.logoUrl,
                                _brand == b.name,
                                () {
                                  Navigator.pop(ctx);
                                  setState(() {
                                    _brand = b.name;
                                    _page = 1;
                                    _hasMore = true;
                                    _products = [];
                                    _alsoProducts = [];
                                  });
                                  _search();
                                  _scrollToTop();
                                },
                              ),
                            ),
                            const SizedBox(height: 20),
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
    );
  }

  Widget _buildBrandTile(
    String name,
    String? logoUrl,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final initials = name == 'Все бренды'
        ? '+'
        : name.isNotEmpty
            ? name.substring(0, 2).toUpperCase()
            : '?';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 4),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.brandLight : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? context.colors.brand.withValues(alpha: 0.1)
                    : context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: logoUrl != null && logoUrl.isNotEmpty
                  ? ImageLoader(
                      imageUrl: logoUrl,
                      width: 36,
                      height: 36,
                      borderRadius: 8,
                      errorIcon: Icons.business,
                      errorIconSize: 14,
                    )
                  : Center(
                      child: Text(
                        initials,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? context.colors.brand
                              : context.colors.textMuted,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
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

  void _showStockSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Наличие',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _buildStockOption('Все товары', 'all', _stock, () {
              Navigator.pop(ctx);
              setState(() {
                _stock = 'all';
                _page = 1;
                _hasMore = true;
                _products = [];
                _alsoProducts = [];
              });
              _search();
              _scrollToTop();
            }),
            _buildStockOption('В наличии', 'in_stock', _stock, () {
              Navigator.pop(ctx);
              setState(() {
                _stock = 'in_stock';
                _page = 1;
                _hasMore = true;
                _products = [];
                _alsoProducts = [];
              });
              _search();
              _scrollToTop();
            }),
            _buildStockOption('Нет в наличии', 'out_of_stock', _stock, () {
              Navigator.pop(ctx);
              setState(() {
                _stock = 'out_of_stock';
                _page = 1;
                _hasMore = true;
                _products = [];
                _alsoProducts = [];
              });
              _search();
              _scrollToTop();
            }),
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

  Widget _buildBrandChip(
    String name,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final initials = name == 'Все бренды'
        ? '+'
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
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
        filled: true,
        fillColor: context.colors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        isDense: true,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocus.dispose();
    _debounceTimer?.cancel();
    _priceFromController.dispose();
    _priceToController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: context.colors.surfaceAlt,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Поиск',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: context.colors.brand,
        elevation: 0,
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.swap_vert, color: Colors.white),
              onPressed: _showSortSheet,
            ),
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.tune, color: Colors.white),
              onPressed: _showFiltersSheet,
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                decoration: BoxDecoration(color: context.colors.brand),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        autofocus: true,
                        onChanged: _onSearchChanged,
                        onSubmitted: _performSearch,
                        style: TextStyle(
                          color: context.colors.textPrimary,
                          fontSize: 15,
                        ),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: 'Поиск по товарам...',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: context.colors.textMuted,
                            size: 22,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                  child: Icon(
                                    Icons.close,
                                    color: context.colors.textMuted,
                                    size: 20,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _isSearching
                    ? _buildResults()
                    : _buildSuggestions(),
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

  void _showFiltersSheet() {
    _priceFromController.text = _priceFrom?.toString() ?? '';
    _priceToController.text = _priceTo?.toString() ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (ctx, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Все фильтры',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
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
                const SizedBox(height: 24),
                const Text(
                  'Наличие',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterOption(
                      'Все',
                      'all',
                      _stock,
                      () => setSheetState(() => _stock = 'all'),
                    ),
                    _buildFilterOption(
                      'В наличии',
                      'in_stock',
                      _stock,
                      () => setSheetState(() => _stock = 'in_stock'),
                    ),
                    _buildFilterOption(
                      'Нет в наличии',
                      'out_of_stock',
                      _stock,
                      () => setSheetState(() => _stock = 'out_of_stock'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Цена, Р',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child:
                          _buildPriceInput('От', _priceFromController),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '—',
                        style: TextStyle(color: context.colors.textMuted),
                      ),
                    ),
                    Expanded(
                      child: _buildPriceInput('До', _priceToController),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final from =
                          double.tryParse(_priceFromController.text);
                      final to = double.tryParse(_priceToController.text);
                      setSheetState(() {
                        _priceFrom = from;
                        _priceTo = to;
                      });
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
                const SizedBox(height: 24),
                if (_brandsList.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Бренд',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            setSheetState(() => _brand = null),
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
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[400],
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
                      _buildBrandChip('Все бренды', _brand == null, () {
                        setSheetState(() => _brand = null);
                      }),
                      ..._brandsList.map(
                        (b) => _buildBrandChip(
                          b.name,
                          _brand == b.name,
                          () {
                            setSheetState(() => _brand = b.name);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setSheetState(() {
                            _brand = null;
                            _priceFrom = null;
                            _priceTo = null;
                            _stock = 'in_stock';
                            _sort = 'popular';
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _page = 1;
                            _hasMore = true;
                            _products = [];
                            _alsoProducts = [];
                          });
                          _search();
                          _scrollToTop();
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
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
            color: isSelected ? Colors.white : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildChip(
    String label, {
    bool isHistory = false,
    bool isPopular = false,
  }) {
    return GestureDetector(
      onTap: () {
        _searchController.text = label;
        _performSearch(label);
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              isPopular ? context.colors.warning.withValues(alpha: 0.15) : context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isPopular
                ? context.colors.warning
                : context.colors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isPopular
                ? context.colors.warning
                : context.colors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? context.colors.brand : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isActive ? context.colors.brand : context.colors.border,
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color:
                    isActive ? Colors.white : context.colors.textSecondary,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 14, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }

  String _pluralItems(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'товар';
    if ([2, 3, 4].contains(m10) && ![12, 13, 14].contains(m100)) {
      return 'товара';
    }
    return 'товаров';
  }

  Widget _buildSuggestions() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
      children: [
        if (_popular.isNotEmpty || _history.isNotEmpty) ...[
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Часто ищут',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      ..._history.take(5).map(
                            (q) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildChip(q, isHistory: true),
                            ),
                          ),
                      ..._popular.take(8).map(
                            (p) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildChip(
                                p is String ? p : p['query'] ?? '',
                                isPopular: true,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_suggestions.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Подсказки',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Consumer<FavoriteBrandsProvider>(
            builder: (context, favProvider, _) {
              return Column(
                children: _suggestions
                    .map((s) => _buildSuggestionItem(s, favProvider))
                    .toList(),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildSuggestionItem(
    dynamic s,
    FavoriteBrandsProvider favProvider,
  ) {
    final text = s['text'] ?? '';
    final type = s['type'] ?? '';
    final logo = s['logo'] ?? '';
    int? brandId;
    final rawBrandId = s['brand_id'];
    if (rawBrandId is int && rawBrandId > 0) {
      brandId = rawBrandId;
    } else if (rawBrandId is String) {
      final parsed = int.tryParse(rawBrandId);
      if (parsed != null && parsed > 0) brandId = parsed;
    }
    final count = s['count'] is int ? s['count'] as int : null;
    final inStockCount =
        s['in_stock_count'] is int ? s['in_stock_count'] as int : null;
    final isFavorite =
        brandId != null ? favProvider.isFavorite(brandId) : false;

    if (type == 'brand') {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CatalogScreen(initialBrand: text),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
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
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: logo.isNotEmpty
                      ? ImageLoader(
                          imageUrl: logo,
                          width: 42,
                          height: 42,
                          borderRadius: 8,
                          errorIcon: Icons.business,
                          errorIconSize: 16,
                        )
                      : Center(
                          child: Text(
                            text.isNotEmpty
                                ? text
                                    .substring(0, min(2, text.length))
                                    .toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textMuted,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      if (count != null) ...[
                        Text(
                          '$count ${_pluralItems(count)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colors.textMuted,
                          ),
                        ),
                        if (inStockCount != null && inStockCount < count)
                          Text(
                            '$inStockCount/$count в наличии',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colors.success,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                if (brandId != null)
                  GestureDetector(
                    onTap: () => favProvider.toggle(brandId!),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isFavorite
                            ? context.colors.brandLight
                            : context.colors.surfaceAlt,
                        shape: BoxShape.circle,
                      ),
                      child: favProvider.isLoading(brandId)
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: context.colors.brand,
                              ),
                            )
                          : Icon(
                              isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 18,
                              color: isFavorite
                                  ? context.colors.brand
                                  : context.colors.textDisabled,
                            ),
                    ),
                  ),
                SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  size: 22,
                  color: context.colors.textDisabled,
                ),
              ],
            ),
          ),
        ),
      );
    }

    IconData icon;
    switch (type) {
      case 'product':
        icon = Icons.inventory_2_outlined;
        break;
      default:
        icon = Icons.search;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 3),
      child: GestureDetector(
        onTap: () {
          _searchController.text = text;
          _performSearch(text);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: context.colors.textMuted,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: context.colors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (_popular.isNotEmpty || _history.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              color: context.colors.surfaceAlt,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
                    child: Text(
                      'Часто ищут',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        ..._history.take(5).map(
                              (q) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildChip(q, isHistory: true),
                              ),
                            ),
                        ..._popular.take(8).map(
                              (p) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildChip(
                                  p is String ? p : p['query'] ?? '',
                                  isPopular: true,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Фильтры',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildFilterChip(
                        'Цена',
                        _priceFrom != null || _priceTo != null,
                        _showPriceSheet,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Бренд',
                        _brand != null,
                        _showBrandSheet,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Наличие',
                        _stock != 'all',
                        _showStockSheet,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '$_total товаров',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isLoading && _products.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: context.colors.brand),
            ),
          )
        else if (_products.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Text(
                'Ничего не найдено',
                style: TextStyle(color: context.colors.textMuted),
              ),
            ),
          )
        else ...[
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.54,
              crossAxisSpacing: 1,
              mainAxisSpacing: 1,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, index) {
                if (index >= _products.length) {
                  return const ProductCardSkeleton();
                }
                return ProductCard(
  product: _products[index],
  searchQuery: _query,
  searchPosition: index + 1,
);
              },
              childCount: _products.length + (_hasMore ? 4 : 0),
            ),
          ),
          if (!_hasMore && _products.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                  child: Text(
                    'Смотрите также',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ),
            ),
          if (!_hasMore)
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.54,
                crossAxisSpacing: 1,
                mainAxisSpacing: 1,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, index) {
                  if (index >= _alsoProducts.length) {
                    _loadAlsoProducts();
                    return const ProductCardSkeleton();
                  }
                  return ProductCard(product: _alsoProducts[index]);
                },
                childCount:
                    _alsoProducts.length + (_alsoLoading ? 4 : 0),
              ),
            ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}