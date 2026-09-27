// lib/services/api_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_error.dart';
import '../core/app_logger.dart';
import '../core/result.dart';

class ApiService {
  ApiService._();

  static const String baseUrl = 'https://xn--80abvyjk6cts.xn--p1ai';
  static const String baseUrlIp = 'https://185.19.206.67';

  static const Duration _requestTimeout = Duration(seconds: 10);
  static const Duration _connectionTimeout = Duration(seconds: 5);
  static const Duration _uploadTimeout = Duration(seconds: 30);
  static const Duration _uploadMultipleTimeout = Duration(seconds: 60);
  static const int _maxRetries = 3;

  static const Duration _cookiePersistDebounce = Duration(seconds: 5);
  static const Duration _cacheDuration = Duration(seconds: 60);
  static const String _logTag = 'ApiService';

  /// 🔥 Интервал health-check: 60 сек когда всё ок, 5 сек когда упало.
  static const Duration _healthOkInterval = Duration(seconds: 60);
  static const Duration _healthFailInterval = Duration(seconds: 5);

  static http.Client _client = http.Client();

  static String? _cookies;
  static DateTime? _lastCookiePersist;
  static Future<void>? _cookiesLoadingFuture;

  static final Map<String, _CachedResponse> _cache = {};

  static bool _isAvailable = true;
  static bool get isAvailable => _isAvailable;

  static Timer? _healthCheckTimer;
  static bool _healthCheckActive = false;

  static final List<void Function(bool isAvailable, bool isBlocking)>
      _availabilityListeners = [];

  static void addAvailabilityListener(
    void Function(bool isAvailable, bool isBlocking) listener,
  ) {
    _availabilityListeners.add(listener);
  }

  static void removeAvailabilityListener(
    void Function(bool isAvailable, bool isBlocking) listener,
  ) {
    _availabilityListeners.remove(listener);
  }

  /// 🔥 Уведомляем только при РЕАЛЬНОЙ смене состояния.
  /// Иначе при недоступном API каждый health-check (5 сек) будет
  /// спамить слушателей.
  static void _notifyAvailability(bool isAvailable, bool isBlocking) {
    if (_isAvailable == isAvailable) return;

    _isAvailable = isAvailable;

    for (final l in List.of(_availabilityListeners)) {
      try {
        l(isAvailable, isBlocking);
      } catch (e, st) {
        AppLogger.error(_logTag, 'availability listener failed', e, st);
      }
    }
  }

  // ============================================================
  //  CACHE
  // ============================================================

  static void clearCache() => _cache.clear();

  static void invalidateCache({String? url, String? prefix}) {
    if (url != null) _cache.remove(url);
    if (prefix != null) {
      _cache.removeWhere((key, _) => key.startsWith(prefix));
    }
  }

  static String? get cookies => _cookies;

  // ============================================================
  //  INIT
  // ============================================================

  static Future<void> init() async {
    await loadCookies();
    startHealthCheck();
  }

  static Future<void> loadCookies() {
    return _cookiesLoadingFuture ??= _doLoadCookies();
  }

  static Future<void> _doLoadCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('remember_token');
      final savedCookies = prefs.getString('saved_cookies');

      final cookieMap = <String, String>{};

      if (savedCookies != null && savedCookies.isNotEmpty) {
        for (final cookie in savedCookies.split('; ')) {
          final parts = cookie.split('=');
          if (parts.length >= 2) {
            cookieMap[parts[0]] = parts.sublist(1).join('=');
          }
        }
      }

      if (savedToken != null && savedToken.isNotEmpty) {
        cookieMap['remember_token'] = savedToken;
      }

