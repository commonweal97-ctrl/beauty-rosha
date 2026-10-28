/// Информация об отмене заказа (из /api/orders/cancel-preview)
class CancellationInfo {
  final bool canCancel;
  final String? reason;
  final double fee;
  final double refund;
  final double total;
  final String currency;
  final bool isFree;
  final bool isPaid;
  final String? paymentStatus;
  final String? paymentMethod;
  final String? deliveryMethod;
  final String? deliveryProvider;

  const CancellationInfo({
    required this.canCancel,
    this.reason,
    required this.fee,
    required this.refund,
    required this.total,
    required this.currency,
    required this.isFree,
    required this.isPaid,
    this.paymentStatus,
    this.paymentMethod,
    this.deliveryMethod,
    this.deliveryProvider,
  });

  factory CancellationInfo.fromJson(Map<String, dynamic> json) {
    return CancellationInfo(
      canCancel: json['can_cancel'] == true,
      reason: json['reason'] as String?,
      fee: (json['fee'] as num?)?.toDouble() ?? 0,
      refund: (json['refund'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] as String?) ?? 'RUB',
      isFree: json['is_free'] == true,
      isPaid: json['is_paid'] == true,
      paymentStatus: json['payment_status'] as String?,
      paymentMethod: json['payment_method'] as String?,
      deliveryMethod: json['delivery_method'] as String?,
      deliveryProvider: json['delivery_provider'] as String?,
    );
  }

  String formatMoney(double amount) {
    final symbol = currency == 'RUB'
        ? '₽'
        : (currency == 'BYN' ? 'BYN' : (currency == 'KZT' ? '₸' : currency));
    return '${amount.round()} $symbol';
  }
}
