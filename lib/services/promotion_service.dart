// lib/services/promotion_service.dart
import '../core/app_logger.dart';
import 'api_service.dart';

class PromotionService {
  static const _logTag = 'PromotionService';

  static List<Map<String, dynamic>>? cachedPromotions;

  /// Загружает активные акции с сервера.
  /// При ошибке — возвращает кэш или пустой список.
  static Future<List<Map<String, dynamic>>> fetchActivePromotions() async {
    final result = await ApiService.get('/api/promotions/active-list');

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'fetchActivePromotions failed: ${result.errorOrNull?.message}',
      );
      return cachedPromotions ?? [];
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return cachedPromotions ?? [];

    final list = data['promotions'];
    if (list is! List) return cachedPromotions ?? [];

    cachedPromotions = list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    return cachedPromotions!;
  }

  /// Рассчитывает акции локально.
  static Map<String, dynamic> calculateLocal({
    required List<Map<String, dynamic>> cartItems,
    required List<Map<String, dynamic>> promotions,
  }) {
    final freeItems = <Map<String, dynamic>>[];
    double totalDiscount = 0;
    final appliedPromotions = <Map<String, dynamic>>[];
    final Map<int, int> freeItemsMap = {};

    for (final promo in promotions) {
      if (promo['type'] != '2plus1') continue;

      final groups = _groupItems(promo, cartItems);
      for (final group in groups.values) {
        totalDiscount += _apply2Plus1(promo, group, freeItems, freeItemsMap);
      }
    }

    return {
      'free_items': freeItems,
      'total_discount': totalDiscount,
      'applied_promotions': appliedPromotions,
      'free_items_map': freeItemsMap,
    };
  }

  static Map<String, List<Map<String, dynamic>>> _groupItems(
    Map<String, dynamic> promo,
    List<Map<String, dynamic>> items,
  ) {
    final groups = <String, List<Map<String, dynamic>>>{};
    final promoProducts = List<int>.from(promo['products'] ?? []);
    final categories = List<int>.from(promo['categories'] ?? []);
    final brands = List<String>.from(promo['brands'] ?? []);

    for (final item in items) {
      final pid = item['product_id'] as int;
      final catId = item['category_id'];
      final brand = item['brand_name'] as String?;

      bool matches = false;
      String key = '';

      if (promoProducts.isNotEmpty) {
        if (promoProducts.contains(pid)) {
          matches = true;
          key = 'product_$pid';
        }
      } else if (categories.isNotEmpty && brands.isNotEmpty) {
        if (catId != null &&
            categories.contains(catId) &&
            brand != null &&
            brands.contains(brand)) {
          matches = true;
          key = 'cat_${catId}_brand_$brand';
        }
      } else if (categories.isNotEmpty) {
        if (catId != null && categories.contains(catId)) {
          matches = true;
          key = 'cat_$catId';
        }
      } else if (brands.isNotEmpty) {
        if (brand != null && brands.contains(brand)) {
          matches = true;
          key = 'brand_$brand';
        }
      } else {
        matches = true;
        key = 'product_$pid';
      }

      if (matches) {
        groups.putIfAbsent(key, () => []).add(item);
      }
    }
    return groups;
  }

  static double _apply2Plus1(
    Map<String, dynamic> promo,
    List<Map<String, dynamic>> group,
    List<Map<String, dynamic>> freeItems,
    Map<int, int> freeItemsMap,
  ) {
    int totalQty = 0;
    for (final item in group) {
      totalQty += item['quantity'] as int;
    }

    if (totalQty < 3) return 0;

    int freeCount = totalQty ~/ 3;

    final allUnits = <Map<String, dynamic>>[];
    for (final item in group) {
      final qty = item['quantity'] as int;
      final price = (item['price'] ?? 0).toDouble();
      final effectivePrice = (item['effective_price'] ?? price).toDouble();
      for (int i = 0; i < qty; i++) {
        allUnits.add({
          'product_id': item['product_id'],
          'price': price,
          'effective_price': effectivePrice,
        });
      }
    }

    allUnits.sort((a, b) =>
        (a['effective_price'] as double).compareTo(b['effective_price'] as double));

    double discount = 0;
    for (int i = 0; i < freeCount; i++) {
      final unit = allUnits[i];
      final pid = unit['product_id'] as int;
      final price = unit['effective_price'] as double;

      freeItems.add({
        'product_id': pid,
        'original_price': unit['price'],
        'discount': price,
      });

      freeItemsMap[pid] = (freeItemsMap[pid] ?? 0) + 1;
      discount += price;
    }

    return discount;
  }
}