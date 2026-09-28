// lib/screens/auth/pin_login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/api_error.dart';
import '../../core/app_logger.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../core/app_colors.dart';

class PinLoginScreen extends StatefulWidget {
  final int userId;
  final VoidCallback onForgotPin;

  const PinLoginScreen({
    super.key,
    required this.userId,
    required this.onForgotPin,
  });

  @override
  State<PinLoginScreen> createState() => _PinLoginScreenState();
}

class _PinLoginScreenState extends State<PinLoginScreen> {
  static const _logTag = 'PinLoginScreen';

  String _pin = '';
  String? _error;
  int _attempts = 0;
  bool _verifying = false;

  void _onKey(String key) {
    HapticFeedback.lightImpact();
    if (_pin.length >= 4 || _verifying) return;
    setState(() {
      _pin += key;
      _error = null;
    });
    if (_pin.length == 4) _verify();
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    if (_pin.isEmpty || _verifying) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verify() async {
    if (_verifying) return;
    _verifying = true;

    try {
      final result = await ApiService.verifyPin(widget.userId, _pin);
      if (!mounted) return;

      if (result.isFailure) {
        final error = result.errorOrNull;

        // BusinessError = сервер вернул success: false → неверный PIN
        // Всё остальное = проблема с сетью/сервером
        if (error is BusinessError) {
          _attempts++;
          AppLogger.info(_logTag, 'wrong PIN, attempt $_attempts/3');

          if (_attempts >= 3) {
            widget.onForgotPin();
          } else {
            setState(() {
              _error = 'Неверный PIN. Осталось ${3 - _attempts} попытки';
              _pin = '';
            });
          }
        } else {
          AppLogger.warning(
            _logTag,
            'verifyPin failed: ${error?.message}',
          );
          setState(() {
            _error = error?.userMessage ?? 'Ошибка соединения';
            _pin = '';
          });
        }
        return;
      }

      final response = result.valueOrNull ?? const {};
      final token = response['remember_token'];

      if (token is String && token.isNotEmpty) {
        await AuthService.saveRememberToken(token);
        await ApiService.init();
      }

      final data = response['data'];
      final userData = data is Map ? data['user'] : null;

      await AuthService.saveLogin(
        userId: widget.userId,
        name: (userData is Map ? userData['name'] : null) ?? '',
        email: (userData is Map ? userData['email'] : null) ?? '',
      );

      if (!mounted) return;

      context.read<AuthProvider>().setLoggedIn(
            true,
            userId: widget.userId,
            name: (userData is Map ? userData['name'] : null) ?? '',
            phone: (userData is Map ? userData['phone'] : null) ?? '',
            email: (userData is Map ? userData['email'] : null) ?? '',
          );

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e, st) {
      AppLogger.error(_logTag, 'verifyPin unexpected error', e, st);
      if (mounted) {
        setState(() {
          _error = 'Ошибка соединения';
          _pin = '';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _verifying = false);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surfaceAlt,
      body: SafeArea(
        child: Column(
          children: [
            Spacer(),
            Text(
              'Введите PIN-код',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Для входа в аккаунт',
              style: TextStyle(fontSize: 15, color: context.colors.textSecondary),
            ),
            SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                4,
                (i) => AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  width: 14,
                  height: 14,
                  margin: EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length
                        ? (_error != null
                            ? context.colors.error
                            : context.colors.brand)
                        : (_verifying
                            ? context.colors.brand.withValues(alpha: 0.3)
                            : context.colors.border),
                  ),
                ),
              ),
            ),
            SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: context.colors.error, fontSize: 14),
              )
            else if (_verifying)
              Text(
                'Проверяем...',
                style: TextStyle(color: context.colors.textMuted, fontSize: 14),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3']),
                  SizedBox(height: 16),
                  _buildRow(['4', '5', '6']),
                  SizedBox(height: 16),
                  _buildRow(['7', '8', '9']),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: _verifying ? null : widget.onForgotPin,
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: Center(
                            child: Text(
                              'Не помню\nпин-код',
                              style: TextStyle(
                                fontSize: 11,
                                color: _verifying
                                    ? context.colors.textDisabled
                                    : context.colors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                      _PinKey(
                        label: '0',
                        onTap: () => _onKey('0'),
                        enabled: !_verifying,
                      ),
                      _PinKey(
                        label: '⌫',
                        isBackspace: true,
                        onTap: _onBackspace,
                        enabled: !_verifying,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys
          .map((k) => _PinKey(
                label: k,
                onTap: () => _onKey(k),
                enabled: !_verifying,
              ))
          .toList(),
    );
  }
}

class _PinKey extends StatefulWidget {
  final String label;
  final bool isBackspace;
  final VoidCallback onTap;
  final bool enabled;

  const _PinKey({
    required this.label,
    required this.onTap,
    this.isBackspace = false,
    this.enabled = true,
  });

  @override
  State<_PinKey> createState() => _PinKeyState();
}

class _PinKeyState extends State<_PinKey> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:
          widget.enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap();
            }
          : null,
      onTapCancel:
          widget.enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: _pressed
              ? context.colors.brand
              : (widget.enabled
                  ? context.colors.surfaceAlt
                  : context.colors.surfaceAlt),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: widget.isBackspace
            ? Icon(
                Icons.backspace_outlined,
                size: 26,
                color: _pressed
                    ? Colors.white
                    : (widget.enabled
                        ? context.colors.textPrimary
                        : context.colors.textDisabled),
              )
            : Text(
                widget.label,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                  color: _pressed
                      ? Colors.white
                      : (widget.enabled
                          ? context.colors.textPrimary
                          : context.colors.textDisabled),
                ),
              ),
      ),
    );
  }
}