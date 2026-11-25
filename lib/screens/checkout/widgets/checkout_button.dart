import 'package:http/http.dart' as http;
import 'dart:convert';
// lib/screens/checkout/widgets/checkout_button.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api_error.dart';
import '../../../core/app_logger.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/checkout_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../providers/order_refresh_provider.dart';
import '../../../screens/main_shell.dart';
import '../../../services/api_service.dart';
import '../../../services/app_review_service.dart';
import '../../../services/haptic_service.dart';
import '../payment_webview_screen.dart';
import '../thank_you_screen.dart';
import '../../../widgets/common/gradient_button.dart';
import '../../../widgets/common/apple_snackbar.dart';

class CheckoutButton extends StatefulWidget {
  const CheckoutButton({super.key});

  @override
  State<CheckoutButton> createState() => _CheckoutButtonState();
}

class _CheckoutButtonState extends State<CheckoutButton> {
  static const _logTag = 'CheckoutButton';

  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final checkout = context.watch<CheckoutProvider>();
    final cart = context.watch<CartProvider>();
    final currency = context.watch<CurrencyProvider>();

    final deliveryCost = checkout.deliveryCost;
    final finalTotal = cart.finalTotal + deliveryCost - checkout.bonusAmount;
    final method = checkout.deliveryMethod;
    final paymentMethod = checkout.paymentMethod;

    bool isReady = false;
    String buttonLabel = '';

