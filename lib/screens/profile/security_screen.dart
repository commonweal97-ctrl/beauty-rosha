// lib/screens/profile/security_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_logger.dart';
import '../../services/api_service.dart';
import '../../core/app_colors.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  static const _logTag = 'SecurityScreen';

  bool _hasPin = false;
  bool _hasBiometric = false;
  bool _hasPassword = false;
  bool _isLoading = true;
  bool _biometricInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final statusResult = await ApiService.getSecurityStatus();
      final passwordResult = await ApiService.get(
        '/api/security/password-status',
      );

      if (!mounted) return;

      if (statusResult.isSuccess) {
        final data = statusResult.valueOrNull?['data'];
        if (data is Map) {
          _hasPin = data['has_pin'] == true;
        }
      } else {
        AppLogger.warning(
          _logTag,
          'getSecurityStatus failed: '
              '${statusResult.errorOrNull?.message}',
        );
      }

      if (passwordResult.isSuccess) {
        final data = passwordResult.valueOrNull?['data'];
        if (data is Map) {
          _hasPassword = data['has_password'] == true;
        }
      } else {
        AppLogger.warning(
          _logTag,
          'password-status failed: '
              '${passwordResult.errorOrNull?.message}',
        );
      }

      final localAuth = LocalAuthentication();
      final canCheck = await localAuth.canCheckBiometrics;
      final available = await localAuth.getAvailableBiometrics();
      final deviceHasBiometric = canCheck && available.isNotEmpty;

      final prefs = await SharedPreferences.getInstance();
      final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;

      if (!mounted) return;
      _hasBiometric = deviceHasBiometric && biometricEnabled;
    } catch (e, st) {
      AppLogger.error(_logTag, 'loadData failed', e, st);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      setState(() => _biometricInProgress = true);
      try {
        final auth = LocalAuthentication();
        final ok = await auth.authenticate(
          localizedReason: 'Включить вход по биометрии',
          options: const AuthenticationOptions(stickyAuth: true),
        );
        if (ok && mounted) {
          setState(() => _hasBiometric = true);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('biometric_enabled', true);
        }
      } catch (e) {
        AppLogger.warning(_logTag, 'biometric authenticate failed', e);
        if (mounted) setState(() => _hasBiometric = false);
      } finally {
        if (mounted) setState(() => _biometricInProgress = false);
      }
    } else {
      setState(() => _hasBiometric = false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', false);
    }
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: context.colors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.colors.brand, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      );

  void _showPinSetup() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PinSetupScreen(
          onPinSet: (String pin) async {
            final result = await ApiService.post(
              '/api/security/setup-pin',
              {
                'pin_code': pin,
                'confirm_pin': pin,
              },
            );
            if (result.isFailure) {
              AppLogger.warning(
                _logTag,
                'setup-pin failed: ${result.errorOrNull?.message}',
              );
              return;
            }
            if (mounted) setState(() => _hasPin = true);
          },
        ),
      ),
    );
  }

  void _showPasswordDialog() {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _hasPassword ? 'Смена пароля' : 'Установка пароля',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              if (_hasPassword)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: currentController,
                    obscureText: true,
                    style: const TextStyle(fontSize: 16),
                    decoration: _inputDecoration('Текущий пароль'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: newController,
                  obscureText: true,
                  style: const TextStyle(fontSize: 16),
                  decoration: _inputDecoration('Новый пароль'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: confirmController,
                  obscureText: true,
                  style: const TextStyle(fontSize: 16),
                  decoration: _inputDecoration('Повторите пароль'),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final newPass = newController.text.trim();
                    if (newPass.length < 6) {
                      setSheetState(() => error = 'Минимум 6 символов');
                      return;
                    }
                    if (newPass != confirmController.text.trim()) {
                      setSheetState(() => error = 'Пароли не совпадают');
                      return;
                    }

                    final result = await ApiService.post(
                      '/api/security/change-password',
                      {
                        'current_password': currentController.text,
                        'new_password': newPass,
                      },
                    );

                    if (result.isFailure) {
                      AppLogger.warning(
                        _logTag,
                        'change-password failed: '
                            '${result.errorOrNull?.message}',
                      );
                      setSheetState(
                        () => error = result.errorOrNull?.userMessage ??
                            'Ошибка соединения',
                      );
                      return;
                    }

                    if (mounted) setState(() => _hasPassword = true);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Сохранить',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deletePassword() async {
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Удаление пароля'),
        content: Text('Вы уверены, что хотите удалить пароль?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Отмена',
              style: TextStyle(color: context.colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final result = await ApiService.post(
      '/api/security/delete-password',
      {},
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'delete-password failed: ${result.errorOrNull?.message}',
      );
      return;
    }

    setState(() => _hasPassword = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surfaceAlt,
      appBar: AppBar(
        title: Text(
          'Безопасный вход',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: context.colors.brand,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: context.colors.brand,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Быстрый вход',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SwitchListTile(
                        secondary: Icon(Icons.dialpad),
                        title: Text(
                          'PIN-код',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _hasPin ? '✓ Подключен' : 'Не подключен',
                          style: TextStyle(
                            fontSize: 13,
                            color: _hasPin
                                ? context.colors.success
                                : context.colors.textMuted,
                          ),
                        ),
                        value: _hasPin,
                        onChanged: (v) {
                          if (v) {
                            _showPinSetup();
                          } else {
                            ApiService.post(
                              '/api/security/setup-pin',
                              {'disable': true},
                            ).then((result) {
                              if (result.isFailure) {
                                AppLogger.warning(
                                  _logTag,
                                  'disable-pin failed: '
                                      '${result.errorOrNull?.message}',
                                );
                              }
                            });
                            setState(() => _hasPin = false);
                          }
                        },
                        activeThumbColor: context.colors.brand,
                      ),
                      Divider(height: 1, indent: 56),
                      SwitchListTile(
                        secondary: _biometricInProgress
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: context.colors.brand,
                                ),
                              )
                            : Icon(Icons.fingerprint),
                        title: Text(
                          'Биометрия',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          _hasBiometric ? '✓ Подключена' : 'Не подключена',
                          style: TextStyle(
                            fontSize: 13,
                            color: _hasBiometric
                                ? context.colors.success
                                : context.colors.textMuted,
                          ),
                        ),
                        value: _hasBiometric,
                        onChanged:
                            _biometricInProgress ? null : _toggleBiometric,
                        activeThumbColor: context.colors.brand,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Пароль',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.lock_outline),
                        title: Text('Пароль'),
                        subtitle: Text(
                          _hasPassword
                              ? '✓ Установлен'
                              : 'Не установлен',
                          style: TextStyle(
                            fontSize: 13,
                            color: _hasPassword
                                ? context.colors.success
                                : context.colors.textMuted,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: _showPasswordDialog,
                              child: Text(
                                _hasPassword ? 'Сменить' : 'Установить',
                                style: TextStyle(
                                  color: context.colors.brand,
                                ),
                              ),
                            ),
                            if (_hasPassword)
                              TextButton(
                                onPressed: _deletePassword,
                                child: const Text(
                                  'Удалить',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ===== ЭКРАН УСТАНОВКИ PIN =====
class _PinSetupScreen extends StatefulWidget {
  final Function(String pin) onPinSet;

  const _PinSetupScreen({required this.onPinSet});

  @override
  State<_PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<_PinSetupScreen> {
  String _pin = '';
  String _firstPin = '';
  bool _isConfirm = false;
  String? _error;

  void _onKey(String key) {
    HapticFeedback.lightImpact();
    if (_pin.length >= 4) return;
    setState(() {
      _pin += key;
      _error = null;
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        if (!_isConfirm) {
          _firstPin = _pin;
          _pin = '';
          setState(() => _isConfirm = true);
        } else if (_pin == _firstPin) {
          widget.onPinSet(_firstPin);
          Navigator.pop(context);
        } else {
          _pin = '';
          setState(() => _error = 'PIN-коды не совпадают');
        }
      });
    }
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.close,
                        size: 18,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Spacer(),
            Text(
              _isConfirm ? 'Повторите PIN-код' : 'Придумайте PIN-код',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _isConfirm
                  ? 'Введите PIN-код ещё раз'
                  : '4 цифры для быстрого входа',
              style: TextStyle(
                fontSize: 15,
                color: context.colors.textSecondary,
              ),
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
                            ? Colors.red
                            : context.colors.brand)
                        : context.colors.border,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3']),
                  const SizedBox(height: 16),
                  _buildRow(['4', '5', '6']),
                  const SizedBox(height: 16),
                  _buildRow(['7', '8', '9']),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 72, height: 72),
                      _PinKey(label: '0', onTap: () => _onKey('0')),
                      _PinKey(
                        label: '⌫',
                        isBackspace: true,
                        onTap: _onBackspace,
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
          .map((k) => _PinKey(label: k, onTap: () => _onKey(k)))
          .toList(),
    );
  }
}

class _PinKey extends StatefulWidget {
  final String label;
  final bool isBackspace;
  final VoidCallback onTap;

  const _PinKey({
    required this.label,
    required this.onTap,
    this.isBackspace = false,
  });

  @override
  State<_PinKey> createState() => _PinKeyState();
}

class _PinKeyState extends State<_PinKey> with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color:
              _pressed ? context.colors.brand : context.colors.surfaceAlt,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: widget.isBackspace
            ? Icon(
                Icons.backspace_outlined,
                size: 26,
                color:
                    _pressed ? Colors.white : context.colors.textPrimary,
              )
            : Text(
                widget.label,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                  color: _pressed ? Colors.white : context.colors.textPrimary,
                ),
              ),
      ),
    );
  }
}