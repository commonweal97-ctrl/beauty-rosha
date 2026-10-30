// lib/core/price_formatter.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/currency_provider.dart';

extension PriceFormatter on BuildContext {
  /// Форматирует цену в текущей валюте пользователя.
  /// Возвращает Widget, обёрнутый в `Consumer<CurrencyProvider>` — 
  /// автоматически перестраивается при смене валюты.
  Widget formatPrice(
    double rubAmount, {
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w600,
    Color? color,
    TextDecoration? decoration,
    String prefix = '',
    String suffix = '',
    int? maxLines,
  }) {
    return Consumer<CurrencyProvider>(
      builder: (context, currency, _) {
        final isByn = currency.currency == 'BYN';
        final converted = currency.convert(rubAmount);
        final priceStr = _formatNumber(converted, currency.currency);
        final symbolFontSize = isByn ? fontSize * 1.15 : fontSize;

        return Text.rich(
          TextSpan(
            children: [
              if (prefix.isNotEmpty)
                TextSpan(
                  text: prefix,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                    color: color,
                    decoration: decoration,
                  ),
                ),
              TextSpan(
                text: priceStr,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  color: color,
                  decoration: decoration,
                ),
              ),
              TextSpan(
                text: ' ${currency.symbol}',
                style: TextStyle(
                  fontFamily: isByn ? 'NBRB' : null,
                  fontSize: symbolFontSize,
                  fontWeight: fontWeight,
                  color: color,
                  decoration: decoration,
                ),
              ),
              if (suffix.isNotEmpty)
                TextSpan(
                  text: suffix,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: fontWeight,
                    color: color,
                    decoration: decoration,
                  ),
                ),
            ],
          ),
          maxLines: maxLines,
        );
      },
    );
  }

  String formatPricePlain(double rubAmount) {
    final currency = read<CurrencyProvider>();
    final converted = currency.convert(rubAmount);
    return '${_formatNumber(converted, currency.currency)} ${currency.symbol}';
  }

  String _formatNumber(double value, String currency) {
    if (currency == 'BYN') return value.toStringAsFixed(2);
    if (value == value.roundToDouble()) return '${value.toInt()}';
    return value.toStringAsFixed(2);
  }
}
