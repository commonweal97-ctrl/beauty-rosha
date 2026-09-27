// lib/services/connectivity_service.dart
import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../core/app_logger.dart';
import '../screens/qr/qr_offline_screen.dart';

class ConnectivityService {
  static const _logTag = 'ConnectivityService';

  static final ConnectivityService _instance = ConnectivityService._();
  factory ConnectivityService() => _instance;
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOffline = false;
  OverlayEntry? _overlayEntry;
  BuildContext? _appContext;
  Timer? _showTimer;

  /// 🔥 Последний тип сети: чтобы понять, «сменилась ли сеть».
  /// Смена сети — единственный повод делать HTTP-проверку.
  String? _lastConnectionType;

  void init(BuildContext appContext) {
    _appContext = appContext;
    _subscription =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    _checkInitialConnectivity();

    // 🔥 Убрано: _periodicTimer с 15-секундным HTTP-пингом.
    // Раньше каждые 15 сек мы дёргали `/` через HTTP — это тратило
    // трафик и батарею пользователя. Теперь HTTP-проверка происходит
    // только при смене типа сети (Wi-Fi ↔ Mobile) или при старте.
  }

  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final type = _classifyConnection(results);
    final changedType = type != _lastConnectionType;
    _lastConnectionType = type;

    if (type == 'offline') {
      _scheduleOfflineOverlay();
      return;
    }

    // Сеть есть.
    if (_isOffline) {
      // Были offline, стали online → скрываем overlay.
      // При смене типа сети — перепроверим реальный HTTP.
      if (changedType && type == 'mobile') {
        _verifyHttpAndUpdate(previousOffline: true);
      } else {
        _isOffline = false;
        _showTimer?.cancel();
        _hideOfflineOverlay();
      }
    } else if (changedType && type == 'mobile') {
      // Были на Wi-Fi, перешли на Mobile → проверим, есть ли реально интернет
      // (Mobile без интернета — частая ситуация в метро).
      _verifyHttpAndUpdate(previousOffline: false);
    }
  }

  String _classifyConnection(List<ConnectivityResult> results) {
    final hasReal = results.any((r) =>
        r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet);
    if (hasReal) return 'real';

    final hasMobile = results.contains(ConnectivityResult.mobile);
    if (hasMobile) return 'mobile';

    return 'offline';
  }

  Future<void> _verifyHttpAndUpdate({required bool previousOffline}) async {
    final httpOk = await _checkViaHttp(timeout: const Duration(seconds: 5));

    if (httpOk) {
      if (previousOffline) {
        _isOffline = false;
        _showTimer?.cancel();
        _hideOfflineOverlay();
      }
    } else {
      if (!previousOffline) {
        _isOffline = true;
        _showOfflineOverlay();
      }
    }
  }

  void _scheduleOfflineOverlay() {
    if (_isOffline) return;

    // Debounce — показываем оверлей только если связь не появилась за 1 сек.
    _showTimer?.cancel();
    _showTimer = Timer(const Duration(seconds: 1), () {
      _isOffline = true;
      _showOfflineOverlay();
    });
  }

  Future<void> _checkInitialConnectivity() async {
    await Future.delayed(const Duration(seconds: 2));

    final results = await _connectivity.checkConnectivity();
    final type = _classifyConnection(results);
    _lastConnectionType = type;

    if (type == 'offline') {
      _isOffline = true;
      _showOfflineOverlay();
    } else if (type == 'mobile') {
      // На старте с мобильной сетью — проверяем HTTP (Mobile без интернета).
      final httpOk = await _checkViaHttp(timeout: const Duration(seconds: 5));
      if (!httpOk) {
        _isOffline = true;
        _showOfflineOverlay();
      }
    }
  }

  Future<void> retry() async {
    final httpOk = await _checkViaHttp(timeout: const Duration(seconds: 1));
    if (!httpOk && !_isOffline) {
      _isOffline = true;
      _showOfflineOverlay();
    } else if (httpOk && _isOffline) {
      _isOffline = false;
      _hideOfflineOverlay();
    }
  }

  Future<bool> _checkViaHttp({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final client = HttpClient();
    client.connectionTimeout = timeout;
    try {
      final request = await client.getUrl(
        Uri.parse('https://xn--80abvyjk6cts.xn--p1ai'),
      );
      // Завершаем запрос — сам ответ нам не нужен,
      // важно только, что соединение удалось.
      await request.close();
      return true;
    } catch (e) {
      AppLogger.warning(_logTag, 'checkViaHttp failed', e);
      return false;
    } finally {
      client.close();
    }
  }

  void _showOfflineOverlay() {
    if (_overlayEntry != null || _appContext == null) return;

    final overlay = Navigator.of(_appContext!).overlay;
    if (overlay == null) return;

    _overlayEntry = OverlayEntry(builder: (_) => const QrOfflineScreen());
    overlay.insert(_overlayEntry!);
  }

  void _hideOfflineOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<bool> isConnected() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  void dispose() {
    _subscription?.cancel();
    _showTimer?.cancel();
    _hideOfflineOverlay();
  }
}