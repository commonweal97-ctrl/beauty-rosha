// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
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
  String _countryCode = '7';
  String _countryDial = '+7';
  String _countryFlag = '🇷🇺';
  String? _error;

  final List<Map<String, dynamic>> _countries = [
    {'code': 'ru', 'dial_code': '7', 'flag': '🇷🇺', 'name': 'Россия', 'max_digits': 10},
    {'code': 'kz', 'dial_code': '7', 'flag': '🇰🇿', 'name': 'Казахстан', 'max_digits': 10},
    {'code': 'by', 'dial_code': '375', 'flag': '🇧🇾', 'name': 'Беларусь', 'max_digits': 9},
  ];

  int get _maxDigits {
    final country = _countries.firstWhere(
      (c) => c['dial_code'] == _countryCode,
      orElse: () => _countries.first,
    );
    return country['max_digits'] as int;
  }

  bool get _isFormValid {
    if (_isPhone) {
      final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      return digits.length == _maxDigits;
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
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return '+$_countryCode$digits';
  }

  void _onPhoneChanged(String value) {
    String digits = value.replaceAll(RegExp(r'\D'), '');

    // Автоопределение Беларуси
    if ((digits.startsWith('375') || digits.startsWith('7375')) &&
        _countryCode != '375') {
      setState(() {
        _countryCode = '375';
        _countryDial = '+375';
        _countryFlag = '🇧🇾';
      });
      if (digits.startsWith('7375')) digits = digits.substring(1);
      if (digits.startsWith('375')) digits = digits.substring(3);
    } else if (_countryCode == '375') {
      if (digits.startsWith('7') || digits.startsWith('8')) {
        setState(() {
          _countryCode = '7';
          _countryDial = '+7';
        });
        if (digits.startsWith('8')) digits = '7${digits.substring(1)}';
        if (digits.startsWith('77') && digits.length > 10) {
          digits = digits.substring(1);
        }
        if (digits.startsWith('7')) digits = digits.substring(1);
      }
    } else {
      if (digits.startsWith('77') && digits.length > 10) {
        digits = digits.substring(1);
      }
      if (digits.startsWith('8')) {
        digits = '7${digits.substring(1)}';
      }

      if (digits.startsWith('7') && digits.length >= 2) {
        setState(() => _countryFlag = '🇰🇿');
      } else if (digits.startsWith('9') ||
          digits.startsWith('3') ||
          digits.startsWith('4') ||
          digits.startsWith('5') ||
          digits.startsWith('6') ||
          digits.startsWith('8')) {
        setState(() => _countryFlag = '🇷🇺');
      }
    }

    final maxDigits = _countryCode == '375' ? 9 : 10;
    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);

    String formatted = '';
    if (_countryCode == '7') {
      if (digits.isNotEmpty) {
        formatted += digits.substring(0, digits.length > 3 ? 3 : digits.length);
      }
      if (digits.length > 3) {
        formatted +=
            ' ${digits.substring(3, digits.length > 6 ? 6 : digits.length)}';
      }
      if (digits.length > 6) {
        formatted +=
            ' ${digits.substring(6, digits.length > 8 ? 8 : digits.length)}';
      }
      if (digits.length > 8) formatted += ' ${digits.substring(8)}';
    } else if (_countryCode == '375') {
      if (digits.isNotEmpty) {
        formatted += digits.substring(0, digits.length > 2 ? 2 : digits.length);
      }
      if (digits.length > 2) {
        formatted +=
            ' ${digits.substring(2, digits.length > 5 ? 5 : digits.length)}';
      }
      if (digits.length > 5) {
        formatted +=
            ' ${digits.substring(5, digits.length > 7 ? 7 : digits.length)}';
      }
      if (digits.length > 7) formatted += ' ${digits.substring(7)}';
    }

    _phoneController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() => _error = null);
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

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Выберите страну',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(height: 12),
              ..._countries.map(
                (c) => ListTile(
                  leading: Text(
                    c['flag'] as String,
                    style: TextStyle(fontSize: 32),
                  ),
                  title: Text(
                    c['name'] as String,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: Text(
                    '+${c['dial_code']}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    setState(() {
                      _countryCode = c['dial_code'] as String;
                      _countryDial = '+${c['dial_code']}';
                      _countryFlag = c['flag'] as String;
                      _phoneController.clear();
                    });
                    Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                            child: Row(
                              children: [
                                GestureDetector(
                                  onTap: _showCountryPicker,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 17),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                            color: context.colors.border),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _countryFlag,
                                          style: TextStyle(fontSize: 22),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          _countryDial,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: context.colors.textPrimary,
                                          ),
                                        ),
                                        SizedBox(width: 2),
                                        Icon(
                                          Icons.keyboard_arrow_down,
                                          size: 18,
                                          color: context.colors.textMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                          RegExp(r'[\d\s]')),
                                    ],
                                    onChanged: _onPhoneChanged,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '987 654 32 10',
                                      hintStyle: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        color: context.colors.textDisabled,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 17),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
}