// lib/services/image_memory_cache.dart
//
// Профессиональный in-memory кэш для картинок.
// Хранит байты (Uint8List) в RAM для мгновенного доступа (0 мс).
// Используется в ImageLoader для устранения мигания скелетонов.

import 'package:flutter/foundation.dart';

class ImageMemoryCache {
  static final ImageMemoryCache _instance = ImageMemoryCache._internal();
  factory ImageMemoryCache() => _instance;
  ImageMemoryCache._internal();

  // Максимальный размер кэша (50 МБ — достаточно для ~500 картинок 100 КБ).
  static const int _maxSizeBytes = 50 * 1024 * 1024;

  final Map<String, Uint8List> _cache = {};
  int _currentSizeBytes = 0;

  /// Получить байты из кэша (или null, если нет).
  Uint8List? get(String url) {
    final bytes = _cache[url];
    if (url.contains('.avif')) {
      debugPrint('[ImageMemoryCache] get AVIF: $url → ${bytes != null ? "HIT (${bytes.length} bytes)" : "MISS"}');
    }
    return bytes;
  }

  /// Сохранить байты в кэш (с ограничением размера).
  void put(String url, Uint8List bytes) {
    if (_cache.containsKey(url)) return;

    // Если кэш переполнен — очищаем (простая стратегия: очистить всё).
    if (_currentSizeBytes + bytes.length > _maxSizeBytes) {
      clear();
    }

    _cache[url] = bytes;
    _currentSizeBytes += bytes.length;
    debugPrint('[ImageMemoryCache] put: $url (${bytes.length} bytes, total=${_cache.length})');
    if (url.contains('.avif')) {
      debugPrint('[ImageMemoryCache] ✅ AVIF saved: ${bytes.length} bytes');
    } else {
      debugPrint('[ImageMemoryCache] ⚠️ NOT AVIF (WebP?): ${bytes.length} bytes');
    }
  }

  /// Очистить кэш.
  void clear() {
    _cache.clear();
    _currentSizeBytes = 0;
    debugPrint('[ImageMemoryCache] cleared');
  }

  /// Статистика (для отладки).
  Map<String, dynamic> stats() => {
        'count': _cache.length,
        'sizeBytes': _currentSizeBytes,
        'sizeMb': (_currentSizeBytes / 1024 / 1024).toStringAsFixed(1),
      };
}
