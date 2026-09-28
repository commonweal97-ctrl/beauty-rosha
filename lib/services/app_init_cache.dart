// lib/services/app_init_cache.dart
//
// Файловый кэш для ответа /api/app/init.
// Использует getApplicationSupportDirectory() — надёжное хранилище,
// которое НЕ блокирует UI и НЕ грузит SharedPreferences.
//
// Особенности:
// - TTL 4 часа (динамика: город/валюта/баннеры меняются)
// - Size limit 500 KB (защита от раздувания)
// - Атомарная запись (write через .tmp + rename)
// - Graceful fallback (не падает при ошибках IO/JSON)

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/app_logger.dart';

class AppInitCache {
  static const _logTag = 'AppInitCache';
  static const _fileName = 'app_init_cache.json';
  static const _ttl = Duration(hours: 4);
  static const _maxSizeBytes = 500 * 1024; // 500 KB

  /// Загружает закэшированный payload.
  /// Возвращает null если:
  /// - файла нет
  /// - TTL истёк
  /// - JSON битый
  /// - IO ошибка
  static Future<Map<String, dynamic>?> load() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;

      final raw = await file.readAsString();
      if (raw.isEmpty) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = decoded['_cached_at'] as int?;
      if (savedAt == null) return null;

      final age = DateTime.now().millisecondsSinceEpoch - savedAt;
      if (age > _ttl.inMilliseconds) {
        AppLogger.info(_logTag, 'cache EXPIRED (age=${age ~/ 1000}s)');
        return null;
      }

      final payload = decoded['payload'];
      if (payload is! Map) return null;

      AppLogger.info(
        _logTag,
        'cache HIT (age=${age ~/ 1000}s, ${raw.length} bytes)',
      );
      return Map<String, dynamic>.from(payload);
    } catch (e) {
      AppLogger.warning(_logTag, 'load failed', e);
      return null;
    }
  }

  /// Сохраняет payload в кэш.
  /// Если размер JSON > 500 KB — не сохраняет (защита от раздувания).
  static Future<void> save(Map<String, dynamic> payload) async {
    try {
      final data = jsonEncode({
        '_cached_at': DateTime.now().millisecondsSinceEpoch,
        'payload': payload,
      });

      if (data.length > _maxSizeBytes) {
        AppLogger.warning(
          _logTag,
          'payload too large (${data.length} bytes) — skip cache',
        );
        return;
      }

      final file = await _cacheFile();
      final tmp = File('${file.path}.tmp');

      // Атомарная запись: tmp → rename
      await tmp.writeAsString(data, flush: true);
      await tmp.rename(file.path);

      AppLogger.info(_logTag, 'cache SAVED (${data.length} bytes)');
    } catch (e) {
      AppLogger.warning(_logTag, 'save failed', e);
    }
  }

  /// Очищает кэш (при logout или forceRefresh).
  static Future<void> clear() async {
    try {
      final file = await _cacheFile();
      if (await file.exists()) {
        await file.delete();
        AppLogger.info(_logTag, 'cache CLEARED');
      }
    } catch (e) {
      AppLogger.warning(_logTag, 'clear failed', e);
    }
  }

  static Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }
}
