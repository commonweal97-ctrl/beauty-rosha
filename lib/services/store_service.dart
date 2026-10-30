import '../models/store.dart';
import 'api_service.dart';

class StoreService {
  static Store? _cachedStore;
  static DateTime? _lastFetch;
  static const Duration _cacheTtl = Duration(hours: 1);

  /// Получить магазин по умолчанию (с кэшем на 1 час).
  static Future<Store?> getDefaultStore({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedStore != null && _lastFetch != null) {
      if (DateTime.now().difference(_lastFetch!) < _cacheTtl) {
        return _cachedStore;
      }
    }

    try {
      final response = await ApiService.get('/stores/default');
      if (response.valueOrNull?['success'] == true && response.valueOrNull?['store'] != null) {
        _cachedStore = Store.fromJson(response.valueOrNull?['store']);
        _lastFetch = DateTime.now();
        return _cachedStore;
      }
    } catch (e) {
      // В случае ошибки возвращаем кэш (если есть) или null
      if (_cachedStore != null) return _cachedStore;
    }
    return null;
  }

  /// Синхронный метод для получения адреса (если кэш уже загружен).
  static String getDefaultAddress() {
    return _cachedStore?.address ?? 'Брянск, проспект Станке Димитрова, 65';
  }

  /// Синхронный метод для получения названия магазина.
  static String getDefaultName() {
    return _cachedStore?.name ?? 'Б•Роща — Брянск';
  }

  /// Получить все магазины (для карты).
  static Future<List<Store>> getStores() async {
    try {
      final response = await ApiService.get('/stores');
      if (response.valueOrNull?['success'] == true && response.valueOrNull?['stores'] != null) {
        return (response.valueOrNull?['stores'] as List)
            .map((json) => Store.fromJson(json))
            .toList();
      }
    } catch (e) {
      // В случае ошибки возвращаем пустой список
    }
    return [];
  }
}
