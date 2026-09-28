// lib/screens/auth/email_input_screen.dart
import 'package:flutter/material.dart';

import '../../core/app_logger.dart';
import '../../services/api_service.dart';
import 'otp_screen.dart';
import '../../core/app_colors.dart';

class EmailInputScreen extends StatefulWidget {
  final int userId;
  final String phone;

  const EmailInputScreen({
    super.key,
    required this.userId,
    required this.phone,
  });

  @override
  State<EmailInputScreen> createState() => _EmailInputScreenState();
}

class _EmailInputScreenState extends State<EmailInputScreen> {
  static const _logTag = 'EmailInputScreen';

  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  bool get _isValid => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
      .hasMatch(_emailController.text.trim());

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final email = _emailController.text.trim();
    if (!_isValid) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ApiService.sendOtp(widget.userId, email: email);

      if (!mounted) return;

      if (result.isFailure) {
        setState(() =>
            _error = result.errorOrNull?.userMessage ?? 'Ошибка отправки кода');
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(userId: widget.userId, email: email),
        ),
      );
    } catch (e, st) {
      AppLogger.error(_logTag, 'continue failed', e, st);
      if (mounted) setState(() => _error = 'Ошибка соединения');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
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
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color:
                              context.colors.brand.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mail_outline_rounded,
                          size: 36,
                          color: context.colors.brand,
                        ),
                      ),
                      SizedBox(height: 28),
                      Text(
                        'Укажите email',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Мы нашли ваш аккаунт\nпо номеру ${widget.phone}',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[500],
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Укажите email для входа',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 36),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _error != null
                                ? Colors.red.withValues(alpha: 0.5)
                                : Color(0xFFEEEEEE),
                          ),
                        ),
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofocus: true,
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
                              horizontal: 16,
                              vertical: 17,
                            ),
                          ),
                          onChanged: (_) => setState(() => _error = null),
                          onSubmitted: (_) => _isValid ? _continue() : null,
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
                              (_isValid && !_isLoading) ? _continue : null,
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
                      Text(
                        'На этот email будет отправлен код подтверждения',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400],
                        ),
                        textAlign: TextAlign.center,
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
    );
  }
}