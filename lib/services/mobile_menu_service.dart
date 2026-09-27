// lib/services/mobile_menu_service.dart
import '../core/app_logger.dart';
import '../models/mobile_menu_data.dart';
import 'api_service.dart';

class MobileMenuService {
  static const _logTag = 'MobileMenuService';

  /// Загрузка данных мобильного меню. При ошибке — пустая модель.
  static Future<MobileMenuData> getMenuData() async {
    final result = await ApiService.get('/api/mobile-menu');

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'getMenuData failed: ${result.errorOrNull?.message}',
      );
      return _emptyMenuData();
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      AppLogger.warning(_logTag, 'getMenuData: data is not a Map');
      return _emptyMenuData();
    }

    try {
      return MobileMenuData.fromJson(Map<String, dynamic>.from(data));
    } catch (e, st) {
      AppLogger.error(_logTag, 'getMenuData parse failed', e, st);
      return _emptyMenuData();
    }
  }

  /// Подкатегории для конкретной категории. `null` при ошибке.
  static Future<Map<String, dynamic>?> getSubcategories(int parentId) async {
    final result = await ApiService.get(
      '/api/mobile-menu/subcategories?parent_id=$parentId',
    );

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'getSubcategories($parentId) failed: ${result.errorOrNull?.message}',
      );
      return null;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return null;

    return Map<String, dynamic>.from(data);
  }

  static MobileMenuData _emptyMenuData() {
    return MobileMenuData(
      categories: [],
      banners: [],
      unreadNotifications: 0,
      city: 'Брянск',
    );
  }
}