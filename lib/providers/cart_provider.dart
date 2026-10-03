// lib/providers/cart_provider.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_logger.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../services/crashlytics_service.dart';
import '../services/promotion_service.dart';
import 'auth_provider.dart';

class CartProvider extends ChangeNotifier {
  static const _logTag = 'CartProvider';

  final Map<int, int> _items = {};
  final Map<int, Map<String, dynamic>> _details = {};
  bool _loaded = false;
  bool _fullyLoaded = false;
  bool _disposed = false;
  bool _authListenerAdded = false;

  double _totalPrice = 0;
  double _totalOldPrice = 0;
  double _cardDiscount = 0;
  double _promoDiscount = 0;
  double _firstOrderDiscount = 0;
  Map<String, dynamic>? _firstOrderInfo;
  double _finalTotal = 0;
  int _totalCount = 0;
  bool _hasCard = false;
  String? _cardStatus;
  final Map<int, int> _freeItemsMap = {};
  List<Map<String, dynamic>> _promoProducts = [];

  Set<int> _checkedIds = {};

  Map<int, int> get items => _items;
  Map<int, Map<String, dynamic>> get details => _details;
  bool get loaded => _loaded;

  /// 🔥 ШАГ 4: `isFullyLoaded` — true только после `loadFullCart`.
  /// `loadCartCount()` ставит `_loaded = true`, но `_fullyLoaded = false`.
  /// `CartScreen` использует это, чтобы понять, нужно ли догружать promotions.
  bool get isFullyLoaded => _fullyLoaded;

  int get totalCount => _totalCount;
  double get finalTotal => _finalTotal;
  double get cardDiscount => _cardDiscount;
  double get promoDiscount => _promoDiscount;
  double get firstOrderDiscount => _firstOrderDiscount;
  Map<String, dynamic>? get firstOrderInfo => _firstOrderInfo;
  double get totalPrice => _totalPrice;
  double get totalOldPrice => _totalOldPrice;
  bool get hasCard => _hasCard;
  String? get cardStatus => _cardStatus;
  Map<int, int> get freeItemsMap => _freeItemsMap;
  List<Map<String, dynamic>> get promoProducts => _promoProducts;
  Set<int> get checkedIds => _checkedIds;
  int getQuantity(int productId) => _items[productId] ?? 0;
  bool isInCart(int productId) => _items.containsKey(productId);

  bool isItemChecked(int productId) => _checkedIds.contains(productId);

  bool get allChecked {
    final available = _details.keys
        .where((id) =>
            !(_details[id]?['unavailable'] == true ||
                (_details[id]?['stock'] ?? 0) <= 0))
        .toSet();
    return available.isNotEmpty && _checkedIds.length == available.length;
  }

  static const String _localCartKey = 'guest_cart_items';

  CartProvider() {
    _loadLocalCartSync();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void listenToAuth(AuthProvider auth) {
    if (_authListenerAdded) return;
    _authListenerAdded = true;

    auth.addListener(() {
      if (!auth.isLoading && auth.isLoggedIn) {
        _syncGuestCartOnLogin();
      }
    });
  }

  Future<void> _syncGuestCartOnLogin() async {
    await _loadLocalCart();

    if (_items.isNotEmpty) {
      try {
        await CrashlyticsService.log(
          'Cart sync on login: ${_items.length} items',
        );

        final syncItems = _items.entries
            .map((e) => {
                  'product_id': e.key,
                  'quantity': e.value,
                })
            .toList();

        final result = await ApiService.post('/api/cart/sync', {
          'items': syncItems,
        });

        if (result.isFailure) {
          AppLogger.warning(
            _logTag,
            'sync on login failed: ${result.errorOrNull?.message}',
          );
        }
      } catch (e, stackTrace) {
        await CrashlyticsService.recordError(
          e,
          stackTrace,
          reason: 'Cart sync on login failed',
        );
      }
    }

    await loadFullCart();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localCartKey);
  }

