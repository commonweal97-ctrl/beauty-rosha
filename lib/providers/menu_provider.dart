// lib/providers/menu_provider.dart
import 'package:flutter/material.dart';

import '../models/mobile_menu_data.dart';
import '../services/mobile_menu_service.dart';

class MenuProvider extends ChangeNotifier {
  bool _isOpen = false;
  bool _isLoading = false;
  MobileMenuData? _data;

  VoidCallback? onOpenNotifications;
  VoidCallback? onOpenProfile;
  VoidCallback? onOpenCart;
  VoidCallback? onGoHome;

  bool get isOpen => _isOpen;
  bool get isLoading => _isLoading;
  MobileMenuData? get data => _data;

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

  Future<void> _open() async {
    _isLoading = true;
    _isOpen = true;
    notifyListeners();

    _data = await MobileMenuService.getMenuData();

    _isLoading = false;
    notifyListeners();
  }
}