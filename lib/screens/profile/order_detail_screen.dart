// lib/screens/profile/order_detail_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_logger.dart';
import '../../providers/cart_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/order_refresh_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/image_loader.dart';
import '../../widgets/order/delivery_progress_bar.dart';
import '../../widgets/rate_product_sheet.dart';
import '../../widgets/common/support_icon_with_badge.dart';
import '../checkout/payment_webview_screen.dart';
import '../main_shell.dart';
import '../product/product_detail_screen.dart';
import 'support_screen.dart';
import '../../core/app_colors.dart';
import '../../widgets/checkout/cancel_order_dialog.dart';
import '../../services/orders_api.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  static const _logTag = 'OrderDetailScreen';

  Map<String, dynamic>? _order;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _isCancelling = false;
  bool _trackingLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final result = await ApiService.get(
      '/api/orders/detail?order_id=${widget.orderId}',
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadDetail(${widget.orderId}) failed: '
            '${result.errorOrNull?.message}',
      );
      setState(() => _isLoading = false);
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! List || data.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    final first = data.first;
    if (first is! Map) {
      setState(() => _isLoading = false);
      return;
    }

    final order = Map<String, dynamic>.from(first);
    final items = data
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();

    setState(() {
      _order = order;
      _items = items;
      _isLoading = false;
    });
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  String _formatPrice(double price) {
    final currency = context.read<CurrencyProvider>();
    return '${price.round()} ${currency.symbol}';
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
        'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _getPaymentMethodText(String method) {
    switch (method) {
      case 'card':
        return 'Картой онлайн';
      case 'cod':
        return 'При получении';
      case 'podeli':
        return 'Подели';
      case 'yandex_split':
        return 'Сплит';
      case 'invoice':
        return 'По счёту';
      default:
        return method.isNotEmpty ? method : 'Не указан';
    }
  }

  Future<void> _callPhone(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _cancelOrder() async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);

    try {
      // 1. Preview
      final preview = await OrdersApi.cancelPreview(widget.orderId);
      if (!mounted) return;

      if (preview.isFailure) {
        _showSnack(preview.errorOrNull?.userMessage ?? 'Не удалось получить данные');
        return;
      }

      final info = preview.valueOrNull!;
      if (!info.canCancel) {
        _showSnack(info.reason ?? 'Нельзя отменить этот заказ');
        return;
      }

      // 2. Диалог
      final confirmed = await CancelOrderDialog.show(context, widget.orderId, info);
      if (confirmed != true || !mounted) return;

      // 3. Отмена
      final cancelResult = await OrdersApi.cancel(widget.orderId);
      if (!mounted) return;

      if (cancelResult.isSuccess) {
        _showSnack('Заказ отменён');
        await _loadDetail();  // обновить статус
      } else {
        _showSnack(cancelResult.errorOrNull?.userMessage ?? 'Не удалось отменить');
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }


  Future<void> _openPayment() async {
    final order = _order;
    if (order == null) return;

    final orderId = widget.orderId;
    final total = _parseDouble(order['total']);
    final deliveryMethod = order['delivery_method'] ?? '';
    final deliveryCost = _parseDouble(order['delivery_cost']);
    final orderStatus = order['status'] ?? '';
    final currency = context.read<CurrencyProvider>().currency;

    if (currency != 'RUB') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Счёт будет направлен на вашу почту'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }

    final isAwaitingPayment = orderStatus == 'awaiting_payment';

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Выберите способ оплаты',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              _buildPaymentOption(
                iconPath: 'assets/payment/card-credit-finance.svg',
                title: 'Картой онлайн',
                subtitle: 'Банковской картой',
                onTap: () {
                  Navigator.pop(ctx);
                  _startPayment(orderId, total, 'card');
                },
              ),
              if (isAwaitingPayment &&
                  deliveryCost == 0 &&
                  (deliveryMethod == 'pickup-store' ||
                      deliveryMethod == 'courier'))
                _buildPaymentOption(
                  iconPath:
                      'assets/payment/hand-money-cash-hold-coins.svg',
                  title: 'При получении',
                  subtitle: 'Оплата при получении заказа',
                  onTap: () {
                    Navigator.pop(ctx);
                    ApiService.post(
                      '/api/admin/orders/update-detail',
                      {
                        'order_id': orderId,
                        'payment_method': 'cod',
                      },
                    ).then((result) {
                      if (result.isFailure) {
                        AppLogger.warning(
                          _logTag,
                          'update-detail (cod) failed: '
                              '${result.errorOrNull?.message}',
                        );
                      }
                    });
                    _loadDetail();
                  },
                ),
              if (total <= 30000)
                _buildPaymentOption(
                  iconPath: 'assets/payment/logo_podeli.png',
                  title: 'Подели',
                  subtitle: 'Оплата частями без переплат',
                  onTap: () {
                    Navigator.pop(ctx);
                    _startPayment(orderId, total, 'podeli');
                  },
                ),
              const SizedBox(height: 12),
              if (total <= 50000)
                _buildPaymentOption(
                  iconPath: 'assets/payment/ya_split.png',
                  title: 'Сплит',
                  subtitle: 'Оплата частями от Яндекса',
                  onTap: () {
                    Navigator.pop(ctx);
                    _startPayment(orderId, total, 'yandex_split');
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required String iconPath,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isPng = iconPath.endsWith('.png');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: context.colors.surfaceAlt),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: context.colors.brandLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isPng
                    ? Image.asset(
                        iconPath,
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                      )
                    : SvgPicture.asset(
                        iconPath,
                        width: 28,
                        height: 28,
                        // 🔥 В тёмной теме — белая иконка, в светлой — чёрная
                        colorFilter: ColorFilter.mode(
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black,
                          BlendMode.srcIn,
                        ),
                      ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.colors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startPayment(
    int orderId,
    double total,
    String method,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('remember_token') ?? '';

    if (token.isEmpty) {
      token = ApiService.cookies
              ?.split('; ')
              .firstWhere(
                (c) => c.startsWith('remember_token='),
                orElse: () => '',
              )
              .replaceFirst('remember_token=', '') ??
          '';
    }

    final refreshResult = await ApiService.post(
      '/api/auth/refresh-token',
      {},
    );

    if (!mounted) return;

    if (refreshResult.isSuccess) {
      final refreshData = refreshResult.valueOrNull;
      final newToken = refreshData?['remember_token'] ??
          refreshData?['token'] ??
          refreshData?['data']?['remember_token'] ??
          refreshData?['data']?['token'] ??
          '';
      if (newToken is String && newToken.isNotEmpty) {
        token = newToken;
        await prefs.setString('remember_token', token);
      }
    } else {
      AppLogger.warning(
        _logTag,
        'refresh-token failed: ${refreshResult.errorOrNull?.message}',
      );
    }

    if (token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка авторизации. Перезайдите в приложение.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final String url;
    if (method == 'podeli') {
      url = 'https://xn--80abvyjk6cts.xn--p1ai/api/payment/podeli-pay'
          '?order_id=$orderId'
          '&amount=${total.toInt()}'
          '&token=$token';
    } else if (method == 'yandex_split') {
      url = 'https://xn--80abvyjk6cts.xn--p1ai/api/payment/yandex-pay'
          '?order_id=$orderId'
          '&amount=${total.toInt()}'
          '&token=$token';
    } else {
      url = 'https://xn--80abvyjk6cts.xn--p1ai/api/payment/pay'
          '?order_id=$orderId'
          '&amount=${total.toInt()}'
          '&token=$token';
    }

    if (!mounted) return;

    final paymentResult = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentWebViewScreen(
          paymentUrl: url,
          orderId: orderId,
          authToken: token,
          baseUrl: 'https://xn--80abvyjk6cts.xn--p1ai',
        ),
      ),
    );

    if (!mounted) return;

    context.read<OrderRefreshProvider>().notifyOrderChanged();

    await _loadDetail();

    if (!mounted) return;

    if (paymentResult == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Оплата прошла успешно!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _openTracking() async {
    final order = _order;
    if (order == null) return;

        setState(() {
      _trackingLoading = true;
    });

    dynamic deliveryData;
    if (order['delivery_data'] != null) {
      if (order['delivery_data'] is String) {
        try {
          deliveryData = jsonDecode(order['delivery_data']);
        } catch (_) {
          // Не удалось распарсить — оставляем пустым.
        }
      } else {
        deliveryData = order['delivery_data'];
      }
    }
    deliveryData ??= {};
    final provider = deliveryData is Map
        ? (deliveryData['provider'] ?? '')
        : '';

    final result = await ApiService.get(
      '/api/orders/track',
      queryParams: {'order_id': '${widget.orderId}'},
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'tracking($provider) failed: ${result.errorOrNull?.message}',
      );
      setState(() => _trackingLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось загрузить данные отслеживания'),
          backgroundColor: context.colors.brand,
        ),
      );
      return;
    }

    final response = result.valueOrNull ?? const {};
    final historyRaw = response['history'];
    final history = historyRaw is List
        ? historyRaw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    final estimatedDate = response['estimated_delivery_date'] as String?;
    if (estimatedDate != null && _order != null) {
      _order!['estimated_delivery_date'] = estimatedDate;
    }

    String? url;
    switch (provider) {
      case 'cdek':
        final cdekNumber = response['cdek_number'];
        if (cdekNumber != null) {
          url = 'https://www.cdek.ru/ru/tracking/?order_id=$cdekNumber';
        }
        break;
      case 'russian_post':
        final trackingNumber = response['tracking_number'];
        if (trackingNumber != null) {
          url = 'https://www.pochta.ru/tracking#$trackingNumber';
        } else {
          url = order['custom_tracking_url'] as String?;
        }
        break;
      case 'ozon':
        final trackingUrl = response['tracking_url'] as String?;
        if (trackingUrl != null && trackingUrl.isNotEmpty) {
          url = trackingUrl;
        } else {
          url = order['custom_tracking_url'] as String?;
        }
        break;
      case 'fivepost':
        final customUrl = order['custom_tracking_url']?.toString() ?? '';
        if (customUrl.isNotEmpty) {
          url = customUrl;
        } else {
          final senderOrderId =
              order['fivepost_sender_order_id']?.toString() ?? '';
          if (senderOrderId.isNotEmpty) {
            url = 'https://fivepost.ru/tracking/$senderOrderId';
          }
        }
        break;
      case 'yandex':
        url = order['custom_tracking_url'] as String?;
        break;
    }

        setState(() {
      _trackingLoading = false;
    });

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => _buildTrackingSheet(ctx, history, url),
    );
  }

  Widget _buildTrackingSheet(
    BuildContext sheetContext,
    List<Map<String, dynamic>> history,
    String? url,
  ) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.55,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Отслеживание',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: _trackingLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: context.colors.brand,
                    ),
                  )
                : history.isEmpty
                    ? Center(
                        child: Text(
                          'Нет данных для отслеживания',
                          style: TextStyle(color: context.colors.textMuted),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (url != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildGradientButton(
                                text: 'Отследить на сайте',
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFF97316),
                                    Color(0xFFEA580C),
                                  ],
                                ),
                                shadowColor: const Color(0xFFF97316),
                                icon: Icons.open_in_new,
                                onTap: () async {
                                  final uri = Uri.parse(url);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                },
                              ),
                            ),
                          ...history.asMap().entries.map((entry) {
                            final event = entry.value;
                            final isActive = entry.key == 0;
                            return Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isActive
                                              ? Color(0xFFF97316)
                                              : context.colors.border,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      if (!isActive)
                                        Container(
                                          width: 2,
                                          height: 50,
                                          color: context.colors.border,
                                        ),
                                    ],
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Padding(
                                      padding:
                                          EdgeInsets.only(bottom: 12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${event['date'] ?? ''} в ${event['time'] ?? ''}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isActive
                                                  ? Color(0xFFF97316)
                                                  : context.colors.textMuted,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            event['title'] ??
                                                event['status'] ??
                                                '',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isActive
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: context.colors.textPrimary,
                                            ),
                                          ),
                                          if ((event['city'] ?? '')
                                              .toString()
                                              .isNotEmpty)
                                            Padding(
                                              padding: EdgeInsets.only(
                                                top: 2,
                                              ),
                                              child: Text(
                                                event['city']?.toString() ??
                                                    '',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: context.colors.textMuted,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    required LinearGradient gradient,
    required Color shadowColor,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      text,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.colors.surfaceAlt,
        body: Stack(
          children: [
            Center(
              child: CircularProgressIndicator(
                color: context.colors.brand,
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildHeader(topPadding, 'Заказ', ''),
            ),
          ],
        ),
      );
    }

    if (_order == null) {
      return Scaffold(
        backgroundColor: context.colors.surfaceAlt,
        body: Stack(
          children: [
            Center(
              child: Text(
                'Заказ не найден',
                style: TextStyle(color: context.colors.textMuted),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildHeader(topPadding, 'Заказ', ''),
            ),
          ],
        ),
      );
    }

    final order = _order!;
    final saleDiscount = _parseDouble(order['sale_discount'] ?? 0);
    final loyaltyDiscount = _parseDouble(order['loyalty_discount']);
    final promoDiscount = _parseDouble(order['promo_discount']);
    final firstOrderDiscount =
        _parseDouble(order['first_order_discount'] ?? 0);
    final bonusDiscount = _parseDouble(order['bonus_discount']);
    final deliveryCost = _parseDouble(order['delivery_cost']);
    final total = _parseDouble(order['total']);
    final subtotal = total +
        saleDiscount +
        loyaltyDiscount +
        promoDiscount +
        firstOrderDiscount +
        bonusDiscount -
        deliveryCost;
    final deliveryMethod = order['delivery_method'] ?? '';
    final paymentMethod = order['payment_method'] ?? '';
    final isPaid = order['payment_status'] == 'paid';
    final orderStatus = order['status'] ?? '';
    final canPay = !isPaid &&
        !['completed', 'cancelled', 'returned', 'partial_returned']
            .contains(orderStatus);
    final canCancel = !['completed', 'cancelled', 'returned', 'partial_returned']
        .contains(orderStatus);
    final itemCount =
        _items.where((item) => item['name'] != null).length;

    dynamic deliveryData;
    if (order['delivery_data'] != null) {
      if (order['delivery_data'] is String) {
        try {
          deliveryData = jsonDecode(order['delivery_data']);
        } catch (_) {
          // Не удалось распарсить — оставляем пустым.
        }
      } else {
        deliveryData = order['delivery_data'];
      }
    }
    deliveryData ??= {};

    final provider =
        (deliveryData is Map ? (deliveryData['provider'] ?? '') : '')
            .toString();

    final isExportedToDelivery = (order['cdek_export_status'] == 'success' ||
        order['yandex_export_status'] == 'success' ||
        order['fivepost_export_status'] == 'success' ||
        order['russianpost_export_status'] == 'success' ||
        order['ozon_export_status'] == 'success');

    final showTracking = deliveryMethod == 'pickup-point' &&
        ['cdek', 'yandex', 'fivepost', 'russian_post', 'ozon']
            .contains(provider) &&
        isExportedToDelivery;

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: context.colors.surfaceAlt,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: topPadding + 48),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom: (canPay || showTracking)
                          ? 160
                          : (bottomPadding + 160),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        if (deliveryMethod == 'pickup-store') ...[
                          _buildStoreInfo(),
                          const SizedBox(height: 12),
                          DeliveryProgressBar(
                            status: orderStatus,
                            deliveryMethod: deliveryMethod,
                            createdAt:
                                _formatDate(order['created_at'] ?? ''),
                            completedAt: order['paid_at'],
                          ),
                        ],
                        if (deliveryMethod == 'courier') ...[
                          _buildCourierInfo(
                            deliveryData is Map
                                ? Map<String, dynamic>.from(deliveryData)
                                : {},
                          ),
                          const SizedBox(height: 12),
                          DeliveryProgressBar(
                            status: orderStatus,
                            deliveryMethod: deliveryMethod,
                            createdAt:
                                _formatDate(order['created_at'] ?? ''),
                            completedAt: order['paid_at'],
                          ),
                        ],
                        if (deliveryMethod == 'pickup-point') ...[
                          _buildPickupInfo(
                            deliveryData is Map
                                ? Map<String, dynamic>.from(deliveryData)
                                : {},
                          ),
                          const SizedBox(height: 12),
                          DeliveryProgressBar(
                            status: orderStatus,
                            deliveryMethod: deliveryMethod,
                            createdAt:
                                _formatDate(order['created_at'] ?? ''),
                            shippingAt: order['cdek_exported_at'] ??
                                order['yandex_exported_at'] ??
                                order['fivepost_exported_at'] ??
                                order['russianpost_exported_at'],
                            waitingAt: null,
                            completedAt: order['paid_at'],
                            estimatedDeliveryDate:
                                order['estimated_delivery_date']
                                    as String?,
                          ),
                        ],
                        SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          color: context.colors.surface,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  12,
                                  20,
                                  12,
                                  8,
                                ),
                                child: Text(
                                  'Товары',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textMuted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              ..._items
                                  .where((item) => item['name'] != null)
                                  .map((item) {
                                final price = _parseDouble(item['price']);
                                final salePrice = item['sale_price'] != null
                                    ? _parseDouble(item['sale_price'])
                                    : null;
                                final cardPrice = item['card_price'] != null
                                    ? _parseDouble(item['card_price'])
                                    : null;

                                double actualPrice;
                                if (salePrice != null &&
                                    salePrice < price) {
                                  actualPrice = salePrice.roundToDouble();
                                } else if (cardPrice != null &&
                                    cardPrice < price) {
                                  actualPrice = cardPrice.roundToDouble();
                                } else {
                                  actualPrice = price.roundToDouble();
                                }

                                final qty = _parseInt(item['quantity']);
                                final freeQty =
                                    _parseInt(item['free_quantity']);
                                final isFree =
                                    (freeQty > 0 || price == 0.0);
                                final imageRaw =
                                    item['main_image_detail'] ??
                                    item['main_image_card'] ??
                                    item['main_image'] ??
                                    '';
                                final image = imageRaw
                                    .toString()
                                    .replaceAll('main.webp', 'main_card.webp');
                                final slug = item['slug'] ?? '';
                                final displayPrice =
                                    isFree ? 0.0 : actualPrice * qty;
                                final stock = _parseInt(item['stock']);
                                final isUnavailable =
                                    !(item['is_active'] == true ||
                                            item['is_active'] == 1 ||
                                            item['is_active'] == null) ||
                                        stock <= 0;

                                return InkWell(
                                  onTap: slug.isNotEmpty
                                      ? () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  ProductDetailScreen(
                                                slug: slug,
                                              ),
                                            ),
                                          )
                                      : null,
                                  child: Container(
                                    padding: EdgeInsets.fromLTRB(
                                      12,
                                      14,
                                      12,
                                      14,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: context.colors.border,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ImageLoader(
                                          imageUrl: image,
                                          width: 80,
                                          height: 106,
                                          borderRadius: 12,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      item['name'] ?? '',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: context
                                                            .colors
                                                            .textPrimary,
                                                      ),
                                                      maxLines: 2,
                                                      overflow: TextOverflow
                                                          .ellipsis,
                                                    ),
                                                  ),
                                                  if (isFree)
                                                    Container(
                                                      margin:
                                                          const EdgeInsets
                                                              .only(
                                                        left: 6,
                                                      ),
                                                      padding:
                                                          const EdgeInsets
                                                              .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                      decoration:
                                                          BoxDecoration(
                                                        color: const Color(
                                                          0xFFE8F5E9,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                      ),
                                                      child: const Text(
                                                        'Бесплатно',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                            0xFF2E7D32,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .baseline,
                                                textBaseline:
                                                    TextBaseline.alphabetic,
                                                children: [
                                                  Text(
                                                    isFree
                                                        ? '0 ₽'
                                                        : _formatPrice(
                                                            displayPrice,
                                                          ),
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: isFree
                                                          ? const Color(
                                                              0xFF2E7D32,
                                                            )
                                                          : const Color(
                                                              0xFFDD1847,
                                                            ),
                                                    ),
                                                  ),
                                                  if (!isFree &&
                                                      actualPrice < price) ...[
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      _formatPrice(
                                                        price * qty,
                                                      ),
                                                      style:
                                                          const TextStyle(
                                                        fontSize: 13,
                                                        color: Color(
                                                          0xFF999999,
                                                        ),
                                                        decoration:
                                                            TextDecoration
                                                                .lineThrough,
                                                        decorationColor:
                                                            Color(
                                                          0xFF999999,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  SizedBox(width: 12),
                                                  Text(
                                                    '$qty шт.',
                                                    style:
                                                        TextStyle(
                                                      fontSize: 14,
                                                      color:
                                                          context.colors.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  if (orderStatus ==
                                                      'completed')
                                                    (item['is_reviewed'] ==
                                                            true)
                                                        ? Container(
                                                            padding: const EdgeInsets
                                                                .symmetric(
                                                              horizontal: 14,
                                                              vertical: 8,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: const Color(
                                                                  0xFFF0F0F5),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                10,
                                                              ),
                                                            ),
                                                            child:
                                                                const Text(
                                                              'Оценено',
                                                              style:
                                                                  TextStyle(
                                                                fontSize: 13,
                                                                color: Color(
                                                                    0xFF999999),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                            ),
                                                          )
                                                        : GestureDetector(
                                                            onTap: () =>
                                                                RateProductSheet
                                                                    .show(
                                                              context,
                                                              item,
                                                              _loadDetail,
                                                            ),
                                                            child: Container(
                                                              padding: const EdgeInsets
                                                                  .symmetric(
                                                                horizontal: 14,
                                                                vertical: 8,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: const Color(
                                                                    0xFFFDF2F5),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                  10,
                                                                ),
                                                              ),
                                                              child:
                                                                  const Text(
                                                                '★ Оценить',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize:
                                                                      13,
                                                                  color: Color(
                                                                      0xFFDD1847),
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                  const SizedBox(width: 10),
                                                  GestureDetector(
                                                    onTap: isUnavailable
                                                        ? null
                                                        : () {
                                                            final cart = context
                                                                .read<
                                                                    CartProvider>();
                                                            final currentInCart =
                                                                cart.getQuantity(
                                                              item['product_id']
                                                                  as int,
                                                            );
                                                            final maxCanAdd =
                                                                stock -
                                                                    currentInCart;
                                                            if (maxCanAdd <=
                                                                0) {
                                                              ScaffoldMessenger.of(
                                                                      context)
                                                                  .showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                      'Больше нельзя добавить'),
                                                                  backgroundColor:
                                                                      Color(
                                                                    0xFFDD1847,
                                                                  ),
                                                                ),
                                                              );
                                                              return;
                                                            }
                                                            cart.addItemFull(
                                                              {
                                                                'product_id':
                                                                    item[
                                                                        'product_id'],
                                                                'quantity': 1,
                                                                'name': item[
                                                                        'name'] ??
                                                                    '',
                                                                'slug': slug,
                                                                'price':
                                                                    actualPrice,
                                                                'sale_price': item[
                                                                    'sale_price'],
                                                                'card_price': item[
                                                                    'card_price'],
                                                                'main_image':
                                                                    image,
                                                                'stock': stock,
                                                                'brand': item[
                                                                        'brand'] ??
                                                                    '',
                                                                'category_id':
                                                                    null,
                                                                'unavailable':
                                                                    false,
                                                              },
                                                              1,
                                                            );
                                                            ScaffoldMessenger.of(
                                                                    context)
                                                                .showSnackBar(
                                                              const SnackBar(
                                                                content: Text(
                                                                    'Добавлено в корзину'),
                                                                backgroundColor:
                                                                    Color(
                                                                  0xFFDD1847,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 14,
                                                        vertical: 8,
                                                      ),
                                                      decoration:
                                                          BoxDecoration(
                                                        color: isUnavailable
                                                            ? const Color(
                                                                0xFFE0E0E0,
                                                              )
                                                            : const Color(
                                                                0xFFDD1847,
                                                              ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10),
                                                      ),
                                                      child: Text(
                                                        'В корзину',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          color: isUnavailable
                                                              ? const Color(
                                                                  0xFF999999,
                                                                )
                                                              : Colors.white,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          color: context.colors.surface,
                          padding: EdgeInsets.fromLTRB(
                            12,
                            20,
                            12,
                            24,
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$itemCount ${_pluralItems(itemCount)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: context.colors.textMuted,
                                    ),
                                  ),
                                  Text(
                                    _formatPrice(subtotal),
                                    style: TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                              if (saleDiscount > 0) ...[
                                SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Скидка по акции',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.colors.success,
                                      ),
                                    ),
                                    Text(
                                      '−${_formatPrice(saleDiscount)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.colors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (promoDiscount > 0) ...[
                                SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Промо-акция',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.colors.success,
                                      ),
                                    ),
                                    Text(
                                      '−${_formatPrice(promoDiscount)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.colors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (loyaltyDiscount > 0) ...[
                                SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Скидка по Б-карте',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.colors.success,
                                      ),
                                    ),
                                    Text(
                                      '−${_formatPrice(loyaltyDiscount)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.colors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (firstOrderDiscount > 0) ...[
                                SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Иные скидки',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.colors.success,
                                      ),
                                    ),
                                    Text(
                                      '−${_formatPrice(firstOrderDiscount)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.colors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (bonusDiscount > 0) ...[
                                SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Списано бонусов',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.colors.success,
                                      ),
                                    ),
                                    Text(
                                      '−${_formatPrice(bonusDiscount)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.colors.success,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (deliveryCost > 0) ...[
                                SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Доставка',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.colors.textMuted,
                                      ),
                                    ),
                                    Text(
                                      _formatPrice(deliveryCost),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              const Divider(),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Итого',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    _formatPrice(total),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isPaid
                                          ? const Color(0xFFD4EDDA)
                                          : const Color(0xFFFFF3CD),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isPaid ? 'Оплачен' : 'Не оплачен',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isPaid
                                            ? Color(0xFF155724)
                                            : Color(0xFF856404),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.payment_outlined,
                                        size: 14,
                                        color: context.colors.textMuted,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        _getPaymentMethodText(
                                          paymentMethod,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.colors.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (canCancel) ...[
                          SizedBox(height: 16),
                          Padding(
                            padding:
                                EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: _isCancelling
                                    ? null
                                    : _cancelOrder,
                                child: _isCancelling
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: context.colors.textMuted,
                                        ),
                                      )
                                    : Text(
                                        'Отменить заказ',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: context.colors.textMuted,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(
              topPadding,
              'Заказ №${widget.orderId}',
              _formatDate(order['created_at'] ?? ''),
            ),
          ),
          if (canPay || showTracking)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  bottomPadding > 0 ? bottomPadding + 8 : 16,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surfaceAlt,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canPay)
                      paymentMethod == 'invoice'
                          ? Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF9E6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Color(0xFF856404),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Ожидайте, с вами свяжутся для оплаты',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF856404),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _buildGradientButton(
                              text: 'Оплатить ${_formatPrice(total)}',
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  context.colors.brand,
                                  context.colors.brandDark,
                                ],
                              ),
                              shadowColor: context.colors.brand,
                              onTap: _openPayment,
                            ),
                    if (canPay && showTracking)
                      const SizedBox(height: 8),
                    if (showTracking)
                      _buildGradientButton(
                        text: 'Отследить',
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFF97316),
                            Color(0xFFEA580C),
                          ],
                        ),
                        shadowColor: const Color(0xFFF97316),
                        onTap: _openTracking,
                        icon: Icons.search,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    double topPadding,
    String title,
    String subtitle,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        bottom: Radius.circular(20),
      ),
      child: Container(
        padding: EdgeInsets.only(top: topPadding, bottom: 4),
        color: context.colors.surface,
        child: Row(
          children: [
            SizedBox(width: 8),
            IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: context.colors.error,
                size: 22,
              ),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: 40,
                minHeight: 40,
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => MainShell.push(context, SupportScreen()),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: SupportIconWithBadge(
                      size: 22,
                      color: context.colors.textSecondary,
                      padding: 0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreInfo() {
    return Container(
      width: double.infinity,
      color: context.colors.surface,
      padding: EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Самовывоз из магазина',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Б•Роща — Брянск',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            'г. Брянск, проспект Станке Димитрова, д. 65',
            style: TextStyle(fontSize: 14, color: context.colors.textMuted),
          ),
          SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _InfoRow(
                  label: 'График',
                  value: 'Будни: 10:00–19:00\nВыходные: 10:00–18:00',
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _callPhone('+79208447732'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Телефон',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.textMuted,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 16,
                            color: context.colors.brand,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '+7 (920) 844-77-32',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.colors.brand,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
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

  Widget _buildCourierInfo(Map<String, dynamic> data) {
    final address = data['address'] ?? '';
    final apartment = data['apartment'] ?? '';
    final floor = data['floor'] ?? '';
    final entrance = data['entrance'] ?? '';
    final doorphone = data['doorphone'] ?? '';
    final deliveryDate = data['delivery_date'] ?? '';
    final deliveryTime = data['delivery_time'] ?? '';

    return Container(
      width: double.infinity,
      color: context.colors.surface,
      padding: EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Курьерская доставка',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 18,
                color: context.colors.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      address.isNotEmpty ? address : 'Адрес не указан',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (apartment.isNotEmpty ||
                        floor.isNotEmpty ||
                        entrance.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          'Кв: $apartment'
                          '${floor.isNotEmpty ? ', этаж: $floor' : ''}'
                          '${entrance.isNotEmpty ? ', подъезд: $entrance' : ''}'
                          '${doorphone.isNotEmpty ? ', домофон: $doorphone' : ''}',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (deliveryDate.isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 18,
                    color: context.colors.brand,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Доставим ${_formatDeliveryDate(deliveryDate)}'
                    '${deliveryTime.isNotEmpty ? ' с ${deliveryTime.replaceAll('-', ' до ')}' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPickupInfo(Map<String, dynamic> data) {
    final pointName = data['point_name'] ?? '';
    final pointAddress = data['point_address'] ?? '';
    final provider = data['provider'] ?? '';

    final fivepostExpiration = _order?['fivepost_expiration_date'];
final cdekExpiration = _order?['cdek_storage_expiration_date'];
final yandexExpiration = _order?['yandex_storage_expiration_date'];
final ozonExpiration = _order?['ozon_storage_expiration_date'];
final expirationDate =
    cdekExpiration ?? yandexExpiration ?? fivepostExpiration ?? ozonExpiration;

    final yandexPickupCode = _order?['yandex_pickup_code'];
    final fivepostSecurityCode = _order?['fivepost_security_code'];
    final cdekDeliveryPoint = _order?['cdek_delivery_point'];

    final providerIcons = {
      'cdek': 'assets/images/CDEKLogo.png',
      'yandex': 'assets/images/YandexLogo.png',
      'fivepost': 'assets/images/5postlogo.png',
      'russian_post': 'assets/images/Pochalogo.png',
      'ozon': 'assets/images/OzonLogo.png',
    };
    final iconPath = providerIcons[provider];

    return Container(
      width: double.infinity,
      color: context.colors.surface,
      padding: EdgeInsets.fromLTRB(12, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Пункт выдачи',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (iconPath != null)
                Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      iconPath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Text(
                          provider.toString().toUpperCase().length >= 2
                              ? provider
                                  .toString()
                                  .toUpperCase()
                                  .substring(0, 2)
                              : '?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pointName.isNotEmpty ? pointName : 'ПВЗ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (pointAddress.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        pointAddress,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                    if ((cdekDeliveryPoint != null &&
                            cdekDeliveryPoint.toString().isNotEmpty) ||
                        (yandexPickupCode != null &&
                            yandexPickupCode.toString().isNotEmpty) ||
                        (fivepostSecurityCode != null &&
                            fivepostSecurityCode.toString().isNotEmpty)) ...[
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.brandLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.qr_code,
                              size: 14,
                              color: context.colors.brand,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Код выдачи: '
                              '${cdekDeliveryPoint ?? yandexPickupCode ?? fivepostSecurityCode}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.colors.brand,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                                        if (expirationDate != null &&
                        expirationDate.toString().isNotEmpty &&
                        _order?['status'] == 'ready_pickup') ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9E6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time,
                              size: 14,
                              color: Color(0xFF856404),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Срок хранения до: '
                              '${_formatExpirationDate(expirationDate.toString())}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF856404),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatExpirationDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
        'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDeliveryDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}.${date.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  String _pluralItems(int n) {
    final m10 = n % 10;
    final m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'товар';
    if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) {
      return 'товара';
    }
    return 'товаров';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: context.colors.textMuted,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}