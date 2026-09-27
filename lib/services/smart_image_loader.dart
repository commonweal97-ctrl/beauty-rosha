// lib/services/smart_image_loader.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../core/app_logger.dart';

class SmartImageLoader {
  static const _logTag = 'SmartImageLoader';

  static final SmartImageLoader _instance = SmartImageLoader._internal();
  factory SmartImageLoader() => _instance;
  SmartImageLoader._internal();

  // Очередь загрузки с приоритетами
  final List<_ImageTask> _queue = [];
  final Set<String> _loading = {};
  final Set<String> _loaded = {};
  final Map<String, Completer<void>> _completers = {};

  Timer? _queueTimer;
  bool _isProcessing = false;

  // Максимальное количество одновременных загрузок
  static const int maxConcurrent = 3;
  static const int maxRetries = 2;

  // Кэш-менеджер
  static final DefaultCacheManager cacheManager = DefaultCacheManager();

  int _activeLoads = 0;

  /// Загрузить изображение с приоритетом (0 — высокий, 100 — низкий).
  Future<void> load(String url, {int priority = 50}) async {
    if (_loaded.contains(url)) return;

    final existingCompleter = _completers[url];
    if (existingCompleter != null && !existingCompleter.isCompleted) {
      return existingCompleter.future;
    }

    final completer = Completer<void>();
    _completers[url] = completer;

    _queue.add(_ImageTask(url: url, priority: priority));
    _queue.sort((a, b) => a.compareTo(b));

    _processQueue();

    return completer.future;
  }

  void _processQueue() {
    if (_isProcessing) return;
    _isProcessing = true;

    _queueTimer?.cancel();
    _queueTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _processNextBatch();
    });
  }

  Future<void> _processNextBatch() async {
    if (_queue.isEmpty) {
      _queueTimer?.cancel();
      _isProcessing = false;
      return;
    }

    if (_activeLoads >= maxConcurrent) return;

    final task = _queue.removeAt(0);
    if (_loading.contains(task.url) || _loaded.contains(task.url)) {
      return;
    }

    _loading.add(task.url);
    _activeLoads++;

    try {
      await _loadWithRetry(task.url);
      _loaded.add(task.url);

      final completer = _completers[task.url];
      if (completer != null && !completer.isCompleted) {
        completer.complete();
      }
    } catch (e) {
      AppLogger.warning(_logTag, 'image load failed: ${task.url}', e);

      final completer = _completers[task.url];
      if (completer != null && !completer.isCompleted) {
        completer.completeError(e);
      }
    } finally {
      _loading.remove(task.url);
      _activeLoads--;
      _completers.remove(task.url);
    }
  }

  Future<void> _loadWithRetry(String url) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        await cacheManager.getSingleFile(url);
        return;
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) rethrow;
        // Экспоненциальная задержка между ретраями
        await Future.delayed(Duration(milliseconds: 300 * attempts));
      }
    }
  }

  /// Проверить, загружено ли изображение.
  bool isLoaded(String url) => _loaded.contains(url);

  /// Очистить кэш для URL.
  Future<void> evict(String url) async {
    _loaded.remove(url);
    await cacheManager.removeFile(url);
  }

  /// Очистить весь кэш.
  Future<void> clearCache() async {
    _loaded.clear();
    await cacheManager.emptyCache();
  }

  /// Получить файл из кэша.
  Future<File?> getCachedFile(String url) async {
    try {
      return await cacheManager.getSingleFile(url);
    } catch (e) {
      return null;
    }
  }
}

class _ImageTask implements Comparable<_ImageTask> {
  final String url;
  final int priority;
  final DateTime timestamp;

  _ImageTask({required this.url, required this.priority})
      : timestamp = DateTime.now();

  @override
  int compareTo(_ImageTask other) {
    // Сначала по приоритету, затем по времени
    final priorityCompare = priority.compareTo(other.priority);
    if (priorityCompare != 0) return priorityCompare;
    return timestamp.compareTo(other.timestamp);
  }
}