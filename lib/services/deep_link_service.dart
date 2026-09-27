// lib/services/deep_link_service.dart
import 'dart:async';

import 'package:app_links/app_links.dart';

import '../core/app_logger.dart';

/// Сервис для получения deep links от ОС.
///
/// Работает в двух режимах:
///   1. **Cold start** — приложение запущено по ссылке (getInitialLink).
///   2. **Hot start** — приложение уже работает, пользователь кликнул ссылку
///      (uriLinkStream).
///
/// Все приходящие ссылки складываются в [_pendingLinks]. Их забирает
/// `MainShell` (или другой потребитель) через [setListener],
/// когда UI уже готов принимать навигацию.
class DeepLinkService {
  DeepLinkService._();

  static final DeepLinkService instance = DeepLinkService._();

  static const _logTag = 'DeepLinkService';

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// Очередь ссылок, ожидающих обработки.
  /// Ссылки могут прийти ДО того, как UI готов их обработать
  /// (например, при cold start — раньше, чем построен MainShell).
  final List<Uri> _pendingLinks = [];

  /// Колбэк, который вызывается, когда приходит новая ссылка
  /// И уже установлен потребитель (MainShell).
  void Function(Uri uri)? _onLinkReceived;

  bool _initialized = false;

  /// Инициализация сервиса. Вызывать один раз в `main()` ДО runApp.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Cold start — приложение запущено по ссылке.
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        AppLogger.info(_logTag, 'Cold start link: $initialLink');
        _enqueue(initialLink);
      }
    } catch (e, st) {
      AppLogger.error(_logTag, 'getInitialLink failed', e, st);
    }

    // Hot start — приложение уже работает.
    _subscription = _appLinks.uriLinkStream.listen(
      (uri) {
        AppLogger.info(_logTag, 'Hot start link: $uri');
        _enqueue(uri);
      },
      onError: (e, st) {
        AppLogger.error(_logTag, 'uriLinkStream error', e, st);
      },
    );

    AppLogger.info(_logTag, 'initialized');
  }

  void _enqueue(Uri uri) {
    // Если потребитель уже есть — отдаём сразу.
    // Иначе складываем в очередь.
    if (_onLinkReceived != null) {
      _onLinkReceived!(uri);
    } else {
      _pendingLinks.add(uri);
    }
  }

  /// Устанавливает потребителя ссылок.
  /// Сразу отдаёт все накопленные ссылки (по одной).
  void setListener(void Function(Uri uri) listener) {
    _onLinkReceived = listener;

    if (_pendingLinks.isNotEmpty) {
      final pending = List<Uri>.from(_pendingLinks);
      _pendingLinks.clear();

      // Даём шанс UI отрисоваться перед первой навигацией.
      Future.microtask(() {
        for (final uri in pending) {
          listener(uri);
        }
      });
    }
  }

  /// Снимает потребителя (например, при dispose MainShell).
  void clearListener() {
    _onLinkReceived = null;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _initialized = false;
  }
}