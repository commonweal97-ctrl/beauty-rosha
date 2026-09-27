// lib/providers/catalog_provider.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_logger.dart';
import '../models/brand.dart';
import '../models/category.dart';
import '../models/product.dart';
import '../services/catalog_service.dart';
import 'wishlist_provider.dart';

class CatalogProvider extends ChangeNotifier {
  static const _logTag = 'CatalogProvider';

  List<Product> _products = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _total = 0;
  String? _error;

  int? _categoryId;
  String? _brand;
  String _sort = 'popular';
  double? _priceFrom;
  double? _priceTo;
  String _stock = 'in_stock';

  List<String> _brands = [];
  List<Brand> _brandsList = [];
  List<Category> _categories = [];
  List<Category> _subcategories = [];
  List<Map<String, dynamic>> _badges = [];

  String _categoryName = 'Каталог';

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  int get total => _total;
  String? get error => _error;
  int? get categoryId => _categoryId;
  String? get brand => _brand;
  String get sort => _sort;
  double? get priceFrom => _priceFrom;
  double? get priceTo => _priceTo;
  String get stock => _stock;
  List<String> get brands => _brands;
  List<Brand> get brandsList => _brandsList;
  List<Category> get categories => _categories;
  List<Category> get subcategories => _subcategories;
  List<Map<String, dynamic>> get badges => _badges;
  String get categoryName => _categoryName;

  Future<void> loadCategories() async {
    _categories = await CatalogService.getCategories(brand: _brand);
    notifyListeners();
  }

  Future<void> loadBrands() async {
    _brands = await CatalogService.getBrands(categoryId: _categoryId);
    _brandsList =
        await CatalogService.getBrandsList(categoryId: _categoryId);
    notifyListeners();
  }

  Future<void> loadSubcategories(int parentId) async {
    _subcategories = await CatalogService.getSubcategories(parentId);
    notifyListeners();
  }

  Future<void> loadWithParams(
    BuildContext context, {
    int? categoryId,
    String? brand,
  }) async {
    _isLoading = false;
    _categoryId = categoryId;
    _brand = brand;
    _currentPage = 1;
    _hasMore = true;
    _products = [];
    _subcategories = [];
    _error = null;

    notifyListeners();

    await loadCategories();

    if (!context.mounted) return;

    if (categoryId != null) {
      final cat = _categories.where((c) => c.id == categoryId).toList();
      _categoryName = cat.isNotEmpty ? cat.first.name : 'Каталог';
    } else if (brand != null) {
      _categoryName = brand;
    } else {
      _categoryName = 'Каталог';
    }
    notifyListeners();

    await loadProducts(context, refresh: true);
    await loadBrands();
  }

  Future<void> loadProducts(
    BuildContext context, {
    bool refresh = false,
  }) async {
    if (_isLoading) return;
    if (!refresh && !_hasMore) return;

    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _products = [];
      _error = null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await CatalogService.getProducts(
        page: _currentPage,
        categoryId: _categoryId,
        brand: _brand,
        sort: _sort,
        priceFrom: _priceFrom,
        priceTo: _priceTo,
        stock: _stock,
      );

      if (refresh) {
        _products = result.products;
        _badges = result.badges;
      } else {
        final existingIds = _products.map((p) => p.id).toSet();
        final newProducts = result.products
            .where((p) => !existingIds.contains(p.id))
            .toList();

        _products.addAll(newProducts);
        _badges.addAll(result.badges);
      }

      _applyBadges();

      _total = result.total;
      _hasMore = result.products.length >= 24 && _products.length < _total;

      if (_hasMore) _currentPage++;

      if (context.mounted) {
        final ids = _products.map((p) => p.id).toList();
        if (ids.isNotEmpty) {
          try {
            Provider.of<WishlistProvider>(context, listen: false)
                .checkBatch(ids);
          } catch (e) {
            AppLogger.warning(_logTag, 'checkBatch failed', e);
          }
        }
      }
    } catch (e, st) {
      _error = e.toString();
      AppLogger.error(_logTag, 'loadProducts failed', e, st);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshProducts() async {
    _currentPage = 1;
    _hasMore = true;
    _products = [];

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await CatalogService.getProducts(
        page: _currentPage,
        categoryId: _categoryId,
        brand: _brand,
        sort: _sort,
        priceFrom: _priceFrom,
        priceTo: _priceTo,
        stock: _stock,
      );

      _products = result.products;
      _badges = result.badges;

      _applyBadges();

      _total = result.total;
      _hasMore = result.products.length >= 24 && _products.length < _total;
      if (_hasMore) _currentPage++;
    } catch (e, st) {
      _error = e.toString();
      AppLogger.error(_logTag, 'refreshProducts failed', e, st);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Применяет badges к продуктам по `product_id`.
  void _applyBadges() {
    final badgesMap = <int, String>{};
    for (final b in _badges) {
      final pid = b['product_id'];
      if (pid is int) {
        badgesMap[pid] = (b['text'] ?? b['title'] ?? '').toString();
      }
    }
    for (final product in _products) {
      product.badge = badgesMap[product.id];
    }
  }

  void setCategory(int? categoryId) {
    if (_categoryId == categoryId) return;
    _categoryId = categoryId;
    _subcategories = [];
    _products = [];
    _isLoading = false;
    _hasMore = true;
    _currentPage = 1;
    loadBrands();
    notifyListeners();
  }

  void setBrand(String? brand) {
    if (_brand == brand) return;
    _brand = brand;
    loadCategories();
    notifyListeners();
  }

  void setSort(String sort) {
    if (_sort == sort) return;
    _sort = sort;
    notifyListeners();
  }

  void setPriceRange(double? from, double? to) {
    if (_priceFrom == from && _priceTo == to) return;
    _priceFrom = from;
    _priceTo = to;
    notifyListeners();
  }

  void setStock(String stock) {
    if (_stock == stock) return;
    _stock = stock;
    notifyListeners();
  }

  void resetFilters() {
    _categoryId = null;
    _brand = null;
    _sort = 'popular';
    _priceFrom = null;
    _priceTo = null;
    _stock = 'in_stock';
    _subcategories = [];
    _categoryName = 'Каталог';
    notifyListeners();
  }

  Future<void> refresh(BuildContext context) =>
      loadProducts(context, refresh: true);
}