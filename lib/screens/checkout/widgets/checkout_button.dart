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
    String buttonText = '';

    switch (method) {
      case 'pickup-store':
        isReady = checkout.selectedStore != null;
        buttonText = isReady
            ? _getButtonText(paymentMethod, finalTotal, currency)
            : 'Магазин не выбран';
        break;
      case 'courier':
        final hasDateTime =
            (checkout.courierData['delivery_date']?.isNotEmpty ?? false) &&
                (checkout.courierData['delivery_time']?.isNotEmpty ?? false);
        isReady = checkout.courierReady && hasDateTime;
        buttonText = isReady
            ? _getButtonText(paymentMethod, finalTotal, currency)
            : (!checkout.courierReady
                ? 'Укажите адрес доставки'
                : 'Выберите дату и время');
        break;
      case 'pickup-point':
        isReady = checkout.selectedPickupPoint != null;
        buttonText = isReady
            ? _getButtonText(paymentMethod, finalTotal, currency)
            : 'ПВЗ не выбран';
        break;
      default:
        buttonText = 'Выберите способ доставки';
    }

    return Padding(
      padding: const EdgeInsets.only(
        left: 24,
        right: 24,
        bottom: 16,
        top: 8,
      ),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isReady
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [context.colors.brand, context.colors.brandDark],
                )
              : null,
          color: isReady ? null : context.colors.border,
          boxShadow: isReady
              ? [
                  BoxShadow(
                    color:
                        context.colors.brand.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                  BoxShadow(
                    color:
                        context.colors.brand.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: (isReady && !_isLoading) ? _submitOrder : null,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withValues(alpha: 0.2),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          buttonText,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: isReady
                                ? Colors.white
                                : context.colors.textMuted,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getButtonText(
    String paymentMethod,
    double total,
    CurrencyProvider currency,
  ) {
    switch (paymentMethod) {
      case 'cod':
        return 'Оформить заказ';
      case 'podeli':
        final installment = (total / 4).floorToDouble();
        return 'Оплатить ${_formatPrice(installment, currency)}';
      default:
        return 'Оплатить ${_formatPrice(total, currency)}';
    }
  }

  String _formatPrice(double price, CurrencyProvider currency) {
    if (price <= 0) return '0 ${currency.symbol}';
    if (currency.currency == 'BYN') {
      return '${price.toStringAsFixed(2)} ${currency.symbol}';
    }
    if (price == price.roundToDouble()) {
      return '${price.toInt()} ${currency.symbol}';
    }
    return '${price.toStringAsFixed(2)} ${currency.symbol}';
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