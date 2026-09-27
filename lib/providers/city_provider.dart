// lib/providers/city_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_logger.dart';
import '../models/product_detail.dart';
import '../services/api_service.dart';

class CityProvider extends ChangeNotifier {
  static const _logTag = 'CityProvider';

  String _city = 'Брянск';
  String _country = 'Россия';
  bool _loaded = false;
  bool _disposed = false;
  int _freeDeliveryThreshold = 5000;
  String? _deliveryEstimate;
  DeliveryEstimate? _deliveryInfo;

  String get city => _city;
  String get country => _country;
  bool get loaded => _loaded;
  int get freeDeliveryThreshold => _freeDeliveryThreshold;
  String? get deliveryEstimate => _deliveryEstimate;
  DeliveryEstimate? get deliveryInfo => _deliveryInfo;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  void setFromInit(String city, String country) {
    _city = city;
    _country = country;
    _loaded = true;
    _safeNotify();
    _loadDeliveryInfo();
  }

  Future<void> _loadDeliveryInfo() async {
    final result = await ApiService.get('/api/pickup/estimate?city=$_city');

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadDeliveryInfo("$_city") failed: '
            '${result.errorOrNull?.message}',
      );
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return;

    _freeDeliveryThreshold = (data['free_threshold'] ?? 5000) as int;
    _deliveryEstimate = data['title'] as String?;
    _deliveryInfo = DeliveryEstimate(
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      city: _city,
      providers: (data['providers'] as List<dynamic>?)
              ?.map((p) => p.toString())
              .toList() ??
          [],
    );
    _safeNotify();
  }

  Future<void> loadDeliveryInfo() async {
    await _loadDeliveryInfo();
  }

  Future<void> loadCity() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCity = prefs.getString('city');
    final savedCountry = prefs.getString('country');

    if (savedCity != null && savedCity.isNotEmpty) {
      _city = savedCity;
      _country = savedCountry ?? 'Россия';
    }

    final result = await ApiService.get('/api/city/get');

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadCity failed: ${result.errorOrNull?.message}',
      );
    } else {
      final data = result.valueOrNull?['data'];
      if (data is Map) {
        final serverCity = data['city'] as String?;
        final serverCountry = data['country'] as String?;

        if (serverCity != null && serverCity.isNotEmpty) {
          if (savedCity == null || savedCity.isEmpty) {
            _city = serverCity;
            _country = serverCountry ?? 'Россия';
            await prefs.setString('city', _city);
            await prefs.setString('country', _country);
          } else if (serverCity != savedCity) {
            if (serverCity != 'Брянск' || savedCity == 'Брянск') {
              _city = serverCity;
              _country = serverCountry ?? 'Россия';
              await prefs.setString('city', _city);
              await prefs.setString('country', _country);
            }
          }
        }
      }
    }

    _loaded = true;
    _safeNotify();

    await _loadDeliveryInfo();
  }

  Future<void> setCity(String city, String country) async {
    if (_city == city && _country == country) return;

    _city = city;
    _country = country;

    // Сохраняем локально
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('guest_city', city);
    await prefs.setString('guest_country', country);

    // Отправляем на сервер
    final saveResult = await ApiService.post('/api/city/save', {
      'city': city,
      'country': country,
    });

    if (saveResult.isFailure) {
      AppLogger.warning(
        _logTag,
        'setCity/save failed: ${saveResult.errorOrNull?.message}',
      );
    }

    // Сбрасываем ПВЗ при смене города
    final deselectResult = await ApiService.post(
      '/api/pickup/deselect',
      {'keep_method': true},
    );

    if (deselectResult.isFailure) {
      AppLogger.warning(
        _logTag,
        'setCity/deselect failed: ${deselectResult.errorOrNull?.message}',
      );
    }

    // Перезагружаем порог для нового города
    await _loadDeliveryInfo();

    notifyListeners();
  }

  Future<void> syncWithServer() async {
    final result = await ApiService.get('/api/city/get');

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'syncWithServer failed: ${result.errorOrNull?.message}',
      );
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return;

    final serverCity = data['city'] as String?;
    final serverCountry = data['country'] as String?;

    if (serverCity == null || serverCity.isEmpty || serverCity == _city) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _city = serverCity;
    _country = serverCountry ?? 'Россия';
    await prefs.setString('city', _city);
    await prefs.setString('country', _country);
    _safeNotify();

    await _loadDeliveryInfo();
  }
}