    switch (method) {
      case 'pickup-store':
        isReady = checkout.selectedStore != null;
        buttonLabel = isReady
            ? _getButtonLabel(paymentMethod)
            : 'Магазин не выбран';
        break;
      case 'courier':
        final hasDateTime =
            (checkout.courierData['delivery_date']?.isNotEmpty ?? false) &&
            (checkout.courierData['delivery_time']?.isNotEmpty ?? false);
        isReady = checkout.courierReady && hasDateTime;
        buttonLabel = isReady
            ? _getButtonLabel(paymentMethod)
            : (!checkout.courierReady
                  ? 'Укажите адрес доставки'
                  : 'Выберите дату и время');
        break;
      case 'pickup-point':
        isReady = checkout.selectedPickupPoint != null;
        buttonLabel = isReady
            ? _getButtonLabel(paymentMethod)
            : 'ПВЗ не выбран';
        break;
      default:
        buttonLabel = 'Выберите способ доставки';
    }

    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16, top: 8),
      child: GradientButton(
        text: buttonLabel,
        trailing: isReady ? _buildPriceWidget(finalTotal, currency) : null,
        onPressed: (isReady && !_isLoading) ? _submitOrder : null,
        isLoading: _isLoading,
        enabled: isReady,
        borderRadius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  String _getButtonLabel(String paymentMethod) {
    switch (paymentMethod) {
      case 'cod':
        return 'Оформить заказ';
      case 'podeli':
        return 'Оплатить';
      default:
        return 'Оплатить';
    }
  }

  /// Виджет цены для правой части кнопки — с правильным fontFamily
  Widget _buildPriceWidget(double total, CurrencyProvider currency) {
    // total приходит в RUB — конвертируем в валюту пользователя (BYN/KZT)
    final converted = currency.convert(total);
    final price = currency.currency == 'BYN'
        ? converted.toStringAsFixed(2)
        : (converted == converted.roundToDouble()
              ? converted.toInt().toString()
              : converted.toStringAsFixed(2));

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: price,
            style: TextStyle(
              fontFamily: currency.fontFamily, // NBRB для BYN
              fontSize: currency.symbolFontSize,
            ),
          ),
          TextSpan(
            text: ' ${currency.symbol}',
            style: TextStyle(
              fontFamily: currency.fontFamily,
              fontSize: currency.symbolFontSize,
            ),
          ),
        ],
      ),
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: -0.3,
      ),
    );
  }

  Future<void> _submitOrder() async {
    HapticService.heavy();
    final checkout = context.read<CheckoutProvider>();
    final cart = context.read<CartProvider>();
    setState(() => _isLoading = true);

    Map<String, dynamic> deliveryData = {};
    switch (checkout.deliveryMethod) {
      case 'pickup-store':
        deliveryData = {
          'store_id': checkout.selectedStore?.id,
          'store_name': checkout.selectedStore?.name,
        };
        break;
      case 'courier':
        final courierDate = checkout.courierData['delivery_date'] ?? '';
        final courierTime = checkout.courierData['delivery_time'] ?? '';
        if (courierDate.isEmpty || courierTime.isEmpty) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          showAppleSnackBar(
            context,
            'Выберите дату и время доставки',
            type: SnackType.info,
          );
          return;
        }
        deliveryData = {
          'address': checkout.courierAddress,
          'delivery_date': courierDate,
          'delivery_time': courierTime,
          'apartment': checkout.courierData['apartment'] ?? '',
          'floor': checkout.courierData['floor'] ?? '',
          'entrance': checkout.courierData['entrance'] ?? '',
          'doorphone': checkout.courierData['doorphone'] ?? '',
          'comments': checkout.courierData['comments'] ?? '',
        };
        break;
      case 'pickup-point':
        deliveryData = {
          'point_id': checkout.selectedPickupPoint?.id,
          'provider': checkout.selectedPickupPoint?.provider,
        };
        break;
    }

    final checkedIds = cart.checkedIds.toList();

    final initiateResult = await ApiService.post('/api/orders/initiate', {
      'product_ids': checkedIds,
    });

    if (!mounted) return;

    if (initiateResult.isFailure) {
      setState(() => _isLoading = false);
      showAppleSnackBar(
        context,
        initiateResult.errorOrNull?.userMessage ?? 'Ошибка обновления заказа',
        type: SnackType.error,
      );
      return;
    }

    final initiateData = initiateResult.valueOrNull?['data'];
    if (initiateData is! Map) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ошибка обновления заказа')));
      return;
    }

    final actualOrderId = initiateData['order_id'];
    if (actualOrderId is! int) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ошибка обновления заказа')));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guest_cart_items');
    await prefs.remove('cached_cart_count');

    debugPrint(
      '[ORDER_CREATE] req order_id=$actualOrderId '
      'method=${checkout.deliveryMethod} cost=${checkout.deliveryCost} '
      'pay=${checkout.paymentMethod} bonus=${checkout.bonusAmount} '
      'deliveryData=$deliveryData',
    );

    final result = await ApiService.post('/api/orders/create', {
      'order_id': actualOrderId,
      'delivery_method': checkout.deliveryMethod,
      'delivery_cost': checkout.deliveryCost,
      'payment_method': checkout.paymentMethod,
      'bonus_amount': checkout.bonusAmount,
      'delivery_data': deliveryData,
    });

    if (!mounted) return;

    debugPrint(
      '[ORDER_CREATE] resp isFailure=${result.isFailure} '
      'errType=${result.errorOrNull.runtimeType} '
      'errMsg=${result.errorOrNull?.message} '
      'userMsg=${result.errorOrNull?.userMessage} '
      'payload=${result.errorOrNull is BusinessError ? (result.errorOrNull as BusinessError).payload : null} '
      'rawValue=${result.valueOrNull}',
    );

    if (result.isFailure) {
      setState(() => _isLoading = false);

      final error = result.errorOrNull;

      if (error is BusinessError && error.payload['code'] == 'PRICE_CHANGED') {
        showAppleSnackBar(
          context,
          'Цены на товары изменились. Обновляем заказ...',
          type: SnackType.error,
        );

        await Future.delayed(const Duration(milliseconds: 800));

        if (!mounted) return;

        final reinitResult = await ApiService.post('/api/orders/initiate', {
          'product_ids': cart.checkedIds.toList(),
          'force_recalc': true,
        });

        if (!mounted) return;

        if (reinitResult.isSuccess) {
          final reinitData = reinitResult.valueOrNull?['data'];
          final newOrderId = reinitData is Map ? reinitData['order_id'] : null;

          if (newOrderId is int) {
            if (newOrderId != actualOrderId) {
              checkout.init(newOrderId);
            } else {
              await checkout.reload();
            }
          }
        } else {
          AppLogger.warning(
            _logTag,
            'reinit after PRICE_CHANGED failed: '
            '${reinitResult.errorOrNull?.message}',
          );
        }
        return;
      }

      showAppleSnackBar(
        context,
        error?.userMessage ?? 'Ошибка создания заказа',
        type: SnackType.error,
      );
      return;
    }

    final rawMap = result.valueOrNull is Map
        ? result.valueOrNull as Map
        : const <String, dynamic>{};
    final nestedData = rawMap['data'] is Map ? rawMap['data'] as Map : null;

    final rawOrderId = nestedData?['order_id'] ?? rawMap['order_id'];
    final orderId = rawOrderId is int
        ? rawOrderId
        : int.tryParse(rawOrderId?.toString() ?? '');
    if (orderId == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ошибка создания заказа')));
      return;
    }

    final rawTotal = nestedData?['total'] ?? rawMap['total'];
    final total = rawTotal is num
        ? rawTotal.toDouble()
        : (double.tryParse(rawTotal?.toString() ?? '') ?? 0.0);

    await prefs.remove('cached_orders_data');
    await prefs.remove('cached_orders_timestamp');

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!mounted) return;
    await _openPayment(checkout.paymentMethod, orderId, total);
  }

  Future<bool> _checkBackendOrderPaid({
    required String baseUrl,
    required int orderId,
    required String token,
    required String method,
  }) async {
    try {
      final primaryEndpoint = method == 'yandex_split'
          ? '/api/payment/yandex-pay-check-status'
          : '/api/payment/check-status';
      final headers = <String, String>{'Accept': 'application/json'};
      if (token.isNotEmpty) {
        headers['Cookie'] = 'remember_token=$token';
      }

      for (final ep in [primaryEndpoint, '/api/orders/status']) {
        final uri = Uri.parse('$baseUrl$ep').replace(
          queryParameters: {'order_id': orderId.toString(), 'token': token},
        );
        final resp = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final raw = json.decode(resp.body);
          if (raw is Map) {
            final nested = raw['data'] is Map ? raw['data'] as Map : const {};
            final pStatus =
                (raw['status'] ??
                        raw['payment_status'] ??
                        nested['status'] ??
                        nested['payment_status'] ??
                        '')
                    .toString();
            final oStatus =
                (raw['order_status'] ?? nested['order_status'] ?? '')
                    .toString();
            if (pStatus == 'paid' ||
                pStatus == 'completed' ||
                pStatus == 'captured' ||
                oStatus == 'processing' ||
                oStatus == 'completed') {
              return true;
            }
          }
        }
      }
    } catch (_) {}
    return false;
  }

  void _completeOrderNavigation({required int orderId, required bool isPaid}) {
    if (!mounted) return;
    final cart = context.read<CartProvider>();
    context.read<OrderRefreshProvider>().notifyOrderChanged();

    if (isPaid) {
      for (final id in cart.checkedIds.toList()) {
        cart.removeFromCart(id);
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
      AppReviewService.recordOrderPlaced();
      MainShell.push(context, ThankYouScreen(orderId: orderId));
    } else {
      // WebView уже закрыт (сделал pop(false) сам в PaymentWebViewScreen).
      // Здесь мы уже на CheckoutScreen — второй pop() выбрасывал в корзину.
      // Только показываем SnackBar, ничего не закрываем.
      debugPrint('🧾 [NAV] unpaid order=$orderId — остаёмся на CheckoutScreen');
      showAppleSnackBar(
        context,
        'Оплата заказа №$orderId не завершена. Вы можете повторить оплату.',
        type: SnackType.error,
      );
    }
  }

  Future<void> _openPayment(String method, int orderId, double total) async {
    if (method == 'cod' || method == 'invoice') {
      _completeOrderNavigation(orderId: orderId, isPaid: true);
      return;
    }

    const baseUrl = 'https://xn--80abvyjk6cts.xn--p1ai';
    final prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('remember_token') ?? '';

    if (token.isEmpty) {
      final cookies = ApiService.cookies ?? '';
      for (final cookie in cookies.split('; ')) {
        if (cookie.startsWith('remember_token=')) {
          token = cookie.replaceFirst('remember_token=', '');
          await prefs.setString('remember_token', token);
          break;
        }
      }
    }

    final refreshResult = await ApiService.post('/api/auth/refresh-token', {});

    if (!mounted) return;

    if (refreshResult.isSuccess) {
      final refreshData = refreshResult.valueOrNull;
      final newToken =
          refreshData?['remember_token'] ??
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
      showAppleSnackBar(
        context,
        'Ошибка авторизации. Перезайдите в приложение.',
        type: SnackType.error,
      );
      return;
    }

    final String paymentUrl;
    if (method == 'podeli') {
      paymentUrl =
          '$baseUrl/api/payment/podeli-pay'
          '?order_id=$orderId'
          '&amount=${total.toInt()}'
          '&token=$token';
    } else if (method == 'yandex_split') {
      paymentUrl =
          '$baseUrl/api/payment/yandex-pay'
          '?order_id=$orderId'
          '&amount=${total.toInt()}'
          '&token=$token';
    } else if (method == 'sber') {
      paymentUrl =
          '$baseUrl/api/payment/sber-pay'
          '?order_id=$orderId'
          '&amount=${total.toInt()}'
          '&token=$token';
    } else {
      paymentUrl =
          '$baseUrl/api/payment/pay'
          '?order_id=$orderId'
          '&amount=${total.toInt()}'
          '&token=$token';
    }

    if (!mounted) return;

    final paymentResult = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentWebViewScreen(
          paymentUrl: paymentUrl,
          orderId: orderId,
          authToken: token,
          baseUrl: baseUrl,
        ),
      ),
    );

    if (!mounted) return;

    final isPaid = paymentResult == true
        ? true
        : await _checkBackendOrderPaid(
            baseUrl: baseUrl,
            orderId: orderId,
            token: token,
            method: method,
          );

    if (!mounted) return;

    _completeOrderNavigation(orderId: orderId, isPaid: isPaid);
  }
}
