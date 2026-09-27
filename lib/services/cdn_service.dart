// lib/services/cdn_service.dart
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_logger.dart';

class CdnService {
  static const _logTag = 'CdnService';

  // ========================================================================
  // КОНСТАНТЫ
  // ========================================================================

  static const String mainBaseUrl = 'https://xn--80abvyjk6cts.xn--p1ai';
  static const String cdnBaseUrl =
      'https://xn--80aaf6ac.xn--80abvyjk6cts.xn--p1ai';

  /// Тестовый файл для замера скорости.
  static const String _testFilePath = '/assets/img/products/4880/main.webp';

  /// TTL кэша выбора — 24 часа.
  static const int _cacheTtlMs = 24 * 3600 * 1000;

  /// Timeout на HEAD-запрос при замере.
  static const Duration _measureTimeout = Duration(seconds: 3);

  /// Timeout на запрос к DaData.
  static const Duration _dadataTimeout = Duration(seconds: 4);

  /// Коэффициент преимущества CDN.
  static const double _cdnAdvantageFactor = 1.5;

  // ========================================================================
  // СОСТОЯНИЕ
  // ========================================================================

  static String? _nearestBaseUrl;
  static bool _initStarted = false;
  static Completer<void>? _initCompleter;

  // ========================================================================
  // ПУБЛИЧНЫЙ API
  // ========================================================================

  /// Инициализация (идемпотентно).
  static Future<void> init() async {
    if (_nearestBaseUrl != null) return;

    if (_initStarted && _initCompleter != null) {
      return _initCompleter!.future;
    }

    _initStarted = true;
    _initCompleter = Completer<void>();

    try {
      await _doInit();
      if (!_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }
    } catch (e) {
      AppLogger.warning(_logTag, 'init failed', e);
      _nearestBaseUrl = mainBaseUrl;
      if (!_initCompleter!.isCompleted) {
        _initCompleter!.complete();
      }
    }
  }

  static Future<void> _doInit() async {
    try {
      // 1. Проверяем кэш
      final cached = await _loadFromCache();
      if (cached != null) {
        _nearestBaseUrl = cached;
        return;
      }

      // 2. Замеряем скорость
      final measured = await _measureBothServers();
      if (measured != null) {
        _nearestBaseUrl = measured;
        await _saveToCache(measured);
        return;
      }

      // 3. Fallback — определяем по IP
      final byIp = await _detectByIp();
      if (byIp != null) {
        _nearestBaseUrl = byIp;
        await _saveToCache(byIp);
        return;
      }

      // 4. Финальный fallback
      _nearestBaseUrl = mainBaseUrl;
      await _saveToCache(mainBaseUrl);
    } catch (e) {
      AppLogger.warning(_logTag, 'doInit failed', e);
      _nearestBaseUrl = mainBaseUrl;
    }
  }

  // ========================================================================
  // ЗАМЕР СКОРОСТИ
  // ========================================================================

  static Future<String?> _measureBothServers() async {
    try {
      final results = await Future.wait([
        _measure(mainBaseUrl),
        _measure(cdnBaseUrl),
      ]);

      final mainTime = results[0];
      final cdnTime = results[1];

      if (mainTime >= 99999 && cdnTime >= 99999) return null;
      if (mainTime >= 99999) return cdnBaseUrl;
      if (cdnTime >= 99999) return mainBaseUrl;

      if (cdnTime * _cdnAdvantageFactor < mainTime) return cdnBaseUrl;
      return mainBaseUrl;
    } catch (e) {
      AppLogger.warning(_logTag, 'measureBothServers failed', e);
      return null;
    }
  }

  static Future<int> _measure(String baseUrl) async {
    final stopwatch = Stopwatch()..start();
    try {
      final url = '$baseUrl$_testFilePath';

      final response = await http
          .head(
            Uri.parse(url),
            headers: {
              'Accept': 'image/*,*/*',
              'User-Agent': 'BeautyRosha/1.0',
            },
          )
          .timeout(_measureTimeout);

      stopwatch.stop();

      if (response.statusCode >= 400) return 99999;

      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      stopwatch.stop();
      return 99999;
    }
  }

  // ========================================================================
  // ОПРЕДЕЛЕНИЕ ПО IP (FALLBACK)
  // ========================================================================

