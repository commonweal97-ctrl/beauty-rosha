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
import '../../../services/haptic_service.dart';
import '../../../services/review_service.dart';
import '../payment_webview_screen.dart';
import '../thank_you_screen.dart';
import '../../../core/app_colors.dart';
import '../../../widgets/common/gradient_button.dart';

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
    final finalTotal =
        cart.finalTotal + deliveryCost - checkout.bonusAmount;
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
      padding: const EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: 16,
        top: 8,
      ),
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
    final price = currency.currency == 'BYN'
        ? total.toStringAsFixed(2)
        : (total == total.roundToDouble()
            ? total.toInt().toString()
            : total.toStringAsFixed(2));

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Выберите дату и время доставки'),
              backgroundColor: context.colors.brand,
            ),
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

    final initiateResult = await ApiService.post(
      '/api/orders/initiate',
      {'product_ids': checkedIds},
    );

    if (!mounted) return;

    if (initiateResult.isFailure) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            initiateResult.errorOrNull?.userMessage ??
                'Ошибка обновления заказа',
          ),
        ),
      );
      return;
    }

    final initiateData = initiateResult.valueOrNull?['data'];
    if (initiateData is! Map) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка обновления заказа')),
      );
      return;
    }

    final actualOrderId = initiateData['order_id'];
    if (actualOrderId is! int) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка обновления заказа')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('guest_cart_items');
    await prefs.remove('cached_cart_count');

    final result = await ApiService.post(
      '/api/orders/create',
      {
        'order_id': actualOrderId,
        'delivery_method': checkout.deliveryMethod,
        'delivery_cost': checkout.deliveryCost,
        'payment_method': checkout.paymentMethod,
        'bonus_amount': checkout.bonusAmount,
        'delivery_data': deliveryData,
      },
    );

    if (!mounted) return;

    if (result.isFailure) {
      setState(() => _isLoading = false);

      final error = result.errorOrNull;

      if (error is BusinessError &&
          error.payload['code'] == 'PRICE_CHANGED') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Цены на товары изменились. Обновляем заказ...'),
            backgroundColor: Color(0xFFFFA500),
            duration: Duration(seconds: 2),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 800));

        if (!mounted) return;

        final reinitResult = await ApiService.post(
          '/api/orders/initiate',
          {
            'product_ids': cart.checkedIds.toList(),
            'force_recalc': true,
          },
        );

        if (!mounted) return;

        if (reinitResult.isSuccess) {
          final reinitData = reinitResult.valueOrNull?['data'];
          final newOrderId =
              reinitData is Map ? reinitData['order_id'] : null;

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error?.userMessage ?? 'Ошибка создания заказа',
          ),
        ),
      );
      return;
    }

    final responseData = result.valueOrNull?['data'];
    if (responseData is! Map) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка создания заказа')),
      );
      return;
    }

    final orderId = responseData['order_id'];
    if (orderId is! int) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка создания заказа')),
      );
      return;
    }

    final total =
        (responseData['total'] as num?)?.toDouble() ?? 0.0;

    await prefs.remove('cached_orders_data');
    await prefs.remove('cached_orders_timestamp');

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (checkout.paymentMethod == 'cod' ||
        checkout.paymentMethod == 'invoice') {
      for (final id in cart.checkedIds.toList()) {
        cart.removeFromCart(id);
      }
      context.read<OrderRefreshProvider>().notifyOrderChanged();
    }

    if (!mounted) return;
    await _openPayment(checkout.paymentMethod, orderId, total);
  }

  Future<void> _openPayment(
    String method,
    int orderId,
    double total,
  ) async {
    if (method == 'cod' || method == 'invoice') {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ReviewService().requestReviewIfNeeded();
      MainShell.push(context, ThankYouScreen(orderId: orderId));
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

    final String paymentUrl;
    if (method == 'podeli') {
      paymentUrl = '$baseUrl/api/payment/podeli-pay'
          '?order_id=$orderId'
          '&amount=${total.toInt()}'
          '&token=$token';
    } else if (method == 'sber') {
      paymentUrl = '$baseUrl/api/payment/sber-pay'
          '?order_id=$orderId'
          '&amount=${total.toInt()}'
          '&token=$token';
    } else {
      paymentUrl = '$baseUrl/api/payment/pay'
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

    Navigator.of(context).popUntil((route) => route.isFirst);

    if (paymentResult == true) {
      final cart = context.read<CartProvider>();
      for (final id in cart.checkedIds.toList()) {
        cart.removeFromCart(id);
      }
      context.read<OrderRefreshProvider>().notifyOrderChanged();

      ReviewService().requestReviewIfNeeded();
      MainShell.push(context, ThankYouScreen(orderId: orderId));
    }
  }
}