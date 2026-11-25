// lib/core/bonus_rate.dart

/// Единая точка правды: «1 бонус = X <валюта>».
///
/// Immutable value-object. Приходит из бекенда (`App\Services\Bonus\BonusRate`),
/// Flutter **не** форматирует сам (Ozon-way: presentation на бекенде).
///
/// Контракт JSON (см. `BonusController::balance()` → `bonus_rate`):
/// ```json
/// { "amount": 0.04, "currency": "BYN", "decimals": 2, "symbol": "BYN",
///   "formatted": "0.04 BYN", "label": "1 бонус = 0.04 BYN",
///   "subunit_label": "4 копейки" }
/// ```
class BonusRate {
  const BonusRate({
    required this.amount,
    required this.currency,
    required this.decimals,
    required this.symbol,
    required this.formatted,
    required this.label,
    this.subunitLabel,
  });

  final double amount;
  final String currency;
  final int decimals;
  final String symbol;

  /// «0.04 BYN» / «6 ₸» / «1 ₽».
  final String formatted;

  /// «1 бонус = 0.04 BYN» / «1 бонус = 6 ₸» / «1 бонус = 1 ₽».
  final String label;

  /// «4 копейки» (только BYN, amount < 1) — Ozon-way.
  /// null — использовать [formatted].
  final String? subunitLabel;

  /// Готовая строка для UI: «1 бонус ≈ 4 копейки» / «1 бонус = 1 ₽».
  String get displayLabel =>
      subunitLabel != null ? '1 бонус ≈ $subunitLabel' : label;

  factory BonusRate.fromJson(Map<String, dynamic> json) {
    return BonusRate(
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'RUB',
      decimals: (json['decimals'] as num?)?.toInt() ?? 0,
      symbol: json['symbol'] as String? ?? '₽',
      formatted: json['formatted'] as String? ?? '1 ₽',
      label: json['label'] as String? ?? '1 бонус = 1 ₽',
      subunitLabel: json['subunit_label'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'currency': currency,
        'decimals': decimals,
        'symbol': symbol,
        'formatted': formatted,
        'label': label,
        'subunit_label': subunitLabel,
      };

  /// Fallback, если API не вернул `bonus_rate` (старый бекенд / оффлайн).
  /// Ozon-way: лучше показать «1 бонус = 1 ₽», чем ничего.
  static const fallbackRub = BonusRate(
    amount: 1.0,
    currency: 'RUB',
    decimals: 0,
    symbol: '₽',
    formatted: '1 ₽',
    label: '1 бонус = 1 ₽',
  );
}