  static Future<String?> _detectByIp() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://suggestions.dadata.ru/suggestions/api/4_1/rs/iplocate/address',
        ),
        headers: {
          'Accept': 'application/json',
          'Authorization':
              'Token 3a827d10d5f52ae61c7332285e85411439c58c7b',
        },
      ).timeout(_dadataTimeout);

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body);
      final location = data['location']?['data'];

      if (location == null) return null;

      final region = (location['region'] ?? '').toString().toLowerCase();
      final city = (location['city'] ?? '').toString().toLowerCase();
      final regionWithType =
          (location['region_with_type'] ?? '').toString().toLowerCase();
      final federalDistrict =
          (location['federal_district'] ?? '').toString().toLowerCase();

      final searchString =
          '$region $city $regionWithType $federalDistrict';

      final isNearMain =
          _nearMainRegions.any((r) => searchString.contains(r));

      return isNearMain ? mainBaseUrl : cdnBaseUrl;
    } catch (e) {
      AppLogger.warning(_logTag, 'detectByIp failed', e);
      return null;
    }
  }

  /// Регионы/города/федеральные округа, где основной сервер быстрее.
  static const List<String> _nearMainRegions = [
    // ЦФО
    'брянск', 'москва', 'калуга', 'орёл', 'орел', 'смоленск', 'тула',
    'курск', 'белгород', 'владимир', 'иваново', 'кострома', 'тверь',
    'ярославль', 'рязань', 'липецк', 'тамбов', 'воронеж',
    // СЗФО
    'санкт-петербург', 'спб', 'псков', 'великий новгород', 'вологда',
    'архангельск', 'мурманск', 'петрозаводск', 'сыктывкар', 'калининград',
    // ПФО
    'нижний новгород', 'казань', 'самара', 'саратов', 'уфа', 'пермь',
    'ижевск', 'пенза', 'ульяновск', 'оренбург', 'йошкар-ола', 'саранск',
    'чебоксары', 'киров',
    // УФО
    'екатеринбург', 'челябинск', 'тюмень', 'курган', 'салехард',
    'ханты-мансийск',
    // Области
    'брянская', 'московская', 'калужская', 'орловская', 'смоленская',
    'тульская', 'курская', 'белгородская', 'владимирская', 'ивановская',
    'костромская', 'тверская', 'ярославская', 'рязанская', 'липецкая',
    'тамбовская', 'воронежская',
    'ленинградская', 'псковская', 'новгородская', 'вологодская',
    'архангельская', 'мурманская', 'калининградская',
    'нижегородская', 'самарская', 'саратовская', 'пензенская', 'ульяновская',
    'оренбургская', 'кировская', 'свердловская', 'челябинская',
    'тюменская', 'курганская',
    // Республики
    'татарстан', 'башкортостан', 'удмуртия', 'марий эл', 'мордовия', 'чувашия',
    'карелия', 'коми',
    // Федеральные округа
    'центральный', 'северо-западный', 'приволжский', 'уральский',
  ];

  // ========================================================================
  // КЭШ
  // ========================================================================

  static Future<String?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cdn_base_url');
      final ts = prefs.getInt('cdn_base_url_ts') ?? 0;

      if (cached == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - ts;
      if (age > _cacheTtlMs) return null;

      // Валидация: должен быть один из двух известных
      if (cached != mainBaseUrl && cached != cdnBaseUrl) return null;

      return cached;
    } catch (e) {
      AppLogger.warning(_logTag, 'loadFromCache failed', e);
      return null;
    }
  }

  static Future<void> _saveToCache(String baseUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cdn_base_url', baseUrl);
      await prefs.setInt(
        'cdn_base_url_ts',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      AppLogger.warning(_logTag, 'saveToCache failed', e);
    }
  }

  /// Принудительно перезамерить.
  static Future<void> refreshNearest() async {
    _nearestBaseUrl = null;
    _initStarted = false;
    _initCompleter = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cdn_base_url');
      await prefs.remove('cdn_base_url_ts');
    } catch (e) {
      AppLogger.warning(_logTag, 'refreshNearest/clearCache failed', e);
    }

    await init();
  }

  // ========================================================================
  // ГЕТТЕРЫ URL
  // ========================================================================

  static String get _baseUrl => _nearestBaseUrl ?? mainBaseUrl;

  static String get currentBaseUrl => _baseUrl;
  static bool get isUsingCdn => _baseUrl == cdnBaseUrl;

  static String imageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '$_baseUrl$url';
    return '$_baseUrl/$url';
  }

  static String imageUrlFallback(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) {
      return url.replaceFirst(cdnBaseUrl, mainBaseUrl);
    }
    if (url.startsWith('/')) return '$mainBaseUrl$url';
    return '$mainBaseUrl/$url';
  }

  static String videoUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) {
      return url.replaceFirst(cdnBaseUrl, mainBaseUrl);
    }
    if (url.startsWith('/')) return '$mainBaseUrl$url';
    return '$mainBaseUrl/$url';
  }
}