  void _loadLocalCartSync() {
    SharedPreferences.getInstance().then((prefs) {
      if (_disposed) return;
      final saved = prefs.getString(_localCartKey);
      if (saved != null && saved.isNotEmpty) {
        try {
          final List<dynamic> cartData = jsonDecode(saved);
          for (final item in cartData) {
            final pid = item['product_id'] as int;
            _items[pid] = item['quantity'] as int;
            _details[pid] = Map<String, dynamic>.from(item);
          }
          _totalCount = _items.values.fold(0, (sum, qty) => sum + qty);
          _loaded = true;
          _initCheckedIds();
          if (!_disposed) notifyListeners();
        } catch (e) {
          AppLogger.warning(_logTag, 'loadLocalCartSync parse failed', e);
          _loaded = true;
          _initCheckedIds();
          if (!_disposed) notifyListeners();
        }
      } else {
        _loaded = true;
        _initCheckedIds();
        if (!_disposed) notifyListeners();
      }
    });
  }

  void _initCheckedIds() {
    _checkedIds = _details.keys
        .where((id) =>
            !(_details[id]?['unavailable'] == true ||
                (_details[id]?['stock'] ?? 0) <= 0))
        .toSet();
  }

  void toggleAll(bool selectAll) {
    final available = _details.keys
        .where((id) =>
            !(_details[id]?['unavailable'] == true ||
                (_details[id]?['stock'] ?? 0) <= 0))
        .toSet();
    _checkedIds = selectAll ? available : {};
    recalculateLocal(_checkedIds);
    notifyListeners();
  }

  void toggleItem(int productId) {
    if (_checkedIds.contains(productId)) {
      _checkedIds.remove(productId);
    } else {
      _checkedIds.add(productId);
    }
    recalculateLocal(_checkedIds);
    notifyListeners();
  }

  /// 🔥 ШАГ 4: лёгкая загрузка — только `/api/cart/items`.
  /// Нужна на старте для бейджа `totalCount` в BottomNav.
  /// НЕ тянет promotions и loyalty/status.
  Future<void> loadCartCount() async {
    await _loadLocalCart();

    final List<int> localProductIds = _items.keys.toList();
    final Map<String, dynamic> body = {
      'product_ids': localProductIds,
      'quantities': Map<String, int>.fromEntries(
        _items.entries.map((e) => MapEntry(e.key.toString(), e.value)),
      ),
    };

    final cartResult = await ApiService.post('/api/cart/items', body);

    if (cartResult.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadCartCount failed: ${cartResult.errorOrNull?.message}',
      );
      // Fallback: локальные данные
      _totalCount = _items.values.fold(0, (sum, qty) => sum + qty);
      _loaded = true;
      _initCheckedIds();
      if (!_disposed) notifyListeners();
      return;
    }

    final data = cartResult.valueOrNull?['data'];
    if (data is! Map) {
      _loaded = true;
      _initCheckedIds();
      if (!_disposed) notifyListeners();
      return;
    }

    final bool isAuthenticated = data['is_authenticated'] ?? false;
    final List<dynamic> serverItems = data['items'] ?? [];

