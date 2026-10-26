// lib/providers/menu_provider.dart
import 'package:flutter/material.dart';

import '../models/mobile_menu_data.dart';
import '../services/mobile_menu_service.dart';
import '../services/image_memory_cache.dart';
import '../services/cdn_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MenuProvider extends ChangeNotifier {
  bool _isOpen = false;
  bool _isLoading = false;
  bool _isIconsPreloading = false;
  bool _isMenuReady = false;
  MobileMenuData? _data;

  VoidCallback? onOpenNotifications;
  VoidCallback? onOpenProfile;
  VoidCallback? onOpenCart;
  VoidCallback? onGoHome;

  bool get isOpen => _isOpen;
  bool get isLoading => _isLoading;
  bool get isIconsPreloading => _isIconsPreloading;
  bool get isMenuReady => _isMenuReady;
  
  void setMenuReady(bool value) {
    if (_isMenuReady != value) {
      _isMenuReady = value;
      notifyListeners();
    }
  }
  MobileMenuData? get data => _data;
  
  void setIconsPreloading(bool value) {
    if (_isIconsPreloading != value) {
      _isIconsPreloading = value;
      notifyListeners();
    }
  }

  void setFromInit(List<Map<String, dynamic>> menuData) {
    _data = MobileMenuData(
      categories: menuData.map((c) => MenuCategory.fromJson(c)).toList(),
      banners: _data?.banners ?? [],
      unreadNotifications: _data?.unreadNotifications ?? 0,
      city: _data?.city ?? 'Брянск',
    );
    notifyListeners();
  }

  void toggle() {
    if (_isOpen) {
      _isOpen = false;
      notifyListeners();
    } else {
      _open();
    }
  }

  void close() {
    _isOpen = false;
    notifyListeners();
  }

  Future<void> loadMenu() async {
    _isLoading = true;
    notifyListeners();

    // MobileMenuService.getMenuData() не бросает — при ошибке вернёт
    // пустую модель и залогирует причину.
    _data = await MobileMenuService.getMenuData();

    _isLoading = false;
    notifyListeners();
  }

  /// 🔥 Загрузка только баннеров (без isLoading — в фоне)
  Future<void> loadBanners() async {
    try {
      // 🔥 Не перезагружаем, если баннеры уже есть
      if (_data != null && _data!.banners.isNotEmpty) {
        return;
      }
      final newData = await MobileMenuService.getMenuData();
      if (newData.banners.isNotEmpty) {
        _data = MobileMenuData(
          categories: _data?.categories ?? newData.categories,
          banners: newData.banners,
          unreadNotifications: _data?.unreadNotifications ?? 0,
          city: _data?.city ?? 'Брянск',
        );
        notifyListeners();
        
        // 🔥 Предзагрузка баннеров в RAM (после загрузки)
        for (final banner in newData.banners) {
          final url = banner.imageUrl;
          if (url.isEmpty) continue;
          try {
            // 🔥 Кэшируем .avif (как ищет ImageLoader)
            final fullUrl = CdnService.imageUrl(url); // WebP (быстрее декодируется)
            final file = await DefaultCacheManager().getSingleFile(fullUrl);
            final bytes = await file.readAsBytes();
            ImageMemoryCache().put(fullUrl, bytes);
          } catch (e) {
            // ignore: empty_catches
          }
        }
      }
    } catch (_) {
      // ignore: empty_catches
    }
  }

  /// 🔥 Устанавливает баннеры (без isLoading — в фоне)
  void setBanners(List<MenuBanner> banners) {
    if (banners.isEmpty) return;
    if (_data != null) {
      _data = MobileMenuData(
        categories: _data!.categories,
        banners: banners,
        unreadNotifications: _data!.unreadNotifications,
        city: _data!.city,
      );
      notifyListeners();
    }
  }

  Future<void> _open() async {
    _isLoading = true;
    _isOpen = true;
    notifyListeners();

    _data = await MobileMenuService.getMenuData();

    _isLoading = false;
    notifyListeners();
  }
}