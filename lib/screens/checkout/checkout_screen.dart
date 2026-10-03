// lib/screens/checkout/checkout_screen.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_logger.dart';
import '../../services/haptic_service.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_provider.dart';
import '../../providers/city_provider.dart';
import '../../providers/currency_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/api_service.dart';
import '../../widgets/city_picker.dart';
import 'widgets/bonus_block.dart';
import 'widgets/checkout_button.dart';
import 'widgets/city_currency_header.dart';
import 'widgets/delivery_method_selector.dart';
import 'widgets/order_items_block.dart';
import 'widgets/order_summary_block.dart';
import 'widgets/payment_methods_block.dart';
import '../../core/app_colors.dart';

class CheckoutScreen extends StatefulWidget {
  final int orderId;

  const CheckoutScreen({super.key, required this.orderId});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const _logTag = 'CheckoutScreen';

  @override
  void initState() {
    super.initState();
    AnalyticsService.logScreen('checkout_${widget.orderId}');

    _preloadMapTiles();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final checkout = context.read<CheckoutProvider>();
      final cart = context.read<CartProvider>();

      checkout.init(widget.orderId);

      if (cart.finalTotal > 0) {
        checkout.updateCartTotal(cart.finalTotal);
      }

      final city = context.read<CityProvider>().city;
      _updateDeliveryMethodForCity(checkout, city);
    });
  }

  Future<void> _preloadMapTiles() async {
    LatLng center = const LatLng(53.23, 34.32);

    final city = context.read<CityProvider>().city;

    final cityCoords = {
      'брянск': (53.23, 34.32),
      'москва': (55.75, 37.61),
      'санкт-петербург': (59.93, 30.31),
      'екатеринбург': (56.83, 60.60),
    };

    final lowerCity = city.toLowerCase();
    for (final entry in cityCoords.entries) {
      if (lowerCity.contains(entry.key)) {
        center = LatLng(entry.value.$1, entry.value.$2);
        break;
      }
    }

    for (final zoom in [12, 13]) {
      final n = pow(2, zoom).toDouble();
      final tileX = ((center.longitude + 180) / 360 * n).floor();
      final latRad = center.latitude * pi / 180;
      final tileY =
          ((1 - log(tan(latRad) + 1 / cos(latRad)) / pi) / 2 * n).floor();

      for (int dx = -2; dx <= 2; dx++) {
        for (int dy = -2; dy <= 2; dy++) {
          final url =
              'https://tile.openstreetmap.org/$zoom/${tileX + dx}/${tileY + dy}.png';
          try {
            if (!mounted) return;
            await precacheImage(NetworkImage(url), context);
          } catch (_) {
            // Тайл не загрузился — не критично.
          }
        }
      }
    }
  }

  void _updateDeliveryMethodForCity(
    CheckoutProvider checkout,
    String city,
  ) {
    final methods = _getLocalMethods(city);
    if (methods.isEmpty) return;

    if (!methods.contains(checkout.deliveryMethod)) {
      HapticService.light();
      checkout.setDeliveryMethod(methods.first);
    }
  }

  Future<void> _onCitySelected(String city, String country) async {
    final checkout = context.read<CheckoutProvider>();

    final deselectResult = await ApiService.post(
      '/api/pickup/deselect',
      {'keep_method': true},
    );

    if (deselectResult.isFailure) {
      AppLogger.warning(
        _logTag,
        'deselect pickup failed: '
            '${deselectResult.errorOrNull?.message}',
      );
    }

    if (!mounted) return;

    final result = await ApiService.get(
      '/api/delivery/check-city?city=$city&country=$country',
    );

    if (!mounted) return;

    if (result.isSuccess) {
      final data = result.valueOrNull?['data'];
      final methodsRaw = data is Map ? data['methods'] : null;
      if (methodsRaw is List) {
        final methods =
            methodsRaw.whereType<String>().toList(growable: false);
        if (methods.isNotEmpty) {
          HapticService.light();
      checkout.setDeliveryMethod(methods.first);
        }
      }
    } else {
      AppLogger.warning(
        _logTag,
        'check-city("$city") failed: ${result.errorOrNull?.message}',
      );
      final localMethods = _getLocalMethods(city);
      if (localMethods.isNotEmpty) {
        HapticService.light();
        checkout.setDeliveryMethod(localMethods.first);
      }
    }

    if (!mounted) return;

    await context.read<CityProvider>().setCity(city, country);
  }

  List<String> _getLocalMethods(String city) {
    final lower = city.toLowerCase();
    if (['брянск', 'путевка', 'супонево'].any((c) => lower.contains(c))) {
      return ['pickup-store', 'courier'];
    }
    const oblast = [
      'почеп', 'погар', 'унеча', 'дятьково', 'сельцо', 'фокино',
      'клинцы', 'новозыбков', 'стародуб', 'трубчевск', 'карачев',
      'жуковка', 'сураж', 'мглин', 'суземка', 'комаричи', 'навля',
      'выгоничи',
    ];
    if (oblast.any((c) => lower.contains(c))) {
      return ['pickup-store', 'pickup-point'];
    }
    return ['pickup-point'];
  }

  void _openCityPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => CityPicker(
        onSelect: (city, country) => _onCitySelected(city, country),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final checkout = context.watch<CheckoutProvider>();
    final currency = context.watch<CurrencyProvider>();
    final city = context.watch<CityProvider>().city;

    final checkedCount = cart.checkedIds.fold(
      0,
      (sum, id) => sum + (cart.items[id] ?? 0),
    );
    final checkedTotal = cart.finalTotal;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (cart.loaded && cart.finalTotal > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        checkout.updateCartTotal(cart.finalTotal);
        AnalyticsService.logCheckout(checkedTotal, checkedCount);
      });
    }

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
                    padding: const EdgeInsets.only(bottom: 180),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        CityCurrencyHeader(
                          city: city,
                          onCityTap: _openCityPicker,
                        ),
                        DeliveryMethodSelector(city: city),
                        const BonusBlock(),
                        const PaymentMethodsBlock(),
                        const OrderItemsBlock(),
                        const OrderSummaryBlock(),
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
            child: ClipRRect(
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(20)),
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
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Оформление заказа',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            '$checkedCount ${_pluralItems(checkedCount)}, '
                            '${_formatPrice(checkedTotal, currency)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.colors.textMuted,
                              fontFamily: currency.fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: bottomPadding > 0 ? bottomPadding + 0 : 16,
            left: 0,
            right: 0,
            child: const CheckoutButton(),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price, CurrencyProvider currency) {
    if (price == price.roundToDouble()) {
      return '${price.toInt()} ${currency.symbol}';
    }
    return '${price.toStringAsFixed(2)} ${currency.symbol}';
  }
}