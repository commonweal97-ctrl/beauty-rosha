// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_logger.dart';
import '../../services/api_service.dart';
import 'otp_screen.dart';
import '../../core/app_colors.dart';

class RegisterScreen extends StatefulWidget {
  final String identifier;
  final String type;
  final Map<String, String>? prefillData;

  const RegisterScreen({
    super.key,
    required this.identifier,
    required this.type,
    this.prefillData,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _logTag = 'RegisterScreen';

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  bool _termsAccepted = false;
  bool _subscribe = true;
  String? _error;
  String _countryCode = '7';
  String _countryDial = '+7';
  String _countryFlag = '🇷🇺';

  final List<Map<String, dynamic>> _countries = [
    {
      'code': 'ru',
      'dial_code': '7',
      'flag': '🇷🇺',
      'name': 'Россия',
      'max_digits': 10
    },
    {
      'code': 'kz',
      'dial_code': '7',
      'flag': '🇰🇿',
      'name': 'Казахстан',
      'max_digits': 10
    },
    {
      'code': 'by',
      'dial_code': '375',
      'flag': '🇧🇾',
      'name': 'Беларусь',
      'max_digits': 9
    },
  ];

  int get _maxDigits {
    final country = _countries.firstWhere(
      (c) => c['dial_code'] == _countryCode,
      orElse: () => _countries.first,
    );
    return country['max_digits'] as int;
  }

  @override
  void initState() {
    super.initState();
if (widget.prefillData != null) {
      _firstNameController.text = widget.prefillData!['first_name'] ?? '';
      _lastNameController.text = widget.prefillData!['last_name'] ?? '';

      if (widget.prefillData!['phone']?.isNotEmpty ?? false) {
        String phone =
            widget.prefillData!['phone']!.replaceAll(RegExp(r'\D'), '');
        if (phone.length > _maxDigits) phone = phone.substring(0, _maxDigits);
        _phoneController.text = phone;
        _onPhoneChanged(phone);
      }
    }

    if (widget.type == 'phone' && widget.prefillData == null) {
      String phone = widget.identifier.replaceAll(RegExp(r'\D'), '');

      if (phone.startsWith('375') || phone.startsWith('7375')) {
        if (phone.startsWith('7375')) phone = phone.substring(1);
        if (phone.startsWith('375')) phone = phone.substring(3);
        setState(() {
          _countryCode = '375';
          _countryDial = '+375';
          _countryFlag = '🇧🇾';
        });
      } else if (phone.startsWith('77') && phone.length > 10) {
        phone = phone.substring(1);
      } else if (phone.startsWith('7') && phone.length > 10) {
        phone = phone.substring(1);
      } else if (phone.startsWith('8')) {
        phone = '7${phone.substring(1)}';
      }

      _phoneController.text = phone;
      _onPhoneChanged(phone);
    } else if (widget.type == 'email') {
      _emailController.text = widget.identifier;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onPhoneChanged(String value) {
    String digits = value.replaceAll(RegExp(r'\D'), '');

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
    } else {
      formatted = digits;
    }
    _phoneController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() => _error = null);
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
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

  Future<void> _register() async {
    if (_firstNameController.text.trim().length < 2) {
      setState(() => _error = 'Введите имя (минимум 2 символа)');
      return;
    }
    if (_lastNameController.text.trim().length < 2) {
      setState(() => _error = 'Введите фамилию (минимум 2 символа)');
      return;
    }
    if (!_emailController.text.trim().contains('@')) {
      setState(() => _error = 'Введите корректный email');
      return;
    }
    if (_phoneController.text.replaceAll(RegExp(r'\D'), '').length <
        _maxDigits) {
      setState(() => _error = 'Введите номер телефона полностью');
      return;
    }
    if (!_termsAccepted) {
      setState(() => _error = 'Примите условия обработки данных');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      String normalizedPhone;

      if (_countryCode == '7') {
        if (digits.startsWith('77') && digits.length > 10) {
          digits = digits.substring(1);
        }
        if (digits.startsWith('8')) {
          digits = '7${digits.substring(1)}';
        }
        normalizedPhone = '+7$digits';
      } else if (_countryCode == '375') {
        if (digits.startsWith('7375')) {
          digits = digits.substring(1);
        }
        normalizedPhone = '+375$digits';
      } else {
        normalizedPhone = '+$_countryCode$digits';
      }

      final email = _emailController.text.trim();

      // Проверка телефона
      final checkPhone =
          await ApiService.checkUserExists(normalizedPhone, 'phone');

      if (checkPhone.isFailure) {
        if (mounted) {
          setState(() {
            _error = checkPhone.errorOrNull?.userMessage ??
                'Ошибка соединения';
            _isLoading = false;
          });
        }
        return;
      }

      final phoneData = checkPhone.valueOrNull?['data'];
      if (phoneData is Map && phoneData['exists'] == true) {
        if (mounted) {
          setState(() {
            _error = 'Пользователь с таким телефоном уже существует';
            _isLoading = false;
          });
        }
        return;
      }

      // Проверка email
      if (email.isNotEmpty && email.contains('@')) {
        final checkEmail = await ApiService.checkUserExists(email, 'email');

        if (checkEmail.isFailure) {
          if (mounted) {
            setState(() {
              _error = checkEmail.errorOrNull?.userMessage ??
                  'Ошибка соединения';
              _isLoading = false;
            });
          }
          return;
        }

        final emailData = checkEmail.valueOrNull?['data'];
        if (emailData is Map && emailData['exists'] == true) {
          if (mounted) {
            setState(() {
              _error = 'Пользователь с таким email уже существует';
              _isLoading = false;
            });
          }
          return;
        }
      }

      // Регистрация
      final result = await ApiService.register(
        phone: normalizedPhone,
        email: email,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        subscribe: _subscribe,
        termsAccepted: _termsAccepted,
      );

      if (!mounted) return;

      if (result.isFailure) {
        setState(() =>
            _error = result.errorOrNull?.userMessage ?? 'Ошибка регистрации');
        return;
      }

      final response = result.valueOrNull;
      if (response == null || response['data'] == null) {
        setState(() => _error = 'Ошибка регистрации');
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            userId: 0,
            email: email,
            isRegistration: true,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            phone: normalizedPhone,
          ),
        ),
      );
    } catch (e, st) {
      AppLogger.error(_logTag, 'register failed', e, st);
      if (mounted) setState(() => _error = 'Ошибка соединения');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openTerms() async {
    final uri = Uri.parse('https://бьютироща.рф/terms');
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 20),
                Text(
                  'Регистрация',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Заполните данные для создания аккаунта',
                  style: TextStyle(fontSize: 15, color: Colors.grey[500]),
                ),
                const SizedBox(height: 32),
                _buildTextField(_firstNameController, 'Имя'),
                const SizedBox(height: 16),
                _buildTextField(_lastNameController, 'Фамилия'),
                const SizedBox(height: 16),
                _buildTextField(
                  _emailController,
                  'Email',
                  type: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.colors.border),
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
                              right: BorderSide(color: context.colors.border),
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
                            FilteringTextInputFormatter.allow(RegExp(r'[\d\s]')),
                          ],
                          onChanged: _onPhoneChanged,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: InputDecoration(
                            hintText: '987 654 32 10',
                            hintStyle: TextStyle(
                              fontSize: 16,
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
                ),
                SizedBox(height: 24),
                InkWell(
                  onTap: () => setState(() => _termsAccepted = !_termsAccepted),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _termsAccepted
                                ? context.colors.brand
                                : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _termsAccepted
                                  ? context.colors.brand
                                  : context.colors.textDisabled,
                              width: 2,
                            ),
                          ),
                          child: _termsAccepted
                              ? Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              text: 'Я принимаю ',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              children: [
                                TextSpan(
                                  text: 'условия обработки данных',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: context.colors.brand,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: 34, top: 2),
                  child: GestureDetector(
                    onTap: _openTerms,
                    child: Text(
                      'Ознакомиться с условиями',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textMuted,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                InkWell(
                  onTap: () => setState(() => _subscribe = !_subscribe),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _subscribe
                                ? context.colors.brand
                                : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _subscribe
                                  ? context.colors.brand
                                  : context.colors.textDisabled,
                              width: 2,
                            ),
                          ),
                          child: _subscribe
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Хочу получать новости, акции и специальные предложения',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(height: 24),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.brand,
                      disabledBackgroundColor:
                          context.colors.brand.withValues(alpha: 0.5),
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
                            'Зарегистрироваться',
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
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    TextInputType type = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 16, color: context.colors.textDisabled),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        ),
      ),
    );
  }
}