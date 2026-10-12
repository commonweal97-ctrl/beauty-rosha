// lib/widgets/common/phone_input.dart
// Универсальный ввод телефона: флаг + код страны + маска + автоопределение.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';

class PhoneCountry {
  final String code;
  final String dial;
  final String flag;
  final String name;
  final int maxDigits;

  const PhoneCountry({
    required this.code,
    required this.dial,
    required this.flag,
    required this.name,
    required this.maxDigits,
  });
}

const kPhoneCountries = <PhoneCountry>[
  PhoneCountry(code: 'ru', dial: '7', flag: '🇷🇺', name: 'Россия', maxDigits: 10),
  PhoneCountry(code: 'kz', dial: '7', flag: '🇰🇿', name: 'Казахстан', maxDigits: 10),
  PhoneCountry(code: 'by', dial: '375', flag: '🇧🇾', name: 'Беларусь', maxDigits: 9),
];

class PhoneInput extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onCountryChanged;
  final ValueChanged<String>? onPhoneChanged;
  final PhoneCountry? initialCountry;
  final bool hasError;
  final bool autofocus;
  final String? hintText;
  final FocusNode? focusNode;

  const PhoneInput({
    super.key,
    required this.controller,
    this.onCountryChanged,
    this.onPhoneChanged,
    this.initialCountry,
    this.hasError = false,
    this.autofocus = false,
    this.hintText,
    this.focusNode,
  });

  @override
  State<PhoneInput> createState() => PhoneInputState();
}

class PhoneInputState extends State<PhoneInput> {
  late PhoneCountry _country;

  PhoneCountry get country => _country;

  String get _digits =>
      widget.controller.text.replaceAll(RegExp(r'\D'), '');

  /// Чистый номер: +79991234567
  String get fullPhone => '+${_country.dial}$_digits';

  /// Только цифры (для API): 79991234567
  String get digitsOnly => '${_country.dial}$_digits';

  bool get isValid => _digits.length == _country.maxDigits;

  @override
  void initState() {
    super.initState();
    _country = widget.initialCountry ?? kPhoneCountries.first;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    _format(widget.controller.text);
  }

  void _format(String value) {
    String digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) {
      if (widget.controller.text.isNotEmpty) {
        widget.controller.value = TextEditingValue(
          text: '',
          selection: TextSelection.collapsed(offset: 0),
        );
      }
      return;
    }

    PhoneCountry newCountry = _country;

    // Автоопределение BY
    if ((digits.startsWith('375') || digits.startsWith('7375')) &&
        _country.code != 'by') {
      newCountry = kPhoneCountries.firstWhere((c) => c.code == 'by');
      if (digits.startsWith('7375')) digits = digits.substring(1);
      if (digits.startsWith('375')) digits = digits.substring(3);
    } else if (_country.code == 'by') {
      if (digits.startsWith('7') || digits.startsWith('8')) {
        newCountry = kPhoneCountries.firstWhere((c) => c.code == 'ru');
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
      if (digits.startsWith('8')) digits = '7${digits.substring(1)}';
      if (digits.startsWith('7') && digits.length >= 2) {
        newCountry = kPhoneCountries.firstWhere((c) => c.code == 'kz');
      } else if (RegExp(r'^[3-6,9]').hasMatch(digits)) {
        newCountry = kPhoneCountries.firstWhere((c) => c.code == 'ru');
      }
    }

    if (digits.length > newCountry.maxDigits) {
      digits = digits.substring(0, newCountry.maxDigits);
    }

    final formatted = _applyMask(digits, newCountry);

    if (newCountry != _country) {
      setState(() => _country = newCountry);
      widget.onCountryChanged?.call(newCountry.dial);
    }

    if (widget.controller.text != formatted) {
      widget.controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }

    widget.onPhoneChanged?.call('+${newCountry.dial}$digits');
  }

  String _applyMask(String digits, PhoneCountry c) {
    if (digits.isEmpty) return '';
    if (c.code == 'by') {
      final d = digits;
      final parts = <String>[];
      parts.add('(${d.substring(0, d.length > 2 ? 2 : d.length)}');
      if (d.length > 2) parts.add(') ${d.substring(2, d.length > 4 ? 4 : d.length)}');
      if (d.length > 4) parts.add('-${d.substring(4, d.length > 6 ? 6 : d.length)}');
      if (d.length > 6) parts.add('-${d.substring(6, d.length > 8 ? 8 : d.length)}');
      if (d.length > 8) parts.add('-${d.substring(8)}');
      return parts.join();
    } else {
      final d = digits;
      final parts = <String>[];
      parts.add('(${d.substring(0, d.length > 3 ? 3 : d.length)}');
      if (d.length > 3) parts.add(') ${d.substring(3, d.length > 6 ? 6 : d.length)}');
      if (d.length > 6) parts.add('-${d.substring(6, d.length > 8 ? 8 : d.length)}');
      if (d.length > 8) parts.add('-${d.substring(8)}');
      return parts.join();
    }
  }

  void _openCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              const SizedBox(height: 12),
              ...kPhoneCountries.map((c) {
                final selected = c.code == _country.code;
                return ListTile(
                  leading: Text(c.flag, style: const TextStyle(fontSize: 32)),
                  title: Text(c.name,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                  trailing: Text('+${c.dial}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textSecondary,
                      )),
                  selected: selected,
                  selectedTileColor: context.colors.brandLight,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _country = c;
                      widget.controller.clear();
                    });
                    widget.onCountryChanged?.call(c.dial);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.hasError
              ? Colors.red.withValues(alpha: 0.5)
              : context.colors.border,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _openCountryPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: context.colors.border),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_country.flag, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 6),
                  Text(
                    '+${_country.dial}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.keyboard_arrow_down,
                      size: 18, color: context.colors.textMuted),
                ],
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              keyboardType: TextInputType.phone,
              autofocus: widget.autofocus,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d\s()\-]')),
              ],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText ?? '987 654 32 10',
                hintStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: context.colors.textDisabled,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