    if (isAuthenticated && serverItems.isNotEmpty) {
      _items.clear();
      _details.clear();

      for (final item in serverItems) {
        if (item is! Map) continue;
        final pid = item['product_id'] as int;
        final qty = item['quantity'] as int;
        _items[pid] = qty;
        _details[pid] = Map<String, dynamic>.from(item);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localCartKey);
    } else if (serverItems.isNotEmpty) {
      for (final item in serverItems) {
        if (item is! Map) continue;
        final pid = item['product_id'] as int;
        final localQty = _items[pid] ?? 1;

        _items[pid] = localQty;
        final merged = Map<String, dynamic>.from(item);
        merged['quantity'] = localQty;
        _details[pid] = merged;
      }
    } else if (_items.isNotEmpty && isAuthenticated) {
      final syncItems = _items.entries
          .map((e) => {
                'product_id': e.key,
                'quantity': e.value,
              })
          .toList();

      final syncResult = await ApiService.post(
        '/api/cart/sync',
        {'items': syncItems},
      );

      if (syncResult.isFailure) {
        AppLogger.warning(
          _logTag,
          'loadCartCount/sync failed: ${syncResult.errorOrNull?.message}',
        );
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_localCartKey);
      }
    }

    _totalCount = _items.values.fold(0, (sum, qty) => sum + qty);
    _loaded = true;
    _initCheckedIds();
    await _saveToCache();

    if (!_disposed) notifyListeners();
  }

  /// 🔥 ШАГ 4: тяжёлая загрузка — `/api/cart/items` + promotions
  /// + loyalty/status. Вызывается из `CartScreen` и при `reload`.
  Future<void> loadFullCart() async {
    await _loadLocalCart();

    final List<int> localProductIds = _items.keys.toList();
    final Map<String, dynamic> body = {
      'product_ids': localProductIds,
      'quantities': Map<String, int>.fromEntries(
        _items.entries.map((e) => MapEntry(e.key.toString(), e.value)),
      ),
    };

    final cartResult = await ApiService.post('/api/cart/items', body);

    if (cartResult.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadFullCart failed: ${cartResult.errorOrNull?.message}',
      );
      // Fallback: оставляем локальные данные
      _initCheckedIds();
      if (_items.isNotEmpty) {
        await _loadPromotions();
        await _loadCardStatus();
      }
      _totalCount = _items.values.fold(0, (sum, qty) => sum + qty);
      _loaded = true;
      _fullyLoaded = true;
      await _saveToCache();
      notifyListeners();
      return;
    }

    final data = cartResult.valueOrNull?['data'];
    if (data is! Map) {
      _initCheckedIds();
      _loaded = true;
      _fullyLoaded = true;
      notifyListeners();
      return;
    }

    final bool isAuthenticated = data['is_authenticated'] ?? false;
    final List<dynamic> serverItems = data['items'] ?? [];

    if (isAuthenticated && serverItems.isNotEmpty) {
      _items.clear();
      _details.clear();

      for (final item in serverItems) {
        if (item is! Map) continue;
        final pid = item['product_id'] as int;
        final qty = item['quantity'] as int;
        _items[pid] = qty;
        _details[pid] = Map<String, dynamic>.from(item);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_localCartKey);
    } else if (serverItems.isNotEmpty) {
      for (final item in serverItems) {
        if (item is! Map) continue;
        final pid = item['product_id'] as int;
        final localQty = _items[pid] ?? 1;

        _items[pid] = localQty;
        final merged = Map<String, dynamic>.from(item);
        merged['quantity'] = localQty;
        _details[pid] = merged;
      }
    } else if (_items.isNotEmpty && isAuthenticated) {
      // Защита от рекурсии: сервер пуст, локально есть — синхронизируем 1 раз.
      final syncItems = _items.entries
          .map((e) => {
                'product_id': e.key,
                'quantity': e.value,
              })
          .toList();

      final syncResult = await ApiService.post(
        '/api/cart/sync',
        {'items': syncItems},
      );

      if (syncResult.isFailure) {
        AppLogger.warning(
          _logTag,
          'loadFullCart/sync failed: ${syncResult.errorOrNull?.message}',
        );
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_localCartKey);
      }
    }

    _totalCount = _items.values.fold(0, (sum, qty) => sum + qty);
    _loaded = true;
    _fullyLoaded = true;
    _initCheckedIds();
    await _saveToCache();

    if (_items.isNotEmpty) {
      await PromotionService.fetchActivePromotions();
      await _loadPromotions();
    }

    await _loadCardStatus();

    notifyListeners();
  }

  Future<void> _loadCardStatus() async {
    final result = await ApiService.get('/api/loyalty/status');

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadCardStatus failed: ${result.errorOrNull?.message}',
      );
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return;

    _cardStatus = data['status'] as String?;
    if (!_disposed) notifyListeners();
  }

  Future<void> syncFromServer() async {
    if (_items.isEmpty) return;

    final result = await ApiService.post('/api/cart/items', {
      'product_ids': _items.keys.toList(),
      'quantities': Map<String, int>.fromEntries(
        _items.entries.map((e) => MapEntry(e.key.toString(), e.value)),
      ),
    });

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'syncFromServer failed: ${result.errorOrNull?.message}',
      );
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return;

    final List<dynamic> serverItems = data['items'] ?? [];

    _items.clear();
    _details.clear();

    for (final item in serverItems) {
      if (item is! Map) continue;
      final pid = item['product_id'] as int;
      final qty = item['quantity'] as int;
      _items[pid] = qty;
      _details[pid] = Map<String, dynamic>.from(item);
    }

    _checkedIds = _details.keys
        .where((id) =>
            !(_details[id]?['unavailable'] == true ||
                (_details[id]?['stock'] ?? 0) <= 0))
        .toSet();

    _totalCount = _items.values.fold(0, (sum, qty) => sum + qty);
    await _saveToCache();

    if (_items.isNotEmpty) {
      await _loadPromotions(_checkedIds.toList());
    }

    await _loadCardStatus();

    if (!_disposed) notifyListeners();
  }

  Future<void> _saveLocalCart() async {
    final prefs = await SharedPreferences.getInstance();
    final cartData = <Map<String, dynamic>>[];

    for (final entry in _items.entries) {
      final detail = _details[entry.key];
      cartData.add({
        'product_id': entry.key,
        'quantity': entry.value,
        'name': detail?['name'] ?? '',
        'price': detail?['price'] ?? 0,
        'card_price': detail?['card_price'],
        'sale_price': detail?['sale_price'],
        'main_image': detail?['main_image'] ?? '',
        'main_image_card': detail?['main_image_card'] ??
            (detail?['main_image'] ?? '').toString().replaceAll(
                  'main.webp',
                  'main_card.webp',
                ),
        'stock': detail?['stock'] ?? 0,
        'brand': detail?['brand'] ?? '',
        'slug': detail?['slug'] ?? '',
      });
    }

    await prefs.setString(_localCartKey, jsonEncode(cartData));
  }

  Future<void> _loadLocalCart() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_localCartKey);

    if (saved != null && saved.isNotEmpty) {
      try {
        final List<dynamic> cartData = jsonDecode(saved);
        for (final item in cartData) {
          final pid = item['product_id'] as int;
          _items[pid] = item['quantity'] as int;
          _details[pid] = Map<String, dynamic>.from(item);
        }
      } catch (e) {
        AppLogger.warning(_logTag, 'loadLocalCart parse failed', e);
      }
    }
  }

  Future<void> _saveToCache() async {
    final prefs = await SharedPreferences.getInstance();
    final count = _items.values.fold(0, (sum, qty) => sum + qty);
    await prefs.setInt('cached_cart_count', count);
    await _saveLocalCart();
  }

  void reset() {
    _items.clear();
    _details.clear();
    _checkedIds.clear();
    _loaded = false;
    _fullyLoaded = false;
    _totalPrice = 0;
    _totalOldPrice = 0;
    _cardDiscount = 0;
    _promoDiscount = 0;
    _firstOrderDiscount = 0;
    _firstOrderInfo = null;
    _finalTotal = 0;
    _totalCount = 0;
    _hasCard = false;
    _cardStatus = null;
    _freeItemsMap.clear();
    _promoProducts.clear();
    _saveToCache();
    notifyListeners();
  }

  void _updateCardState(bool newHasCard, double newCardDiscount) {
    _hasCard = newHasCard;
    _cardDiscount = newCardDiscount;
  }

  Future<void> _loadPromotions([List<int>? productIds]) async {
    final ids = productIds ?? _items.keys.toList();
    if (ids.isEmpty) return;

    final Map<String, int> quantities = {};
    for (final id in ids) {
      quantities[id.toString()] = _items[id] ?? 1;
    }

    final promoResult = await ApiService.post(
      '/api/promotions/cart-by-ids',
      {
        'product_ids': ids,
        'quantities': quantities,
      },
    );

    if (promoResult.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadPromotions failed: ${promoResult.errorOrNull?.message}',
      );
      return;
    }

    final promoData = promoResult.valueOrNull?['data'];
    if (promoData is! Map) return;

    final pricesRaw = promoData['prices'];
    final bool isGuest = promoData['is_guest'] ?? false;

    _totalPrice = (promoData['total_price'] ?? 0).toDouble();
    _totalOldPrice = (promoData['total_old_price'] ?? 0).toDouble();
    _promoDiscount = (promoData['promo_discount'] ?? 0).toDouble();
    _firstOrderDiscount =
        (promoData['first_order_discount'] ?? 0).toDouble();
    _firstOrderInfo = promoData['first_order_info'];
    _finalTotal = (promoData['final_total'] ?? 0).toDouble();
    _totalCount = _items.values.fold(0, (sum, qty) => sum + qty);

    _updateCardState(
      isGuest ? false : (promoData['has_card'] ?? false),
      isGuest ? 0 : (promoData['card_discount'] ?? 0).toDouble(),
    );

    _freeItemsMap.clear();
    final freeItemsRaw = promoData['free_items'];
    if (freeItemsRaw is List) {
      for (final fi in freeItemsRaw) {
        if (fi is! Map) continue;
        final pid = fi['product_id'] as int;
        _freeItemsMap[pid] = (_freeItemsMap[pid] ?? 0) + 1;
      }
    }

    final pp = promoData['promo_products'];
    if (pp is List) {
      _promoProducts = pp
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (pricesRaw is Map) {
      for (final entry in _details.entries) {
        final pid = entry.key.toString();
        if (pricesRaw.containsKey(pid)) {
          final priceData = pricesRaw[pid];
          if (priceData is Map) {
            entry.value['price'] =
                (priceData['price'] ?? entry.value['price']).toDouble();
            entry.value['sale_price'] =
                priceData['sale_price']?.toDouble();
            entry.value['card_price'] =
                priceData['card_price']?.toDouble();
            entry.value['free_qty'] = priceData['free_qty'] ?? 0;
            entry.value['paid_qty'] =
                priceData['paid_qty'] ?? entry.value['quantity'];
            entry.value['total_with_promo'] =
                (priceData['total_with_promo'] ?? 0).toDouble();
          }
        }
      }
    }

    if (_hasCard && _cardStatus == null) {
      await _loadCardStatus();
    }

    await _saveToCache();
    if (!_disposed) notifyListeners();
  }

  void addItemFull(Map<String, dynamic> productData, int quantity) {
    final pid = productData['product_id'] as int;
    final stock = (productData['stock'] ?? 0) as int;
    final oldQty = _items[pid] ?? 0;
    final actualQty =
        (oldQty + quantity).clamp(0, stock > 0 ? stock : oldQty + quantity);
    _items[pid] = actualQty;
    _details[pid] = Map<String, dynamic>.from(productData);
    _details[pid]!['quantity'] = actualQty;
    _loaded = true;

    _totalCount = _items.values.fold(0, (sum, qty) => sum + qty);

    if (!(_details[pid]?['unavailable'] == true ||
        (_details[pid]?['stock'] ?? 0) <= 0)) {
      _checkedIds.add(pid);
    }

    recalculateLocal(_checkedIds);

    _saveToCache();
    notifyListeners();

    CrashlyticsService.log('Added to cart: product $pid, qty $quantity');

    CartService.addToCart(pid, quantity: quantity).then((result) {
      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'addToCart($pid) failed: ${result.errorOrNull?.message}',
        );
      }
    });
  }

  void recalculateLocal(Set<int> checkedIds) {
    _checkedIds = checkedIds;

    if (checkedIds.isEmpty) {
      _totalPrice = 0;
      _totalOldPrice = 0;
      _cardDiscount = 0;
      _promoDiscount = 0;
      _firstOrderDiscount = 0;
      _firstOrderInfo = null;
      _finalTotal = 0;
      _totalCount = 0;
      _hasCard = false;
      _freeItemsMap.clear();
      notifyListeners();
      return;
    }

    _loadPromotions(checkedIds.toList());
  }

  Future<void> updateQuantity(int productId, int newQty) async {
    final stock = (_details[productId]?['stock'] ?? 0) as int;
    if (stock > 0 && newQty > stock) {
      newQty = stock;
    }
    if (newQty <= 0) {
      _items.remove(productId);
      _details.remove(productId);
      _checkedIds.remove(productId);

      CrashlyticsService.log('Removed from cart: product $productId');
    } else {
      _items[productId] = newQty;
      if (_details.containsKey(productId)) {
        _details[productId]!['quantity'] = newQty;
      }

      CrashlyticsService.log(
        'Updated cart quantity: product $productId, qty $newQty',
      );
    }
    await _saveToCache();
    notifyListeners();

    CartService.updateQuantity(productId, newQty).then((result) {
      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'updateQuantity($productId) failed: '
              '${result.errorOrNull?.message}',
        );
      }
    });

    if (_items.isNotEmpty && _checkedIds.isNotEmpty) {
      _loadPromotions(_checkedIds.toList());
    } else if (_checkedIds.isEmpty) {
      _finalTotal = 0;
      _totalCount = 0;
      notifyListeners();
    }
  }

  Future<void> removeItem(int productId) async {
    _items.remove(productId);
    _details.remove(productId);
    _checkedIds.remove(productId);
    await _saveToCache();
    notifyListeners();

    CrashlyticsService.log('Removed from cart: product $productId');

    CartService.removeFromCart(productId).then((result) {
      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'removeFromCart($productId) failed: '
              '${result.errorOrNull?.message}',
        );
      }
    });

    if (_items.isNotEmpty) {
      _checkedIds.isNotEmpty
          ? _loadPromotions(_checkedIds.toList())
          : _loadPromotions();
    } else {
      _totalPrice = 0;
      _totalOldPrice = 0;
      _cardDiscount = 0;
      _promoDiscount = 0;
      _firstOrderDiscount = 0;
      _firstOrderInfo = null;
      _finalTotal = 0;
      _totalCount = 0;
      _hasCard = false;
      _freeItemsMap.clear();
      _checkedIds.clear();
    }
    await _saveToCache();
    notifyListeners();
  }

  Future<void> removeItemSilent(int productId) async {
    _items.remove(productId);
    _details.remove(productId);
    _checkedIds.remove(productId);
    await _saveToCache();

    AppLogger.info(_logTag, 'removeItemSilent: $productId');
    notifyListeners();

    final result = await CartService.removeFromCart(productId);

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'removeItemSilent($productId) failed: '
            '${result.errorOrNull?.message}',
      );
    }
  }

  Future<void> removeMultiple(List<int> productIds) async {
    for (final pid in productIds) {
      _items.remove(pid);
      _details.remove(pid);
      _checkedIds.remove(pid);
    }
    await _saveToCache();
    notifyListeners();

    final result = await CartService.removeMultiple(productIds);

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'removeMultiple failed: ${result.errorOrNull?.message}',
      );
    }

    if (_items.isEmpty) {
      _totalPrice = 0;
      _totalOldPrice = 0;
      _cardDiscount = 0;
      _promoDiscount = 0;
      _firstOrderDiscount = 0;
      _firstOrderInfo = null;
      _finalTotal = 0;
      _totalCount = 0;
      _hasCard = false;
      _freeItemsMap.clear();
      _checkedIds.clear();
    }
  }

  Future<void> removeFromCart(int productId) async {
    _items.remove(productId);
    _details.remove(productId);
    _checkedIds.remove(productId);
    await _saveToCache();
    notifyListeners();

    CrashlyticsService.log('Removed from cart: product $productId');

    CartService.removeFromCart(productId).then((result) {
      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'removeFromCart($productId) failed: '
              '${result.errorOrNull?.message}',
        );
      }
    });

    if (_items.isEmpty) {
      _totalPrice = 0;
      _totalOldPrice = 0;
      _cardDiscount = 0;
      _promoDiscount = 0;
      _firstOrderDiscount = 0;
      _firstOrderInfo = null;
      _finalTotal = 0;
      _totalCount = 0;
      _hasCard = false;
      _freeItemsMap.clear();
      _checkedIds.clear();
    } else {
      _checkedIds.isNotEmpty
          ? _loadPromotions(_checkedIds.toList())
          : _loadPromotions();
    }

    await _saveToCache();
    notifyListeners();
  }

  void addItem(int productId, int quantity) {
    if (quantity <= 0) return;
    _items[productId] = (_items[productId] ?? 0) + quantity;
    _saveToCache();
    notifyListeners();
  }

  void addToCart(int productId) {
    addItem(productId, 1);
  }

  void clearCart() {
    _items.clear();
    _details.clear();
    _checkedIds.clear();
    _totalPrice = 0;
    _totalOldPrice = 0;
    _cardDiscount = 0;
    _promoDiscount = 0;
    _firstOrderDiscount = 0;
    _firstOrderInfo = null;
    _finalTotal = 0;
    _totalCount = 0;
    _hasCard = false;
    _cardStatus = null;
    _freeItemsMap.clear();
    _saveToCache();
    notifyListeners();

    CrashlyticsService.log('Cart cleared');
  }
}