      _cookies =
          cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
      AppLogger.info(_logTag, 'Cookies loaded (${cookieMap.length} entries)');
    } catch (e, st) {
      AppLogger.error(_logTag, 'loadCookies failed', e, st);
      _cookiesLoadingFuture = null;
    }
  }

  static Future<void> _persistCookies() async {
    if (_cookies == null || _cookies!.isEmpty) return;

    final now = DateTime.now();
    if (_lastCookiePersist != null &&
        now.difference(_lastCookiePersist!) < _cookiePersistDebounce) {
      return;
    }
    _lastCookiePersist = now;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cookieMap = <String, String>{};
      for (final cookie in _cookies!.split('; ')) {
        final parts = cookie.split('=');
        if (parts.length >= 2) {
          cookieMap[parts[0]] = parts.sublist(1).join('=');
        }
      }

      final clean =
          cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
      await prefs.setString('saved_cookies', clean);

      final token = cookieMap['remember_token'];
      if (token != null && token.isNotEmpty) {
        await prefs.setString('remember_token', token);
      }
    } catch (e, st) {
      AppLogger.error(_logTag, 'persistCookies failed', e, st);
    }
  }

  static void _saveCookies(http.BaseResponse response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null) return;

    final newCookies = setCookie
        .split(',')
        .map((c) => c.trim().split(';').first.trim())
        .where((c) => c.contains('='))
        .join('; ');

    if (newCookies.isEmpty) return;

    final cookieMap = <String, String>{};

    if (_cookies != null && _cookies!.isNotEmpty) {
      for (final cookie in _cookies!.split('; ')) {
        final parts = cookie.split('=');
        if (parts.length >= 2) {
          cookieMap[parts[0]] = parts.sublist(1).join('=');
        }
      }
    }

    for (final cookie in newCookies.split('; ')) {
      final parts = cookie.split('=');
      if (parts.length >= 2) {
        cookieMap[parts[0]] = parts.sublist(1).join('=');
      }
    }

    _cookies = cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');
    _persistCookies();
  }

  static Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'User-Agent': 'BeautyRosha/1.0 (Flutter; Dart)',
    };

    if (_cookies != null && _cookies!.isNotEmpty) {
      headers['Cookie'] = _cookies!;

      for (final cookie in _cookies!.split('; ')) {
        if (cookie.startsWith('csrf_token=')) {
          headers['X-CSRF-Token'] =
              cookie.replaceFirst('csrf_token=', '');
          break;
        }
      }
    }

    return headers;
  }

  static Future<void> setCookie(String cookie) async {
    final parts = cookie.split('=');
    if (parts.length < 2) return;

    final key = parts[0];
    final value = parts.sublist(1).join('=');

    final cookieMap = <String, String>{};
    if (_cookies != null && _cookies!.isNotEmpty) {
      for (final c in _cookies!.split('; ')) {
        final p = c.split('=');
        if (p.length >= 2) {
          cookieMap[p[0]] = p.sublist(1).join('=');
        }
      }
    }
    cookieMap[key] = value;
    _cookies = cookieMap.entries.map((e) => '${e.key}=${e.value}').join('; ');

    await _persistCookies();
  }

  // ============================================================
  //  HEALTH CHECK — адаптивный
  // ============================================================

  static Future<bool> checkApiAvailability() async {
    try {
      final uri = Uri.parse('$baseUrl/api/health');
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(_connectionTimeout);

      final ok = response.statusCode == 200;
      final wasUnavailable = !_isAvailable;

      _notifyAvailability(ok, false);

      if (wasUnavailable && ok) {
        AppLogger.info(_logTag, 'API is available again');
      }

      // 🔥 Перепланируем таймер в зависимости от нового состояния.
      _scheduleNextHealthCheck();

      return ok;
    } catch (e) {
      final isBlocking = isBlockingError(e);
      _notifyAvailability(false, isBlocking);

      _scheduleNextHealthCheck();
      return false;
    }
  }

  static void startHealthCheck() {
    _healthCheckActive = true;
    _healthCheckTimer?.cancel();
    _scheduleNextHealthCheck();
  }

  /// 🔥 Пересоздаёт таймер с интервалом, зависящим от `_isAvailable`.
  static void _scheduleNextHealthCheck() {
    if (!_healthCheckActive) return;

    _healthCheckTimer?.cancel();

    final interval = _isAvailable ? _healthOkInterval : _healthFailInterval;

    _healthCheckTimer = Timer(interval, () {
      checkApiAvailability();
    });
  }

  static void stopHealthCheck() {
    _healthCheckActive = false;
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  // ============================================================
  //  ERROR MAPPING
  // ============================================================

  static bool isBlockingError(Object error) {
    if (error is SocketException) {
      final message = error.message.toLowerCase();
      return message.contains('connection refused') ||
          message.contains('connection reset') ||
          message.contains('network is unreachable') ||
          message.contains('network unreachable') ||
          message.contains('host is down') ||
          message.contains('no route to host') ||
          message.contains('dns') ||
          message.contains('name or service not known');
    }
    if (error is TimeoutException) return true;
    if (error is http.ClientException) {
      final message = error.message.toLowerCase();
      return message.contains('connection') ||
          message.contains('network') ||
          message.contains('dns') ||
          message.contains('timeout');
    }
    return false;
  }

  static ApiError _mapException(Object e, StackTrace st, String path) {
    if (e is TimeoutException) {
      return TimeoutError('Timeout on $path', cause: e, stackTrace: st);
    }
    if (e is SocketException) {
      return NetworkError(
        'Socket error on $path: ${e.message}',
        isBlocking: isBlockingError(e),
        cause: e,
        stackTrace: st,
      );
    }
    if (e is http.ClientException) {
      return NetworkError(
        'Client error on $path: ${e.message}',
        isBlocking: isBlockingError(e),
        cause: e,
        stackTrace: st,
      );
    }
    if (e is ParseError || e is BusinessError || e is ServerError) {
      return e as ApiError;
    }
    return UnknownError('Unexpected on $path: $e',
        cause: e, stackTrace: st);
  }

  // ============================================================
  //  CORE REQUEST
  // ============================================================

  static Future<Result<Map<String, dynamic>>> _request({
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
    bool retry = true,
  }) async {
    if (_cookies == null) {
      await loadCookies();
    }

    if (queryParams != null && queryParams.isNotEmpty) {
      final filtered = queryParams.entries
          .where((e) => e.value != null)
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      if (filtered.isNotEmpty) {
        path = '$path${path.contains('?') ? '&' : '?'}$filtered';
      }
    }

    final uri = Uri.parse('$baseUrl$path');
    final requestTimeout = timeout ?? _requestTimeout;
    final maxAttempts = retry ? _maxRetries + 1 : 1;

    ApiError? lastError;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        http.Response response;

        if (method == 'GET') {
          response = await _client
              .get(uri, headers: _headers)
              .timeout(requestTimeout);
        } else if (method == 'POST') {
          response = await _client
              .post(uri, headers: _headers, body: jsonEncode(body ?? {}))
              .timeout(requestTimeout);
        } else {
          throw ArgumentError('Unsupported method: $method');
        }

        _saveCookies(response);

        if (method == 'POST' &&
            (path.contains('/cart/') || path.contains('/orders/'))) {
          invalidateCache(prefix: '/api/cart/');
          invalidateCache(prefix: '/api/orders/');
        }

        if (response.body.isEmpty) {
          lastError = ParseError(
            'Empty response body from $path (status ${response.statusCode})',
          );
          if (lastError.isRetryable && attempt < maxAttempts - 1) {
            await _backoff(attempt);
            continue;
          }
          return Result.failure(lastError);
        }

        if (response.statusCode == 429) {
          final retryAfterHeader = response.headers['retry-after'];
          final delay = _rateLimitBackoff(attempt, retryAfterHeader);

          lastError = ServerError(
            'Rate limited (429) on $path',
            statusCode: 429,
          );

          if (attempt < maxAttempts - 1) {
            AppLogger.warning(
              _logTag,
              '429 on $path, retrying in ${delay.inMilliseconds}ms '
                  '(attempt ${attempt + 1}/$maxAttempts)',
            );
            await Future.delayed(delay);
            continue;
          }

          AppLogger.warning(
            _logTag,
            '429 on $path, exhausted retries ($maxAttempts)',
          );
          return Result.failure(lastError);
        }

        if (response.statusCode >= 500) {
          lastError = ServerError(
            'Server error ${response.statusCode} on $path',
            statusCode: response.statusCode,
          );
          if (attempt < maxAttempts - 1) {
            await _backoff(attempt);
            continue;
          }
          return Result.failure(lastError);
        }

        Map<String, dynamic> decoded;
        try {
          final raw = jsonDecode(response.body);
          if (raw is! Map<String, dynamic>) {
            return Result.failure(ParseError(
              'Expected JSON object, got ${raw.runtimeType} from $path',
            ));
          }
          decoded = raw;
        } catch (e, st) {
          return Result.failure(ParseError(
            'Invalid JSON from $path: $e',
            cause: e,
            stackTrace: st,
          ));
        }

        if (decoded['success'] == false) {
          return Result.failure(BusinessError(
            (decoded['message'] as String?) ?? 'Request failed',
            payload: decoded,
          ));
        }

        return Result.success(decoded);
      } catch (e, st) {
        final mapped = _mapException(e, st, path);
        lastError = mapped;

        AppLogger.warning(
            _logTag, '$method $path attempt ${attempt + 1}', e);

        if (mapped.isRetryable && attempt < maxAttempts - 1) {
          await _backoff(attempt);
          continue;
        }

        AppLogger.error(_logTag, '$method $path failed permanently', e, st);
        return Result.failure(mapped);
      }
    }

    return Result.failure(lastError ??
        UnknownError('Exhausted retries on $path'));
  }

  /// 🔥 Экспоненциальный backoff с ограничением сверху.
  /// 500ms → 1s → 2s → 4s, максимум 10s.
  static Future<void> _backoff(int attempt) async {
    final ms = (500 * (1 << attempt)).clamp(500, 10000);
    await Future.delayed(Duration(milliseconds: ms));
  }

  /// 🔥 Backoff для 429: если есть Retry-After — уважаем его,
  /// иначе экспоненциальный 1s → 2s → 4s → 8s (максимум 10s).
  static Duration _rateLimitBackoff(int attempt, String? retryAfterHeader) {
    if (retryAfterHeader != null) {
      final seconds = int.tryParse(retryAfterHeader.trim());
      if (seconds != null && seconds > 0) {
        return Duration(seconds: seconds.clamp(1, 10));
      }
    }
    final ms = (1000 * (1 << attempt)).clamp(1000, 10000);
    return Duration(milliseconds: ms);
  }

  // ============================================================
  //  PUBLIC API
  // ============================================================

  static Future<Result<Map<String, dynamic>>> get(
    String path, {
    bool forceRefresh = false,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
  }) async {
    final cacheKey = _buildCacheKey(path, queryParams);
    if (!forceRefresh && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (!cached.isExpired) {
        return Result.success(cached.data);
      }
    }

    final result = await _request(
      method: 'GET',
      path: path,
      queryParams: queryParams,
      timeout: timeout,
    );

    if (result.isSuccess && !forceRefresh) {
      _cache[cacheKey] = _CachedResponse(result.valueOrNull!);
    }

    return result;
  }

    static Future<Result<Map<String, dynamic>>> post(
    String path,
    Map<String, dynamic> body, {
    Duration? timeout,
    bool retry = true,
  }) {
    return _request(
      method: 'POST',
      path: path,
      body: body,
      timeout: timeout,
      retry: retry,
    );
  }

  static String _buildCacheKey(String path, Map<String, dynamic>? params) {
    if (params == null || params.isEmpty) return path;
    final sorted = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final qs = sorted
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
    return '$path?$qs';
  }

  // ============================================================
  //  UPLOAD
  // ============================================================

  static Future<Result<Map<String, dynamic>>> uploadFile(
    String path, {
    required String filePath,
    required String fileName,
    String fieldName = 'file',
    Map<String, String>? additionalFields,
  }) async {
    if (_cookies == null) await loadCookies();

    final uri = Uri.parse('$baseUrl$path');
    ApiError? lastError;

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final request = http.MultipartRequest('POST', uri);
        request.headers['User-Agent'] = 'BeautyRosha/1.0 (Flutter; Dart)';

        if (_cookies != null && _cookies!.isNotEmpty) {
          request.headers['Cookie'] = _cookies!;
          for (final cookie in _cookies!.split('; ')) {
            if (cookie.startsWith('csrf_token=')) {
              request.headers['X-CSRF-Token'] =
                  cookie.replaceFirst('csrf_token=', '');
              break;
            }
          }
        }

        request.files.add(await http.MultipartFile.fromPath(
          fieldName,
          filePath,
          filename: fileName,
        ));

        if (additionalFields != null) {
          request.fields.addAll(additionalFields);
        }

        final streamed = await request.send().timeout(_uploadTimeout);
        final response = await http.Response.fromStream(streamed);
        _saveCookies(response);

        if (response.body.isEmpty) {
          lastError = ParseError('Empty upload response from $path');
          if (attempt < _maxRetries) {
            await _backoff(attempt);
            continue;
          }
          return Result.failure(lastError);
        }

        try {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          if (decoded['success'] == false) {
            return Result.failure(BusinessError(
              (decoded['message'] as String?) ?? 'Upload failed',
              payload: decoded,
            ));
          }
          return Result.success(decoded);
        } catch (e, st) {
          return Result.failure(ParseError(
            'Invalid JSON from upload $path: $e',
            cause: e,
            stackTrace: st,
          ));
        }
      } catch (e, st) {
        lastError = _mapException(e, st, path);
        AppLogger.warning(
            _logTag, 'uploadFile $path attempt ${attempt + 1}', e);
        if (lastError.isRetryable && attempt < _maxRetries) {
          await _backoff(attempt);
          continue;
        }
        return Result.failure(lastError);
      }
    }

    return Result.failure(
        lastError ?? UnknownError('Upload failed after retries'));
  }

  static Future<Result<Map<String, dynamic>>> uploadMultipleFiles(
    String path, {
    required List<String> filePaths,
    String fieldName = 'photos[]',
    Map<String, String>? additionalFields,
    String? videoPath,
  }) async {
    if (_cookies == null) await loadCookies();

    final uri = Uri.parse('$baseUrl$path');
    ApiError? lastError;

    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final request = http.MultipartRequest('POST', uri);
        request.headers['User-Agent'] = 'BeautyRosha/1.0 (Flutter; Dart)';
        request.headers['Accept'] = 'application/json';

        if (_cookies != null && _cookies!.isNotEmpty) {
          request.headers['Cookie'] = _cookies!;
          for (final cookie in _cookies!.split('; ')) {
            if (cookie.startsWith('csrf_token=')) {
              request.headers['X-CSRF-Token'] =
                  cookie.replaceFirst('csrf_token=', '');
              break;
            }
          }
        }

        for (final filePath in filePaths) {
          final fileName = filePath.split('/').last;
          request.files.add(await http.MultipartFile.fromPath(
            fieldName,
            filePath,
            filename: fileName,
          ));
        }

        if (videoPath != null) {
          final videoName = videoPath.split('/').last;
          request.files.add(await http.MultipartFile.fromPath(
            'video',
            videoPath,
            filename: videoName,
          ));
        }

        if (additionalFields != null) {
          request.fields.addAll(additionalFields);
        }

        final streamed =
            await request.send().timeout(_uploadMultipleTimeout);
        final response = await http.Response.fromStream(streamed);
        _saveCookies(response);

        if (response.body.isEmpty) {
          lastError =
              ParseError('Empty multi-upload response from $path');
          if (attempt < _maxRetries) {
            await _backoff(attempt);
            continue;
          }
          return Result.failure(lastError);
        }

        try {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          if (decoded['success'] == false) {
            return Result.failure(BusinessError(
              (decoded['message'] as String?) ?? 'Upload failed',
              payload: decoded,
            ));
          }
          return Result.success(decoded);
        } catch (e, st) {
          return Result.failure(ParseError(
            'Invalid JSON from multi-upload $path: $e',
            cause: e,
            stackTrace: st,
          ));
        }
      } catch (e, st) {
        lastError = _mapException(e, st, path);
        AppLogger.warning(_logTag,
            'uploadMultipleFiles $path attempt ${attempt + 1}', e);
        if (lastError.isRetryable && attempt < _maxRetries) {
          await _backoff(attempt);
          continue;
        }
        return Result.failure(lastError);
      }
    }

    return Result.failure(
        lastError ?? UnknownError('Multi-upload failed after retries'));
  }

  // ============================================================
  //  SESSION
  // ============================================================

  static Future<void> clearSession() async {
    _cookies = null;
    _cookiesLoadingFuture = null;
    _client.close();
    _client = http.Client();
    clearCache();

    /// 🔥 Сбрасываем флаг доступности — иначе следующий health-check
    /// может показать ложный баннер, пока не пройдёт первая проверка.
    _isAvailable = true;

    stopHealthCheck();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_cookies');
    await prefs.remove('remember_token');
    await prefs.remove('isLoggedIn');
    await prefs.remove('userId');
    await prefs.remove('userName');
    await prefs.remove('userPhone');
    await prefs.remove('userEmail');
    await prefs.remove('fcm_token');
    await prefs.remove('cached_qr_card');

    startHealthCheck();
  }

  // ============================================================
  //  CONVENIENCE ENDPOINTS
  // ============================================================

  static Future<Result<Map<String, dynamic>>> appInit() =>
      get('/api/app/init', forceRefresh: true);

  static Future<Result<Map<String, dynamic>>> checkUser(
          String identifier, String type) =>
      post('/api/auth/check', {'identifier': identifier, 'type': type});

  static Future<Result<Map<String, dynamic>>> checkUserExists(
          String identifier, String type) =>
      post('/api/auth/check-user', {'identifier': identifier, 'type': type});

  static Future<Result<Map<String, dynamic>>> sendOtp(int userId,
      {String? email}) {
    final body = <String, dynamic>{'user_id': userId};
    if (email != null && email.isNotEmpty) body['email'] = email;
    return post('/api/auth/send-otp', body);
  }

  static Future<Result<Map<String, dynamic>>> verifyOtp(
          int userId, String code) =>
      post('/api/auth/verify-otp', {
        'user_id': userId,
        'otp_code': code,
        'remember': true,
      });

  static Future<Result<Map<String, dynamic>>> register({
    required String phone,
    required String email,
    required String firstName,
    required String lastName,
    bool subscribe = true,
    bool termsAccepted = false,
  }) =>
      post('/api/auth/register', {
        'phone': phone,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'role': 'client',
        'subscribe': subscribe,
        'terms_accepted': termsAccepted,
      });

  static Future<Result<Map<String, dynamic>>> verifyPin(
          int userId, String pin) =>
      post('/api/security/verify-pin', {
        'user_id': userId,
        'pin_code': pin,
      });

  static Future<Result<Map<String, dynamic>>> getSecurityStatus() =>
      get('/api/security/status', forceRefresh: true);

  static Future<Result<Map<String, dynamic>>> logout() async {
    final result = await post('/api/auth/logout', {});
    await clearSession();
    return result;
  }

  static Future<Result<Map<String, dynamic>>> checkSession() =>
      get('/api/auth/check', forceRefresh: true);

  static Future<Result<Map<String, dynamic>>> toggleFavoriteBrand(
          int brandId) =>
      post('/api/favorite-brands/toggle', {'brand_id': brandId});

  static Future<Result<Map<String, dynamic>>> checkFavoriteBrand(
          int brandId) =>
      get('/api/favorite-brands/check',
          queryParams: {'brand_id': brandId});

  static Future<Result<Map<String, dynamic>>> checkFavoriteBrandsBatch(
          List<int> brandIds) =>
      post('/api/favorite-brands/check-batch', {'brand_ids': brandIds});

  static Future<Result<Map<String, dynamic>>> getFavoriteBrands(
          {int page = 1, int limit = 20}) =>
      get('/api/favorite-brands/items',
          queryParams: {'page': page, 'limit': limit});

  static Future<int> getFavoriteBrandsCount() async {
    final result = await get('/api/favorite-brands/count');
    if (result.isSuccess) {
      return (result.valueOrNull?['data']?['count'] as int?) ?? 0;
    }
    return 0;
  }

  static Future<Result<Map<String, dynamic>>> callVerification(
          String phone) =>
      post('/api/auth/call-verification', {'phone': phone});

  static Future<Result<Map<String, dynamic>>> checkCallVerification(
          String phone) =>
      get('/api/auth/check-call-verification',
          queryParams: {'phone': phone}, forceRefresh: true);
}

class _CachedResponse {
  final Map<String, dynamic> data;
  final DateTime timestamp;

  _CachedResponse(this.data) : timestamp = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(timestamp) > ApiService._cacheDuration;
}