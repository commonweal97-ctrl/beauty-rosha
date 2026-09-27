// lib/services/banner_service.dart
import '../core/app_logger.dart';
import '../models/banner.dart';
import 'api_service.dart';

class BannerService {
  static const _logTag = 'BannerService';

  /// Баннеры для главного экрана. При ошибке — пустой список.
  static Future<List<BannerItem>> getHomeBanners() async {
    final result = await ApiService.get('/api/banners/home');

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'getHomeBanners failed: ${result.errorOrNull?.message}',
      );
      return [];
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return [];

    final banners = data['banners'];
    if (banners is! List) return [];

    return banners
        .whereType<Map>()
        .map((json) => BannerItem.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Баннер для экрана профиля. При ошибке — пустой список.
  static Future<List<BannerItem>> getProfileBanner() async {
    final result = await ApiService.get('/api/banners/profile');

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'getProfileBanner failed: ${result.errorOrNull?.message}',
      );
      return [];
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return [];

    final banners = data['banners'];
    if (banners is! List) return [];

    return banners
        .whereType<Map>()
        .map((json) => BannerItem.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }
}