// lib/screens/auth/otp_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_logger.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import 'call_verification_screen.dart';
import 'register_screen.dart';
import '../../core/app_colors.dart';

class OtpScreen extends StatefulWidget {
  final int userId;
  final String email;
  final bool isRegistration;
  final String firstName;
  final String lastName;
  final String phone;

  const OtpScreen({
    super.key,
    required this.userId,
    this.email = '',
    this.isRegistration = false,
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _logTag = 'OtpScreen';

  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  String? _error;
  int _attempts = 0;
  int _secondsLeft = 60;
  bool _canResend = false;

  String _maskedEmail(String email) {
    if (!email.contains('@')) return '';
    final parts = email.split('@');
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}***@$domain';
    return '${name.substring(0, 2)}***@$domain';
  }

  @override
  void initState() {
    super.initState();
_startTimer();
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
          _startTimer();
        } else {
          _canResend = true;
        }
      });
    });
  }

  Future<void> _resendOtp() async {
    setState(() {
      _canResend = false;
      _secondsLeft = 60;
      _error = null;
      for (final c in _controllers) {
        c.clear();
      }
    });

    if (widget.isRegistration) {
      if (mounted) {
        setState(() => _error = 'Код уже отправлен. Проверьте почту.');
      }
      _startTimer();
      return;
    }

    final result = await ApiService.sendOtp(widget.userId);

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'resendOtp failed: ${result.errorOrNull?.message}',
      );
      if (mounted) setState(() => _error = 'Ошибка отправки');
      return;
    }

    _startTimer();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() => _error = null);
  }

  String get _code => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    final code = _code;
    if (code.length != 6) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.verifyOtp(widget.userId, code);
      if (!mounted) return;

      if (result.isFailure) {
        _attempts++;
        setState(() {
          _error = _attempts >= 3
              ? 'Слишком много попыток.'
              : 'Неверный код. Осталось ${3 - _attempts} попытки';
          for (final c in _controllers) {
            c.clear();
          }
        });
        _focusNodes[0].requestFocus();
        return;
      }

      final response = result.valueOrNull ?? const {};
      final data = response['data'];

      final newUserId =
          (data is Map ? data['user_id'] : null) ?? widget.userId;
      final token = (response['remember_token'] as String?) ?? '';

      if (token.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('remember_token', token);
        await ApiService.setCookie('remember_token=$token');
        await AuthService.saveRememberToken(token);
      }

      final userData = data is Map ? data['user'] : null;
      final userName = (userData is Map ? userData['name'] : null) ?? '';
      final userEmail =
          (userData is Map ? userData['email'] : null) ?? widget.email;
      final userPhone = (userData is Map ? userData['phone'] : null) ?? '';

      await AuthService.saveLogin(
        userId: newUserId,
        name: userName,
        email: userEmail,
      );

      if (!mounted) return;

      context.read<AuthProvider>().setLoggedIn(
            true,
            userId: newUserId,
            name: userName,
            phone: userPhone,
            email: userEmail,
            token: token,
          );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e, st) {
      AppLogger.error(_logTag, 'verify failed', e, st);
      if (mounted) setState(() => _error = 'Ошибка соединения');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _timerText {
    final m = _secondsLeft ~/ 60;
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Подтверждение',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Код отправлен на ',
                        style: TextStyle(
                          fontSize: 15,
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(
                        text: _maskedEmail(widget.email),
                        style: TextStyle(
                          fontSize: 15,
                          color: context.colors.brand,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.isRegistration)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RegisterScreen(
                              identifier: widget.email,
                              type: 'email',
                              prefillData: {
                                'first_name': widget.firstName,
                                'last_name': widget.lastName,
                                'phone': widget.phone,
                              },
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'Изменить email',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.brand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 8.0;
                    const cells = 6;
                    final totalSpacing = spacing * (cells - 1);
                    final cellWidth =
                        (constraints.maxWidth - totalSpacing) / cells;
                    final cellHeight = cellWidth * (56 / 48);
                    final fontSize = cellWidth * 0.5;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(cells, (index) {
                        return Padding(
                          padding: EdgeInsets.only(
                            right: index < cells - 1 ? spacing : 0,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: SizedBox(
                              width: cellWidth,
                              height: cellHeight,
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (value) =>
                                    _onChanged(index, value),
                                style: TextStyle(
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: context.colors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: _error != null
                                          ? context.colors.error
                                          : context.colors.border,
                                      width: 1.5,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: context.colors.border,
                                      width: 1.5,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: context.colors.brand,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
                if (_error != null)
                  Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      _error!,
                      style:
                          TextStyle(color: context.colors.error, fontSize: 13),
                    ),
                  ),
                SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                        (_code.length == 6 && !_isLoading) ? _verify : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.brand,
                      disabledBackgroundColor: context.colors.brand
                          .withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
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
                            'Подтвердить код',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: widget.phone.isNotEmpty
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CallVerificationScreen(
                                phone: widget.phone,
                                userId: widget.userId,
                                email: widget.email,
                                isRegistration: widget.isRegistration,
                                firstName: widget.firstName,
                                lastName: widget.lastName,
                              ),
                            ),
                          ).then((verified) {
                            if (verified == true && context.mounted) {
                              Navigator.of(context)
                                  .popUntil((route) => route.isFirst);
                            }
                          });
                        }
                      : null,
                  icon: Icon(Icons.phone_callback, size: 22),
                  label: Text(
                    'Подтвердить по звонку',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.textPrimary,
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                if (_canResend)
                  GestureDetector(
                    onTap: _resendOtp,
                    child: Text(
                      'Отправить код повторно',
                      style: TextStyle(
                        fontSize: 15,
                        color: context.colors.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Text(
                    'Отправить код повторно через $_timerText',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.textDisabled,
                    ),
                  ),
                SizedBox(height: 12),
                if (!widget.isRegistration)
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'Войти по паролю',
                      style: TextStyle(
                        fontSize: 14,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}