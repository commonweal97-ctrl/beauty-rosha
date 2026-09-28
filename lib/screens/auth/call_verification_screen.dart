// lib/screens/auth/call_verification_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_logger.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../core/app_colors.dart';

class CallVerificationScreen extends StatefulWidget {
  final String phone;
  final int userId;
  final String email;
  final bool isRegistration;
  final String firstName;
  final String lastName;

  const CallVerificationScreen({
    super.key,
    required this.phone,
    required this.userId,
    this.email = '',
    this.isRegistration = false,
    this.firstName = '',
    this.lastName = '',
  });

  @override
  State<CallVerificationScreen> createState() =>
      _CallVerificationScreenState();
}

class _CallVerificationScreenState extends State<CallVerificationScreen> {
  static const _logTag = 'CallVerificationScreen';

  Timer? _checkTimer;
  Timer? _countdownTimer;
  Timer? _verifyCountdownTimer;
  bool _isWaiting = false;
  bool _isChecking = false;
  bool _isVerifying = false;
  String? _error;
  int _secondsLeft = 300;
  int _verifySecondsLeft = 30;

  @override
  void initState() {
    super.initState();
WidgetsBinding.instance.addPostFrameCallback((_) {
      _startChecking();
      _startCountdown();
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _countdownTimer?.cancel();
    _verifyCountdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _secondsLeft = 300;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          timer.cancel();
          _isWaiting = false;
        }
      });
    });
  }

  void _startChecking() {
    setState(() {
      _isWaiting = true;
      _error = null;
    });

    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await _checkVerification();
    });
  }

  String get _timerText {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _verifyTimerText {
    final s = _verifySecondsLeft.toString().padLeft(2, '0');
    return '00:$s';
  }

  Future<void> _checkVerification() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final result = await ApiService.checkCallVerification(widget.phone);

      if (!mounted) return;

      if (result.isSuccess && result.valueOrNull?['verified'] == true) {
        _checkTimer?.cancel();
        _countdownTimer?.cancel();
        _verifyCountdownTimer?.cancel();

        await _performLogin();
      }
    } catch (e) {
  AppLogger.warning(_logTag, 'checkVerification failed', e);
} finally {
      _isChecking = false;
    }
  }

  Future<void> _performLogin() async {
    try {
      if (widget.isRegistration) {
        await _registerByCall();
        return;
      }

      final userResult = await ApiService.checkUser(widget.phone, 'phone');

      if (userResult.isFailure) {
        if (mounted) {
          setState(() {
            _error = userResult.errorOrNull?.userMessage ?? 'Ошибка входа';
            _isVerifying = false;
          });
        }
        return;
      }

      final userData = userResult.valueOrNull?['data'];
      if (userData is! Map || userData['exists'] != true) {
        if (mounted) {
          setState(() {
            _error = 'Пользователь не найден';
            _isVerifying = false;
          });
        }
        return;
      }

      final userId = userData['user_id'];
      final userName = userData['user_name'] ?? '';
      final userEmail = userData['user_email'] ?? widget.email;

      final loginResult = await ApiService.post(
        '/api/auth/login-by-call',
        {'user_id': userId},
      );

      final token = loginResult.isSuccess
          ? ((loginResult.valueOrNull?['remember_token'] as String?) ?? '')
          : '';

      if (token.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('remember_token', token);
        await ApiService.setCookie('remember_token=$token');
      }

      await AuthService.saveLogin(
        userId: userId,
        name: userName,
        email: userEmail,
      );

      if (!mounted) return;

      context.read<AuthProvider>().setLoggedIn(
            true,
            userId: userId,
            name: userName,
            email: userEmail,
            token: token,
          );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e, st) {
      AppLogger.error(_logTag, 'loginByCall failed', e, st);
      if (mounted) {
        setState(() {
          _error = 'Ошибка входа';
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _registerByCall() async {
    try {
      final registerResult = await ApiService.post(
        '/api/auth/register-by-call',
        {
          'phone': widget.phone,
          'email': widget.email,
          'first_name': widget.firstName,
          'last_name': widget.lastName,
        },
      );

      if (registerResult.isFailure) {
        if (mounted) {
          setState(() {
            _error = registerResult.errorOrNull?.userMessage ??
                'Ошибка регистрации';
            _isVerifying = false;
          });
        }
        return;
      }

      final response = registerResult.valueOrNull ?? const {};
      final data = response['data'];
      if (data is! Map) {
        if (mounted) {
          setState(() {
            _error = 'Ошибка регистрации';
            _isVerifying = false;
          });
        }
        return;
      }

      final userId = data['user_id'] ?? 0;
      final token = response['remember_token'] ?? '';
      final userData = data['user'];
      final name = (userData is Map ? userData['name'] : null) ??
          '${widget.firstName} ${widget.lastName}';
      final email = (userData is Map ? userData['email'] : null) ??
          widget.email;

      if (token is String && token.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('remember_token', token);
        await ApiService.setCookie('remember_token=$token');
      }

      await AuthService.saveLogin(
        userId: userId,
        name: name,
        email: email,
      );

      if (!mounted || userId <= 0) return;

      context.read<AuthProvider>().setLoggedIn(
            true,
            userId: userId,
            name: name,
            email: email,
            token: token is String ? token : '',
          );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e, st) {
      AppLogger.error(_logTag, 'registerByCall failed', e, st);
      if (mounted) {
        setState(() {
          _error = 'Ошибка соединения';
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _callNumber() async {
    setState(() {
      _isVerifying = true;
      _isWaiting = false;
      _verifySecondsLeft = 30;
    });

    _verifyCountdownTimer?.cancel();
    _verifyCountdownTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_verifySecondsLeft > 0) {
          _verifySecondsLeft--;
        } else {
          timer.cancel();
          _isVerifying = false;
        }
      });
    });

    ApiService.callVerification(widget.phone).then((result) {
      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'callVerification failed: ${result.errorOrNull?.message}',
        );
      }
    });

    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await _checkVerification();
    });

    final uri = Uri.parse('tel:+79803043674');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              Theme.of(context).brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
          statusBarBrightness:
              Theme.of(context).brightness == Brightness.dark
                  ? Brightness.dark
                  : Brightness.light,
        ),
      child: Scaffold(
        backgroundColor: context.colors.surfaceAlt,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.phone_callback,
                      size: 60,
                      color: context.colors.brand,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Позвоните по номеру телефона',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    GestureDetector(
                      onTap: _callNumber,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.brandLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '+7 (980) 304-36-74',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: context.colors.brand,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Звонок будет сброшен после первого гудка — вход осуществится автоматически',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textMuted,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24),
                    if (_isWaiting) ...[
                      Text(
                        'Ожидание звонка: $_timerText',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _callNumber,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.brand,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Позвонить',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: context.colors.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_isVerifying)
                Positioned.fill(
                  child: Container(
                    color: context.colors.surfaceAlt,
                    child: _buildVerifyingLoader(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyingLoader() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            children: [
              Positioned.fill(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: context.colors.brand,
                ),
              ),
              Center(
                child: Icon(
                  Icons.phone_in_talk,
                  size: 32,
                  color: context.colors.brand.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 28),
        Text(
          'Проверяем ваш номер',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        SizedBox(height: 8),
        Text(
          widget.phone,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: context.colors.textMuted,
          ),
        ),
        SizedBox(height: 16),
        Text(
          _verifyTimerText,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: context.colors.brand,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Ожидайте подтверждения звонка',
          style: TextStyle(fontSize: 14, color: context.colors.textMuted),
        ),
      ],
    );
  }
}