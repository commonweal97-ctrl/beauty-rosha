// lib/screens/profile/wishlist_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_logger.dart';
import '../../models/product.dart';
import '../../providers/wishlist_provider.dart';
import '../../services/wishlist_service.dart';
import '../../widgets/product_card.dart';
import '../../widgets/scroll_to_top_button.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  static const _logTag = 'WishlistScreen';

  List<Product> _products = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 1;
  bool _initialLoad = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String _sort = 'date_desc';
  bool _inStock = false;

  final List<Map<String, String>> _sortOptions = [
    {'key': 'date_desc', 'label': 'По дате добавления'},
    {'key': 'date_asc', 'label': 'Сначала старые'},
    {'key': 'price_asc', 'label': 'По возрастанию цены'},
    {'key': 'price_desc', 'label': 'По убыванию цены'},
    {'key': 'in_stock', 'label': 'Сначала в наличии'},
    {'key': 'out_of_stock', 'label': 'Сначала не в наличии'},
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadItems();
    }
  }

  Future<void> _loadItems({bool refresh = false}) async {
    if (!_initialLoad && (!_hasMore || _isLoading)) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _initialLoad = true;
      _products = [];
    }
    setState(() => _isLoading = true);

    final result = await WishlistService.getItems(
      page: _page,
      search:
          _searchController.text.isNotEmpty ? _searchController.text : null,
      sort: _sort,
      inStock: _inStock,
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadItems(page=$_page) failed: ${result.errorOrNull?.message}',
      );
      setState(() {
        _isLoading = false;
        _initialLoad = false;
      });
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      setState(() {
        _isLoading = false;
        _initialLoad = false;
      });
      return;
    }

    final itemsRaw = data['items'];
    final items = itemsRaw is List
        ? itemsRaw.whereType<Map>().toList()
        : <Map>[];

    final products = items
        .map((item) => Product.fromJson({
              ...Map<String, dynamic>.from(item),
              'brand': item['brand'] ?? '',
              'gallery': [],
            }))
        .toList();

    setState(() {
      if (_page == 1) {
        _products = products;
      } else {
        _products.addAll(products);
      }
      _hasMore = data['has_more'] ?? false;
      if (_hasMore) _page++;
      _isLoading = false;
      _initialLoad = false;
    });

    final wishlistProvider = context.read<WishlistProvider>();
    for (final p in products) {
      wishlistProvider.setInWishlist(p.id, true);
    }
  }

  String _pluralItems(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'товар';
    if ([2, 3, 4].contains(m10) && ![12, 13, 14].contains(m100)) {
      return 'товара';
    }
    return 'товаров';
  }

  String _sortLabel() =>
      _sortOptions
          .firstWhere(
            (s) => s['key'] == _sort,
            orElse: () => _sortOptions[0],
          )['label']!;

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
                  child: _isLoading && _products.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFDD1847),
                          ),
                        )
                      : _products.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      12,
                                    ),
                                    child: Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F8FA),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFF0F0F0),
                                        ),
                                      ),
                                      child: TextField(
                                        controller: _searchController,
                                        onSubmitted: (value) =>
                                            _loadItems(refresh: true),
                                        onChanged: (value) {
                                          if (value.isEmpty) {
                                            _loadItems(refresh: true);
                                          }
                                        },
                                        style: const TextStyle(
                                          fontSize: 15,
                                        ),
                                        decoration: InputDecoration(
                                          hintText:
                                              'Название, артикул, бренд, цвет',
                                          hintStyle: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 14,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.search,
                                            color: Color(0xFF999999),
                                            size: 22,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          suffixIcon: _searchController
                                                  .text.isNotEmpty
                                              ? GestureDetector(
                                                  onTap: () {
                                                    _searchController.clear();
                                                    _loadItems(
                                                      refresh: true,
                                                    );
                                                  },
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 18,
                                                    color: Color(
                                                      0xFF999999,
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  const Icon(
                                    Icons.favorite_border,
                                    size: 64,
                                    color: Color(0xFFCCCCCC),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'В избранном пока ничего нет',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF999999),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : CustomScrollView(
                              controller: _scrollController,
                              slivers: [
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 20),
                                ),
                                SliverToBoxAdapter(
                                  child: Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      12,
                                    ),
                                    child: Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F8FA),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFF0F0F0),
                                        ),
                                      ),
                                      child: TextField(
                                        controller: _searchController,
                                        onSubmitted: (value) =>
                                            _loadItems(refresh: true),
                                        onChanged: (value) {
                                          if (value.isEmpty) {
                                            _loadItems(refresh: true);
                                          }
                                        },
                                        style: const TextStyle(
                                          fontSize: 15,
                                        ),
                                        decoration: InputDecoration(
                                          hintText:
                                              'Название, артикул, бренд, цвет',
                                          hintStyle: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 14,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.search,
                                            color: Color(0xFF999999),
                                            size: 22,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          suffixIcon: _searchController
                                                  .text.isNotEmpty
                                              ? GestureDetector(
                                                  onTap: () {
                                                    _searchController.clear();
                                                    _loadItems(
                                                      refresh: true,
                                                    );
                                                  },
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 18,
                                                    color: Color(
                                                      0xFF999999,
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 10),
                                ),
                                SliverToBoxAdapter(
                                  child: Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      12,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: [
                                                _buildFilterChip(
                                                  _sortLabel(),
                                                  true,
                                                  _showSortSheet,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        GestureDetector(
                                          onTap: () {
                                            setState(
                                              () => _inStock = !_inStock,
                                            );
                                            _loadItems(refresh: true);
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  color: _inStock
                                                      ? const Color(
                                                          0xFFDD1847,
                                                        )
                                                      : Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    4,
                                                  ),
                                                  border: Border.all(
                                                    color: _inStock
                                                        ? const Color(
                                                            0xFFDD1847,
                                                          )
                                                        : const Color(
                                                            0xFFCCCCCC,
                                                          ),
                                                  ),
                                                ),
                                                child: _inStock
                                                    ? const Icon(
                                                        Icons.check,
                                                        size: 14,
                                                        color: Colors.white,
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              const Text(
                                                'Снова в наличии',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w500,
                                                  color: Color(0xFF555555),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SliverPadding(
                                  padding: EdgeInsets.only(
                                    bottom: 100 + bottomPadding,
                                  ),
                                  sliver: SliverGrid(
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.54,
                                      crossAxisSpacing: 1,
                                      mainAxisSpacing: 1,
                                    ),
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        if (index >= _products.length) {
                                          return const ProductCardSkeleton();
                                        }
                                        return ProductCard(
                                          product: _products[index],
                                        );
                                      },
                                      childCount: _products.length +
                                          (_isLoading ? 4 : 0),
                                    ),
                                  ),
                                ),
                              ],
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
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.only(top: topPadding, bottom: 12),
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
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Избранное',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            Text(
                              '${_products.length} '
                              '${_pluralItems(_products.length)}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF888888),
                              ),
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

  Widget _buildFilterChip(
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              isActive ? const Color(0xFFDD1847) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? const Color(0xFFDD1847)
                : const Color(0xFFE0E0E0),
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
                color: isActive ? Colors.white : const Color(0xFF555555),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isActive ? Icons.close : Icons.keyboard_arrow_down,
              size: 16,
              color: isActive ? Colors.white : const Color(0xFF999999),
            ),
          ],
        ),
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              'Сортировка',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ..._sortOptions.map(
              (s) => GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _sort = s['key']!);
                  _loadItems(refresh: true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: _sort == s['key']
                        ? const Color(0xFFFDF2F5)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        s['label']!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: _sort == s['key']
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _sort == s['key']
                              ? const Color(0xFFDD1847)
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      if (_sort == s['key']) const Spacer(),
                      if (_sort == s['key'])
                        const Icon(
                          Icons.check,
                          color: Color(0xFFDD1847),
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}