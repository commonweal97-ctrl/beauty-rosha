// lib/screens/auth/login_screen.dart
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_logger.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/push_service.dart';
import 'email_input_screen.dart';
import 'otp_screen.dart';
import 'pin_login_screen.dart';
import 'register_screen.dart';
import '../../core/app_colors.dart';
import '../../widgets/common/phone_input.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _logTag = 'LoginScreen';

  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isPhone = true;
  bool _isLoading = false;
  String? _error;

  // Ключ для PhoneInput — чтобы при смене товаров widget пересоздался корректно
  final GlobalKey<PhoneInputState> _phoneKey = GlobalKey<PhoneInputState>();

  bool get _isFormValid {
    if (_isPhone) {
      return _phoneKey.currentState?.isValid ?? false;
    }
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
        .hasMatch(_emailController.text.trim());
  }

  @override
  void initState() {
    super.initState();
}

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String _cleanPhone() {
    // Используем состояние PhoneInput — там правильный dial code + digits
    return _phoneKey.currentState?.fullPhone ?? '';
  }

  Future<void> _continue() async {
    final identifier = _isPhone ? _cleanPhone() : _emailController.text.trim();
    if (identifier.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final type = _isPhone ? 'phone' : 'email';
      final existsResult = await ApiService.checkUserExists(identifier, type);
      if (!mounted) return;

      if (existsResult.isFailure) {
        setState(() =>
            _error = existsResult.errorOrNull?.userMessage ?? 'Ошибка соединения');
        return;
      }

      final existsData = existsResult.valueOrNull?['data'];
      final userExists = existsData is Map && existsData['exists'] == true;

      if (!userExists) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RegisterScreen(identifier: identifier, type: type),
          ),
        );
        return;
      }

      final userId = existsData['user_id'];

      final userResult = await ApiService.checkUser(identifier, type);
      if (!mounted) return;

      if (userResult.isFailure) {
        setState(() =>
            _error = userResult.errorOrNull?.userMessage ?? 'Ошибка соединения');
        return;
      }

      final userData = userResult.valueOrNull?['data'];
      final userEmail = userData is Map ? (userData['user_email'] ?? '') : '';
      final hasEmail = userData is Map ? (userData['has_email'] ?? false) : false;
      final userName = userData is Map ? (userData['user_name'] ?? '') : '';
      final methods = userData is Map ? (userData['methods'] ?? {}) : {};
      final hasPin = methods is Map && methods['pin'] == true;

      final prefs = await SharedPreferences.getInstance();
      final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;
      final deviceHasBiometric = await AuthService.hasBiometrics();
      final hasLocalBiometric = biometricEnabled && deviceHasBiometric;

      if (hasLocalBiometric) {
        final bioOk =
            await AuthService.authenticateWithBiometrics('Войдите в приложение');
        if (bioOk && mounted) {
          await _onBiometricLogin(userId, userName, userEmail);
          return;
        }
      }

      if (hasPin) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PinLoginScreen(
                userId: userId,
                onForgotPin: () {
                  Navigator.pop(context);
                  _sendOtp(userId, userEmail, hasEmail: hasEmail);
                },
              ),
            ),
          );
        }
        return;
      }

      if (!hasEmail) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EmailInputScreen(
                userId: userId,
                phone: identifier,
              ),
            ),
          );
        }
        return;
      }

      await _sendOtp(userId, userEmail, hasEmail: hasEmail);
    } catch (e, st) {
      AppLogger.error(_logTag, 'continue failed', e, st);
      if (mounted) setState(() => _error = 'Ошибка соединения');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOtp(
    int userId,
    String email, {
    bool hasEmail = true,
  }) async {
    await ApiService.sendOtp(userId, email: email);
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpScreen(
          userId: userId,
          email: email,
          phone: _isPhone ? _cleanPhone() : '',
        ),
      ),
    );
  }

  Future<void> _onBiometricLogin(
    int userId,
    String name,
    String email,
  ) async {
    final result = await ApiService.post(
      '/api/auth/biometric-login',
      {'user_id': userId},
    );

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'biometric-login failed: ${result.errorOrNull?.message}',
      );
      await _onLoginSuccess(userId, name, email);
      return;
    }

    final token = (result.valueOrNull?['remember_token'] as String?) ?? '';
    if (token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('remember_token', token);
      await ApiService.setCookie('remember_token=$token');
    }

    await AuthService.saveLogin(userId: userId, name: name, email: email);

    if (mounted) {
      context.read<AuthProvider>().setLoggedIn(
            true,
            userId: userId,
            name: name,
            email: email,
            token: token,
          );
    }

    PushService().syncToken();

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _onLoginSuccess(
    int userId,
    String name,
    String email,
  ) async {
    await AuthService.saveLogin(userId: userId, name: name, email: email);

    final result = await ApiService.post(
      '/api/auth/biometric-login',
      {'user_id': userId},
    );

    final token = result.isSuccess
        ? ((result.valueOrNull?['remember_token'] as String?) ?? '')
        : '';

    if (token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('remember_token', token);
      await ApiService.setCookie('remember_token=$token');
    }

    if (mounted) {
      context.read<AuthProvider>().setLoggedIn(
            true,
            userId: userId,
            name: name,
            email: email,
            token: token,
          );
    }

    PushService().syncToken();

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkTheme =
        Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDarkTheme ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            isDarkTheme ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.colors.surfaceAlt,
        body: SafeArea(
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: context.colors.textPrimary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/logo.png', height: 80),
                        SizedBox(height: 32),
                        Text(
                          'Вход в магазин',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Используйте телефон или почту',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Container(
                          decoration: BoxDecoration(
                            color: context.colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _isPhone = true;
                                    _error = null;
                                  }),
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    padding: EdgeInsets.symmetric(
                                        vertical: 13),
                                    decoration: BoxDecoration(
                                      color: _isPhone
                                          ? context.colors.surface
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(11),
                                      boxShadow: _isPhone
                                          ? [
                                              BoxShadow(
                                                color: context.colors.brand
                                                    .withValues(alpha: 0.1),
                                                blurRadius: 8,
                                                offset: Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Телефон',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: _isPhone
                                              ? context.colors.brand
                                              : context.colors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() {
                                    _isPhone = false;
                                    _error = null;
                                  }),
                                  child: AnimatedContainer(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    padding: EdgeInsets.symmetric(
                                        vertical: 13),
                                    decoration: BoxDecoration(
                                      color: !_isPhone
                                          ? context.colors.surface
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(11),
                                      boxShadow: !_isPhone
                                          ? [
                                              BoxShadow(
                                                color: context.colors.brand
                                                    .withValues(alpha: 0.1),
                                                blurRadius: 8,
                                                offset: Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Почта',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: !_isPhone
                                              ? context.colors.brand
                                              : context.colors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (_isPhone)
                          PhoneInput(
                            key: _phoneKey,
                            controller: _phoneController,
                            hasError: _error != null,
                            onPhoneChanged: (_) {
                              if (_error != null) {
                                setState(() => _error = null);
                              } else {
                                setState(() {});
                              }
                            },
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _error != null
                                    ? Colors.red.withValues(alpha: 0.5)
                                    : context.colors.border,
                              ),
                            ),
                            child: TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'example@mail.ru',
                                hintStyle: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: context.colors.textDisabled,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 17),
                              ),
                              onChanged: (_) =>
                                  setState(() => _error = null),
                            ),
                          ),
                        if (_error != null)
                          Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed:
                                (_isFormValid && !_isLoading) ? _continue : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.colors.brand,
                              disabledBackgroundColor:
                                  context.colors.brand
                                      .withValues(alpha: 0.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Продолжить',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // ── Авторизация через сайт (fallback, если приложение не может) ──
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: context.colors.border,
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'или',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.colors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: context.colors.border,
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton(
                            onPressed: _isLoading ? null : _openWebAuth,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: context.colors.border,
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              foregroundColor: context.colors.textPrimary,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.language_rounded,
                                  size: 20,
                                  color: context.colors.textPrimary,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Войти через сайт',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openWebAuth() async {
    setState(() => _error = null);

    // 1. Получаем state + confirm_url
    final initResp = await ApiService.post('/api/auth/app-init', {
      'device_id': await _webAuthDeviceId(),
      'device_name': await _webAuthDeviceName(),
    });
    if (initResp.isFailure) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось начать вход через сайт. Попробуйте снова.');
      return;
    }
    final d = initResp.valueOrNull?['data'] as Map<String, dynamic>?;
    final state = d?['state'] as String?;
    final confirmUrl = d?['confirm_url'] as String?;
    if (state == null || confirmUrl == null) {
      if (!mounted) return;
      setState(() => _error = 'Сервер не вернул ссылку. Попробуйте снова.');
      return;
    }

    // 2. Открываем системный браузер
    final uri = Uri.parse(confirmUrl);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      if (!mounted) return;
      setState(() => _error = 'Не удалось открыть браузер.');
      return;
    }

    // 3. Поллинг
    final deadline = DateTime.now().add(const Duration(minutes: 10));
    while (mounted && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) return;

      try {
        final pollResp = await ApiService.get('/api/auth/app-poll', queryParams: {'state': state});
        if (pollResp.isFailure) continue;
        final pd = pollResp.valueOrNull?['data'] as Map<String, dynamic>?;
        final status = pd?['status'] as String?;

        if (status == 'confirmed') {
          final token = pd?['remember_token'] as String?;
          if (token != null && token.isNotEmpty) {
            // Polling получил токен — но навигацию делает DeepLinkHandler
            // (deep link beautyrosha://auth?token=...). Здесь только сохраняем.
            await ApiService.setCookie('remember_token=$token');
            // Не делаем checkAuth/popUntil — ждём deep link.
            return;
          }
        } else if (status == 'expired') {
          if (!mounted) return;
          setState(() => _error = 'Ссылка истекла. Попробуйте снова.');
          return;
        }
      } catch (_) {
        // тихо — следующий poll
      }
    }

    if (mounted) {
      setState(() => _error = 'Время ожидания истекло. Попробуйте снова.');
    }
  }

  Future<String> _webAuthDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'web_auth_device_id';
    var id = prefs.getString(key);
    if (id == null || id.isEmpty) {
      id = 'dev_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(key, id);
    }
    return id;
  }

  Future<String> _webAuthDeviceName() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        final model = '${info.manufacturer} ${info.model}'.trim();
        return 'Android · $model';
      } else if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return 'iPhone · ${info.utsname.machine}';
      }
    } catch (_) {}
    return Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iPhone' : 'Устройство');
  }
}