// lib/screens/checkout/widgets/courier_delivery_form.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../../core/app_logger.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/checkout_provider.dart';
import '../../../services/api_service.dart';
import 'courier_address_screen.dart';
import 'delivery_slots.dart';
import '../../../core/app_colors.dart';

class CourierDeliveryForm extends StatefulWidget {
  const CourierDeliveryForm({super.key});

  @override
  State<CourierDeliveryForm> createState() => _CourierDeliveryFormState();
}

class _CourierDeliveryFormState extends State<CourierDeliveryForm> {
  static const _logTag = 'CourierDeliveryForm';

  bool _hasAddress = false;
  String _address = '';
  double _deliveryCost = 0;
  bool _isFree = true;
  bool _loadingCost = false;

  @override
  void initState() {
    super.initState();
    AppLogger.info(_logTag, 'initState');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _restoreSavedAddress();
      }
    });
  }

  void _restoreSavedAddress() {
    final checkout = context.read<CheckoutProvider>();
    final savedData = checkout.courierData;

    AppLogger.info(_logTag, 'restoreSavedAddress: savedData=$savedData');

    if (savedData.isNotEmpty &&
        (savedData['address']?.isNotEmpty ?? false)) {
      AppLogger.info(
        _logTag,
        'restoreSavedAddress: found saved address=${savedData['address']}',
      );

      setState(() {
        _address = savedData['address'] ?? '';
        _hasAddress = true;
        _deliveryCost = checkout.deliveryCost;
        _isFree = _deliveryCost == 0;
      });

      checkout.setCourierAddress(_address);
      checkout.setCourierReady(true);

      AppLogger.info(
        _logTag,
        'restoreSavedAddress: calling _refreshDeliveryCost',
      );
      _refreshDeliveryCost();
    } else {
      AppLogger.info(
        _logTag,
        'restoreSavedAddress: no saved address found',
      );
    }
  }

  Future<void> _refreshDeliveryCost() async {
    final cart = context.read<CartProvider>();
    final cartTotal = cart.finalTotal;

    AppLogger.info(
      _logTag,
      'refreshDeliveryCost: fetching /api/delivery/courier-cost'
          '?cart_total=$cartTotal',
    );

    final result = await ApiService.get(
      '/api/delivery/courier-cost?cart_total=$cartTotal',
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'refreshDeliveryCost failed: ${result.errorOrNull?.message}',
      );
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return;

    final cost = (data['delivery_cost'] as num?)?.toDouble() ?? 0;
    final isFree = data['is_free'] ?? (cost == 0);
    final hasAddress = data['has_address'] ?? false;

    AppLogger.info(
      _logTag,
      'refreshDeliveryCost: cost=$cost, isFree=$isFree, '
          'hasAddress=$hasAddress',
    );

    setState(() {
      _deliveryCost = cost;
      _isFree = isFree;
    });

    context.read<CheckoutProvider>().setDeliveryCost(_deliveryCost);
  }

  Future<void> _openAddressMap() async {
    AppLogger.info(_logTag, 'openAddressMap: opening map...');
    Position? position;

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission =
            await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
        }
      }
    } catch (_) {
      // Геолокация недоступна — продолжаем без неё.
    }

    if (!mounted) return;

    final result = await Navigator.of(context, rootNavigator: true)
        .push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => CourierAddressScreen(
          initialAddress: _address,
          userLatitude: position?.latitude,
          userLongitude: position?.longitude,
        ),
      ),
    );

    AppLogger.info(_logTag, 'openAddressMap: result=$result');

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _address = result['address'] ?? _address;
        _hasAddress = true;
      });

      await _saveAddressAndFetchCost(result);
    }
  }

  Future<void> _saveAddressAndFetchCost(
    Map<String, String> data,
  ) async {
    AppLogger.info(_logTag, 'saveAddressAndFetchCost: data=$data');
    setState(() => _loadingCost = true);

    final address = data['address'] ?? '';

    if (mounted) {
      final checkout = context.read<CheckoutProvider>();

      final mergedData = Map<String, String>.from(checkout.courierData);
      mergedData.addAll(data);
      AppLogger.info(
        _logTag,
        'saveAddressAndFetchCost: saving mergedData=$mergedData to provider',
      );
      checkout.setCourierData(mergedData);
      checkout.setCourierAddress(address);
      checkout.setCourierReady(true);
    }

    AppLogger.info(
      _logTag,
      'saveAddressAndFetchCost: saving to server...',
    );
    final saveResult = await ApiService.post(
      '/api/delivery/save-courier',
      {
        'address': address,
        'apartment': data['apartment'] ?? '',
        'floor': data['floor'] ?? '',
        'entrance': data['entrance'] ?? '',
        'doorphone': data['doorphone'] ?? '',
        'comments': data['comment'] ?? '',
      },
    );

    if (!mounted) return;

    if (saveResult.isFailure) {
      AppLogger.warning(
        _logTag,
        'save-courier failed: ${saveResult.errorOrNull?.message}',
      );
      setState(() => _loadingCost = false);
      return;
    }

    final cart = context.read<CartProvider>();
    AppLogger.info(
      _logTag,
      'saveAddressAndFetchCost: fetching courier-cost with '
          'cartTotal=${cart.finalTotal}',
    );

    final result = await ApiService.get(
      '/api/delivery/courier-cost?cart_total=${cart.finalTotal}',
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'courier-cost failed: ${result.errorOrNull?.message}',
      );
      setState(() => _loadingCost = false);
      return;
    }

    final responseData = result.valueOrNull?['data'];
    if (responseData is! Map) {
      setState(() => _loadingCost = false);
      return;
    }

    final cost =
        (responseData['delivery_cost'] as num?)?.toDouble() ?? 0;
    final isFree = responseData['is_free'] ?? (cost == 0);

    AppLogger.info(
      _logTag,
      'saveAddressAndFetchCost: FINAL cost=$cost, isFree=$isFree',
    );

    setState(() {
      _deliveryCost = cost;
      _isFree = isFree;
      _loadingCost = false;
    });

    context.read<CheckoutProvider>().setDeliveryCost(_deliveryCost);
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.info(
      _logTag,
      'build: hasAddress=$_hasAddress, cost=$_deliveryCost, '
          'isFree=$_isFree',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.brand, width: 2),
            borderRadius: BorderRadius.circular(14),
            color: context.colors.brandLight,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  color: context.colors.brand,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Доставка до двери',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _hasAddress ? _address : 'Укажите адрес',
                      style: TextStyle(
                        fontSize: 13,
                        color: _hasAddress
                            ? context.colors.textPrimary
                            : context.colors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _openAddressMap,
          child: Container(
            width: double.infinity,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: const DecorationImage(
                image: AssetImage('assets/images/kartaphoto.webp'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.08),
                  ],
                ),
              ),
              child: Center(
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: 16),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: context.colors.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _hasAddress
                        ? 'Изменить адрес доставки'
                        : 'Установить адрес доставки',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_hasAddress && !_loadingCost) ...[
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.surfaceAlt),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Дата и время доставки',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _isFree
                            ? context.colors.success
                            : context.colors.brand,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isFree
                            ? 'Бесплатно'
                            : '${_deliveryCost.toInt()} ₽',
                        style: TextStyle(
                          color: context.colors.surface,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DeliverySlots(
                  deliveryCost: _deliveryCost,
                  isFree: _isFree,
                  onSlotSelected: (date, time) {
                    final checkout = context.read<CheckoutProvider>();
                    final allData =
                        Map<String, String>.from(checkout.courierData);
                    allData['delivery_date'] = date;
                    allData['delivery_time'] = time;
                    checkout.setCourierData(allData);

                    AppLogger.info(
                      _logTag,
                      'onSlotSelected: saving allData=$allData',
                    );

                    ApiService.post(
                      '/api/delivery/save-courier',
                      allData,
                    ).then((result) {
                      if (result.isFailure) {
                        AppLogger.warning(
                          _logTag,
                          'save-courier (slot) failed: '
                              '${result.errorOrNull?.message}',
                        );
                      }
                    });
                  },
                ),
              ],
            ),
          ),
        ],
        if (_loadingCost)
          Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(
                color: context.colors.brand,
              ),
            ),
          ),
      ],
    );
  }
}