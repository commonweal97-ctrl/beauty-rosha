// lib/screens/profile/purchases_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/purchase_service.dart';
import '../../widgets/product_card.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../../widgets/image_loader.dart';
import '../product/product_detail_screen.dart';
import 'reviews_screen.dart';
import '../main_shell.dart';
import '../../core/app_colors.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  List<PurchasedProduct> _items = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 1;
  bool _initialLoad = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String _sort = 'date_desc';
  final String _hasReview = 'all';
  String _stock = 'all';
  String? _brand;
  PurchaseStats? _stats;

  final List<Map<String, String>> _sortOptions = [
    {'key': 'date_desc', 'label': 'По дате покупки'},
    {'key': 'date_asc', 'label': 'Сначала старые'},
    {'key': 'price_asc', 'label': 'По возрастанию цены'},
    {'key': 'price_desc', 'label': 'По убыванию цены'},
    {'key': 'rating', 'label': 'По вашей оценке'},
  ];

  @override
  void initState() {
    super.initState();
    _loadItems();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadItems();
    }
  }

  Future<void> _loadItems({bool refresh = false}) async {
    if (!_initialLoad && (!_hasMore || _isLoading)) return;
    if (refresh) {
      _page = 1; _hasMore = true; _initialLoad = true; _items = [];
    }
    setState(() => _isLoading = true);
    try {
      final response = await PurchaseService.getItems(
        page: _page,
        sort: _sort,
        hasReview: _hasReview,
        inStock: _stock == 'in_stock',
        source: 'all',
        brand: _brand,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
      );
      if (!mounted) return;
      setState(() {
        if (_page == 1) {
          _items = response.items;
        } else {
          _items.addAll(response.items);
        }
        _hasMore = response.hasMore;
        _stats = response.stats;
        if (_hasMore) _page++;
        _isLoading = false;
        _initialLoad = false;
      });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _initialLoad = false; });
    }
  }

  String _pluralItems(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'товар';
    if ([2, 3, 4].contains(m10) && ![12, 13, 14].contains(m100)) return 'товара';
    return 'товаров';
  }

  String _sortLabel() => _sortOptions.firstWhere((s) => s['key'] == _sort, orElse: () => _sortOptions[0])['label']!;
  String _stockLabel() {
    switch (_stock) {
      case 'in_stock': return 'В наличии';
      case 'out_of_stock': return 'Не в наличии';
      default: return 'Все';
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: context.colors.surfaceAlt,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: topPadding + 48),
                Expanded(
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      // 🔥 Отступ от хедера
                      SliverToBoxAdapter(child: SizedBox(height: 20)),
                      
                      // 🔥 Блок поиска
                      SliverToBoxAdapter(
                        child: Container(
                          color: context.colors.surface,
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: context.colors.surfaceAlt,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: context.colors.surfaceAlt),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onSubmitted: (value) {
                                _initialLoad = true;
                                _hasMore = true;
                                _loadItems(refresh: true);
                              },
                              onChanged: (value) { if (value.isEmpty) { _initialLoad = true; _hasMore = true; _loadItems(refresh: true); } },
                              style: TextStyle(fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Название, артикул, бренд, цвет',
                                hintStyle: TextStyle(color: context.colors.textDisabled, fontSize: 14),
                                prefixIcon: Icon(Icons.search, color: context.colors.textMuted, size: 22),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () { 
                                          _searchController.clear(); 
                                          _initialLoad = true; 
                                          _hasMore = true; 
                                          _loadItems(refresh: true); 
                                        }, 
                                        child: Icon(Icons.close, size: 18, color: context.colors.textMuted),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 🔥 Серый разделитель
                      const SliverToBoxAdapter(child: SizedBox(height: 10)),

                      // 🔥 Блок статистики — только "Оценено" и "Ждут оценки"
                      if (_stats != null)
                        SliverToBoxAdapter(
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatItem(
                                  CustomPaint(size: const Size(28, 26), painter: _StarPainter(color: context.colors.brand)),
                                  '${_stats!.ratedCount}',
                                  'Оценено',
                                  () => MainShell.push(context, const ReviewsScreen(initialTab: 0)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildStatItem(
                                  CustomPaint(size: const Size(28, 26), painter: _StarBorderPainter(color: context.colors.brand)),
                                  '${_stats!.unratedCount}',
                                  'Ждут оценки',
                                  () => MainShell.push(context, const ReviewsScreen(initialTab: 1)),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 🔥 Серый разделитель
                      if (_stats != null)
                        const SliverToBoxAdapter(child: SizedBox(height: 10)),

                      // 🔥 Блок фильтров
                      SliverToBoxAdapter(
                        child: Container(
                          color: context.colors.surface,
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip(_sortLabel(), true, _showSortSheet),
                                SizedBox(width: 8),
                                _buildFilterChip(_stockLabel(), true, _showStockSheet),
                                SizedBox(width: 8),
                                _buildFilterChip(_brand ?? 'Бренд', _brand != null, () => _showBrandSheet()),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 🔥 Товары
                      _isLoading && _items.isEmpty
                          ? SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: context.colors.brand)))
                          : _items.isEmpty
                              ? SliverFillRemaining(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.shopping_bag_outlined, size: 64, color: context.colors.textDisabled), SizedBox(height: 16), Text('Нет купленных товаров', style: TextStyle(fontSize: 16, color: context.colors.textMuted))])))
                              : SliverPadding(
                                  padding: EdgeInsets.only(bottom: 100 + bottomPadding),
                                  sliver: SliverGrid(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.54, crossAxisSpacing: 1, mainAxisSpacing: 1),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        if (index >= _items.length) return const ProductCardSkeleton();
                                        final item = _items[index];
                                        return GestureDetector(
                                          onTap: () => MainShell.push(context, ProductDetailScreen(slug: item.product.slug)),
                                          child: ProductCard(product: item.product),
                                        );
                                      },
                                      childCount: _items.length + (_isLoading ? 4 : 0),
                                    ),
                                  ),
                                ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 🔥 Хедер
          Positioned(
            top: 0, left: 0, right: 0,
            child: AnnotatedRegion<SystemUiOverlayStyle>(
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
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                child: Container(
                  padding: EdgeInsets.only(top: topPadding, bottom: 12),
                  color: context.colors.surface,
                  child: Row(
                    children: [
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: context.colors.error, size: 22),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Купленные товары',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                            ),
                            Text(
                              '${_items.length} ${_pluralItems(_items.length)}',
                              style: TextStyle(fontSize: 13, color: context.colors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
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

  Widget _buildStatItem(Widget customIcon, String count, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            customIcon,
            SizedBox(height: 8),
            Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? context.colors.brand : context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? context.colors.brand : context.colors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isActive ? Colors.white : context.colors.textSecondary)),
          SizedBox(width: 4),
          Icon(isActive ? Icons.close : Icons.keyboard_arrow_down, size: 16, color: isActive ? Colors.white : context.colors.textMuted),
        ]),
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)))),
          SizedBox(height: 20),
          Text('Сортировка', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          SizedBox(height: 16),
          ..._sortOptions.map((s) => GestureDetector(
            onTap: () { Navigator.pop(ctx); setState(() => _sort = s['key']!); _loadItems(refresh: true); },
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(color: _sort == s['key'] ? context.colors.brandLight : Colors.transparent, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [Text(s['label']!, style: TextStyle(fontSize: 15, fontWeight: _sort == s['key'] ? FontWeight.w600 : FontWeight.w400, color: _sort == s['key'] ? context.colors.brand : context.colors.textPrimary)), if (_sort == s['key']) Spacer(), if (_sort == s['key']) Icon(Icons.check, color: context.colors.brand, size: 20)]),
            ),
          )),
        ]),
      ),
    );
  }

  void _showStockSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)))),
          SizedBox(height: 20),
          Text('Наличие', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          SizedBox(height: 16),
          ...['all', 'in_stock', 'out_of_stock'].map((key) {
            String label;
            switch (key) {
              case 'in_stock': label = 'В наличии'; break;
              case 'out_of_stock': label = 'Не в наличии'; break;
              default: label = 'Все';
            }
            return GestureDetector(
              onTap: () { Navigator.pop(ctx); setState(() => _stock = key); _loadItems(refresh: true); },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(color: _stock == key ? context.colors.brandLight : Colors.transparent, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [Text(label, style: TextStyle(fontSize: 15, fontWeight: _stock == key ? FontWeight.w600 : FontWeight.w400, color: _stock == key ? context.colors.brand : context.colors.textPrimary)), if (_stock == key) Spacer(), if (_stock == key) Icon(Icons.check, color: context.colors.brand, size: 20)]),
              ),
            );
          }),
        ]),
      ),
    );
  }

  void _showBrandSheet() async {
    final brands = await PurchaseService.getBrandsWithLogos();

    if (!mounted) return;

    final TextEditingController brandSearch = TextEditingController();
    List<Map<String, dynamic>> filteredBrands = List.from(brands);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        behavior: HitTestBehavior.opaque,
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (ctx, scrollController) => StatefulBuilder(
            builder: (ctx, setSheetState) => GestureDetector(
              onTap: () {},
              child: Container(
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(child: Text('Бренд', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                        ],
                      ),
                    ),
                    SizedBox(height: 12),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: TextField(
                        controller: brandSearch,
                        onChanged: (val) => setSheetState(() {
                          filteredBrands = val.isEmpty
                              ? List.from(brands)
                              : brands.where((b) => (b['name'] as String).toLowerCase().contains(val.toLowerCase())).toList();
                        }),
                        decoration: InputDecoration(
                          hintText: 'Поиск бренда...',
                          prefixIcon: Icon(Icons.search, color: context.colors.textMuted, size: 20),
                          filled: true,
                          fillColor: context.colors.surfaceAlt,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          _buildBrandTile(
                            'Все бренды',
                            null,
                            _brand == null,
                            () {
                              Navigator.pop(ctx);
                              setState(() {
                                _brand = null;
                                _initialLoad = true;
                                _hasMore = true;
                              });
                              _loadItems(refresh: true);
                            },
                          ),
                          ...filteredBrands.map((b) {
                            final name = b['name'] as String;
                            final logo = b['logo'] as String?;
                            return _buildBrandTile(
                              name,
                              logo,
                              _brand == name,
                              () {
                                Navigator.pop(ctx);
                                setState(() {
                                  _brand = name;
                                  _initialLoad = true;
                                  _hasMore = true;
                                });
                                _loadItems(refresh: true);
                              },
                            );
                          }),
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
    );
  }

  Widget _buildBrandTile(String name, String? logoUrl, bool isSelected, VoidCallback onTap) {
    final initials = name == 'Все бренды'
        ? '⊕'
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
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: isSelected ? context.colors.brand.withValues(alpha: 0.1) : context.colors.surfaceAlt,
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
                      child: Text(initials, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isSelected ? context.colors.brand : context.colors.textMuted)),
                    ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400, color: isSelected ? context.colors.brand : context.colors.textPrimary),
              ),
            ),
            if (isSelected)
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(color: context.colors.brand, shape: BoxShape.circle),
                child: Icon(Icons.check, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }
}

// 🔥 Кастомные иконки как в профиле
class _StarPainter extends CustomPainter {
  final Color color;
  _StarPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.scale(size.width / 24);
    canvas.drawPath(
      Path()
        ..moveTo(12, 2)
        ..lineTo(15.09, 8.26)
        ..lineTo(22, 9.27)
        ..lineTo(17, 14.14)
        ..lineTo(18.18, 21.02)
        ..lineTo(12, 17.77)
        ..lineTo(5.82, 21.02)
        ..lineTo(7, 14.14)
        ..lineTo(2, 9.27)
        ..lineTo(8.91, 8.26)
        ..close(),
      paint,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StarBorderPainter extends CustomPainter {
  final Color color;
  _StarBorderPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.scale(size.width / 24);
    canvas.drawPath(
      Path()
        ..moveTo(12, 2)
        ..lineTo(15.09, 8.26)
        ..lineTo(22, 9.27)
        ..lineTo(17, 14.14)
        ..lineTo(18.18, 21.02)
        ..lineTo(12, 17.77)
        ..lineTo(5.82, 21.02)
        ..lineTo(7, 14.14)
        ..lineTo(2, 9.27)
        ..lineTo(8.91, 8.26)
        ..close(),
      paint,
    );
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}