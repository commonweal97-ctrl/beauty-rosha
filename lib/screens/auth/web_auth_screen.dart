import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';
import '../../services/api_service.dart';
import '../../core/app_logger.dart';

/// Экран входа через сайт (web-auth).
///
/// 1. POST /api/auth/app-init → {state, confirm_url}
/// 2. Открывает WebView → confirm_url (пользователь подтверждает вход на сайте)
/// 3. Поллит /api/auth/app-poll?state=... каждые 3 сек
/// 4. При confirmed — возвращает {remember_token, user} через Navigator.pop
class WebAuthScreen extends StatefulWidget {
  const WebAuthScreen({super.key});

  @override
  State<WebAuthScreen> createState() => _WebAuthScreenState();
}

class _WebAuthScreenState extends State<WebAuthScreen> {
  static const _logTag = 'WebAuthScreen';
  static const _baseUrl = 'https://xn--80abvyjk6cts.xn--p1ai';
  static const _pollInterval = Duration(seconds: 3);
  static const _maxPollTime = Duration(minutes: 10);

  String? _state;
  String? _confirmUrl;
  String? _error;
  bool _loading = true;
  bool _confirmed = false;
  Timer? _pollTimer;
  DateTime? _startedAt;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final deviceId = await _buildDeviceId();
      final resp = await http.post(
        Uri.parse('$_baseUrl/api/auth/app-init'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'device_id': deviceId,
          'device_name': _deviceName(),
        }),
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'Ошибка init');
      }
      final d = data['data'] as Map<String, dynamic>;
      _state = d['state'] as String;
      _confirmUrl = d['confirm_url'] as String;
      _startedAt = DateTime.now();

      if (!mounted) return;
      setState(() {
        _loading = false;
      });

      _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());
    } catch (e, st) {
      AppLogger.error(_logTag, 'init failed', e, st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось начать вход через сайт. Попробуйте снова.';
      });
    }
  }

  Future<void> _poll() async {
    if (_confirmed || _state == null) return;
    if (_startedAt != null &&
        DateTime.now().difference(_startedAt!) > _maxPollTime) {
      _pollTimer?.cancel();
      if (!mounted) return;
      setState(() => _error = 'Время ожидания истекло. Попробуйте снова.');
      return;
    }

    try {
      final resp = await http.get(
        Uri.parse('$_baseUrl/api/auth/app-poll?state=$_state'),
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) return;
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['success'] != true) return;
      final d = data['data'] as Map<String, dynamic>;
      final status = d['status'] as String?;

      if (status == 'confirmed') {
        _confirmed = true;
        _pollTimer?.cancel();
        final token = d['remember_token'] as String?;
        if (token == null || token.isEmpty) {
          if (!mounted) return;
          setState(() => _error = 'Сервер не вернул токен');
          return;
        }
        await ApiService.setCookie('remember_token=$token');
        if (!mounted) return;
        Navigator.of(context).pop(<String, dynamic>{
          'remember_token': token,
          'user': d['user'],
        });
      } else if (status == 'expired') {
        _pollTimer?.cancel();
        if (!mounted) return;
        setState(() => _error = 'Ссылка истекла. Попробуйте снова.');
      }
    } catch (e) {
      // Тихо — следующий poll через 3 сек
    }
  }

  String _deviceName() {
    // Простое имя — модель можно уточнить через device_info_plus
    return 'Android-устройство';
  }

  Future<String> _buildDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'web_auth_device_id';
    var id = prefs.getString(key);
    if (id == null || id.isEmpty) {
      id = 'dev_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
      await prefs.setString(key, id);
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Вход через сайт',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.colors.textMuted),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: context.colors.textPrimary),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _loading = true;
                    });
                    _start();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Попробовать снова',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return InAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(_confirmUrl!)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: false,
        transparentBackground: true,
        isInspectable: true,
      ),
    );
  }
}
