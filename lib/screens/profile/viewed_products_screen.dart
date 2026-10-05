// lib/screens/profile/viewed_products_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_logger.dart';
import '../../models/product.dart';
import '../../providers/wishlist_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/product_card.dart';
import '../../core/app_colors.dart';
import '../../core/adaptive_grid.dart';

class ViewedProductsScreen extends StatefulWidget {
  const ViewedProductsScreen({super.key});

  @override
  State<ViewedProductsScreen> createState() => _ViewedProductsScreenState();
}

class _ViewedProductsScreenState extends State<ViewedProductsScreen> {
  static const _logTag = 'ViewedProductsScreen';

  List<Product> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  bool _initialLoad = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    if (_isLoading || !_hasMore) return;
    if (!_initialLoad && !_hasMore) return;

    setState(() => _isLoading = true);

    final result = await ApiService.get(
      '/api/products/viewed',
      queryParams: {
        'page': _page.toString(),
        'limit': '24',
      },
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadProducts(page=$_page) failed: '
            '${result.errorOrNull?.message}',
      );
      setState(() {
        _hasMore = false;
        _isLoading = false;
        _initialLoad = false;
      });
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      setState(() {
        _hasMore = false;
        _isLoading = false;
        _initialLoad = false;
      });
      return;
    }

    final productsRaw = data['products'];
    final products = productsRaw is List
        ? productsRaw
            .whereType<Map>()
            .map((p) => Product.fromJson(Map<String, dynamic>.from(p)))
            .toList()
        : <Product>[];

    final ids = products.map((p) => p.id).toList();
    if (ids.isNotEmpty) {
      context.read<WishlistProvider>().checkBatch(ids);
    }

    if (!mounted) return;

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
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Недавно смотрели',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: context.colors.brand,
        elevation: 0,
      ),
      body: _isLoading && _products.isEmpty
          ? Center(
              child: CircularProgressIndicator(color: context.colors.brand),
            )
          : _products.isEmpty
              ? Center(
                  child: Text(
                    'Нет просмотренных товаров',
                    style: TextStyle(
                      color: context.colors.textMuted,
                      fontSize: 16,
                    ),
                  ),
                )
              : GridView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.only(
                    top: 12,
                    left: 1,
                    right: 1,
                    bottom: bottomPadding + 20,
                  ),
                  gridDelegate:
                      const AdaptiveProductGridDelegate(
                    crossAxisCount: 2,
                    crossAxisSpacing: 1,
                    mainAxisSpacing: 1,
                    contentHeight: 90,
                  ),
                  itemCount: _products.length + (_hasMore ? 4 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _products.length) {
                      return const ProductCardSkeleton();
                    }
                    return ProductCard(product: _products[index]);
                  },
                ),
    );
  }
}