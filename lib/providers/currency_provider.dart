// lib/providers/currency_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_logger.dart';
import '../services/api_service.dart';

class CurrencyProvider extends ChangeNotifier {
  static const _logTag = 'CurrencyProvider';

  String _currency = 'RUB';
  bool _isLoaded = false;
  double _rate = 1.0;

  String get currency => _currency;
  bool get isLoaded => _isLoaded;
  double get rate => _rate;

  String get symbol {
    switch (_currency) {
      case 'RUB':
        return '₽';
      case 'BYN':
        return '\u{E901}';
      case 'KZT':
        return '₸';
      default:
        return '₽';
    }
  }

  String? get fontFamily => _currency == 'BYN' ? 'NBRB' : null;
  double get symbolFontSize => _currency == 'BYN' ? 22.0 : 16.0;

  /// Устанавливаем валюту без загрузки курса (курс загрузим в init).
  void setFromInit(String currency) {
    _currency = currency;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currency == 'RUB' && prefs.getString('currency') != null) {
      _currency = prefs.getString('currency')!;
    }
    debugPrint('[Currency] init: currency=$_currency');
    await _loadRate();
    debugPrint('[Currency] init: rate=$_rate');
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _loadRate() async {
    debugPrint('[Currency] loadRate: currency=$_currency');
    final result = await ApiService.get(
      '/api/currency/rates',
      forceRefresh: true,
    );
    debugPrint('[Currency] loadRate result: ${result.isSuccess}');

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadRate failed: ${result.errorOrNull?.message}',
      );
      _rate = 1.0;
      return;
    }

    final rates = result.valueOrNull?['data']?['rates'];
    if (rates is! Map) {
      _rate = 1.0;
      return;
    }

    final rateData = rates[_currency];
    if (rateData is Map && rateData['rate'] is num) {
      _rate = (rateData['rate'] as num).toDouble();
    } else {
      _rate = 1.0;
    }
  }

  Future<void> setCurrency(String currency) async {
    if (_currency == currency) return;
    _currency = currency;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currency);

    final result = await ApiService.post(
      '/api/currency/set',
      {'currency': currency},
    );

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'setCurrency($currency) failed: ${result.errorOrNull?.message}',
      );
    }

    await _loadRate();
    _isLoaded = true;
    notifyListeners();
  }

  /// Конвертация из рублей в текущую валюту.
  double convert(double rubAmount) {
    if (_currency == 'RUB') return rubAmount;
    if (_rate <= 0) return rubAmount;
    return rubAmount / _rate;
  }

  /// Форматирование сконвертированной суммы.
  String formatConverted(double rubAmount) {
    final value = convert(rubAmount);
    if (value <= 0) return '0';
    if (value == value.roundToDouble()) return '${value.toInt()}';
    return value.toStringAsFixed(2);
  }
}