// lib/providers/banner_provider.dart
import 'package:flutter/material.dart';

import '../core/app_logger.dart';
import '../models/banner.dart';
import '../services/api_service.dart';

class BannerProvider extends ChangeNotifier {
  static const _logTag = 'BannerProvider';

  List<BannerItem> _banners = [];
  bool _isLoading = false;
  bool _isLoaded = false;
  DateTime? _lastLoadTime;
  static const _cacheDuration = Duration(minutes: 30);

  List<BannerItem> get banners => _banners;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  bool get hasBanners => _banners.isNotEmpty;

  bool get _isCacheExpired {
    if (_lastLoadTime == null) return true;
    return DateTime.now().difference(_lastLoadTime!) > _cacheDuration;
  }

  /// Быстрая инициализация из `appInit` (без запроса к API).
  void setFromInit(List<Map<String, dynamic>> bannersData) {
    _banners = bannersData.map((b) => BannerItem.fromJson(b)).toList();
    _isLoaded = true;
    _lastLoadTime = DateTime.now();
    notifyListeners();
  }

  Future<void> loadBanners({bool forceRefresh = false}) async {
    if (_isLoaded &&
        !forceRefresh &&
        !_isLoading &&
        _banners.isNotEmpty &&
        !_isCacheExpired) {
      return;
    }

    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    final result = await ApiService.get(
      '/api/banners/home',
      forceRefresh: forceRefresh,
    );

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadBanners failed: ${result.errorOrNull?.message}',
      );
    } else {
      final data = result.valueOrNull?['data'];
      if (data is Map) {
        final bannersList = (data['banners'] as List?) ?? const [];
        _banners = bannersList
            .whereType<Map>()
            .map((b) => BannerItem.fromJson(Map<String, dynamic>.from(b)))
            .toList();
        _lastLoadTime = DateTime.now();
        _isLoaded = true;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadBanners(forceRefresh: true);
  }
}