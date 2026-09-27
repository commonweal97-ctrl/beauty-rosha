// lib/providers/checkout_provider.dart
import 'package:flutter/material.dart';

import '../core/app_logger.dart';
import '../models/store.dart';
import '../screens/checkout/pickup_map_screen.dart';
import '../services/api_service.dart';
import '../services/crashlytics_service.dart';

class CheckoutProvider extends ChangeNotifier {
  static const _logTag = 'CheckoutProvider';

  int? _orderId;
  double _cartTotal = 0;

  String _deliveryMethod = 'pickup-store';
  double _deliveryCost = 0;
  String _paymentMethod = 'card';
  Store? _selectedStore;
  PickupPoint? _selectedPickupPoint;
  int _bonusAmount = 0;
  Map<String, dynamic>? _orderData;
  bool _courierReady = false;
  String _courierAddress = '';
  Map<String, String> _courierData = {};

  int? get orderId => _orderId;
  String get deliveryMethod => _deliveryMethod;
  double get deliveryCost => _deliveryCost;
  String get paymentMethod => _paymentMethod;
  Store? get selectedStore => _selectedStore;
  PickupPoint? get selectedPickupPoint => _selectedPickupPoint;
  int get bonusAmount => _bonusAmount;
  Map<String, dynamic>? get orderData => _orderData;
  bool get courierReady => _courierReady;
  String get courierAddress => _courierAddress;
  Map<String, String> get courierData => _courierData;

  void init(int orderId) {
    _orderId = orderId;

    CrashlyticsService.log('Checkout started: order $orderId');

    _loadOrderData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_deliveryMethod == 'pickup-point') {
        _refreshPickupPointCost();
      }
    });
  }

  Future<void> reload() async {
    if (_orderId == null) return;

    CrashlyticsService.log('Checkout reload: order $_orderId');

    try {
      await _loadOrderData();

      if (_deliveryMethod == 'pickup-point' && _selectedPickupPoint != null) {
        await _refreshPickupPointCost();
      }

      notifyListeners();
    } catch (e, stackTrace) {
      await CrashlyticsService.recordError(
        e,
        stackTrace,
        reason: 'Checkout reload failed',
      );
    }
  }

  Future<void> _loadOrderData() async {
    if (_orderId == null) return;

    final result =
        await ApiService.get('/api/orders/detail?order_id=$_orderId');

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadOrderData($_orderId) failed: ${result.errorOrNull?.message}',
      );
      await CrashlyticsService.recordError(
        result.errorOrNull!,
        result.errorOrNull?.stackTrace ?? StackTrace.current,
        reason: 'Order data load failed',
      );
      return;
    }

    final data = result.valueOrNull?['data'];

    // API возвращает List — берём первый элемент, либо Map напрямую.
    if (data is List && data.isNotEmpty) {
      _orderData = Map<String, dynamic>.from(data.first as Map);
    } else if (data is Map) {
      _orderData = Map<String, dynamic>.from(data);
    } else {
      _orderData = null;
    }

    CrashlyticsService.log('Order data loaded: $_orderId');
    notifyListeners();
  }

  void updateCartTotal(double cartTotal) {
    if (cartTotal <= 0) return;
    if (_cartTotal == cartTotal && _selectedPickupPoint != null) return;
    _cartTotal = cartTotal;

    if (_deliveryMethod == 'pickup-point') {
      _refreshPickupPointCost();
    }
  }

  Future<void> _refreshPickupPointCost() async {
    final url = '/api/pickup/selected?cart_total=$_cartTotal';
    final result = await ApiService.get(url);

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'refreshPickupPointCost failed: ${result.errorOrNull?.message}',
      );
      await CrashlyticsService.recordError(
        result.errorOrNull!,
        result.errorOrNull?.stackTrace ?? StackTrace.current,
        reason: 'Pickup point cost refresh failed',
      );
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return;

    final point = PickupPoint.fromJson(Map<String, dynamic>.from(data));
    _selectedPickupPoint = point;
    _deliveryCost = point.deliveryCost;
    notifyListeners();
  }

  void setDeliveryMethod(String method) {
    if (_deliveryMethod == method) return;
    _deliveryMethod = method;

    CrashlyticsService.log('Delivery method selected: $method');

    if (method == 'pickup-store') {
      _deliveryCost = 0;
      _selectedPickupPoint = null;
    } else if (method == 'pickup-point') {
      _refreshPickupPointCost();
    } else if (method == 'courier') {
      _deliveryCost = 0;
    }

    notifyListeners();

    // Fire-and-forget: не блокируем UI
    ApiService.post('/api/delivery/save-method', {'method': method})
        .then((result) {
      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'save-method($method) failed: ${result.errorOrNull?.message}',
        );
      }
    });
  }

  void setDeliveryCost(double cost) {
    if (_deliveryCost == cost) return;
    _deliveryCost = cost;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    if (_paymentMethod == method) return;
    _paymentMethod = method;

    CrashlyticsService.log('Payment method selected: $method');

    notifyListeners();

    // Fire-and-forget
    ApiService.post('/api/checkout/save-payment-method', {'method': method})
        .then((result) {
      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'save-payment-method($method) failed: '
              '${result.errorOrNull?.message}',
        );
      }
    });
  }

  void setSelectedStore(Store store) {
    _selectedStore = store;

    CrashlyticsService.log('Store selected: ${store.id} - ${store.name}');

    notifyListeners();

    // Fire-and-forget
    ApiService.post('/api/delivery/save-store', {
      'store_id': store.id,
      'name': store.name,
      'address': store.address,
    }).then((result) {
      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'save-store(${store.id}) failed: ${result.errorOrNull?.message}',
        );
      }
    });
  }

  void setSelectedPickupPoint(PickupPoint point) {
    _selectedPickupPoint = point;
    _deliveryCost = point.deliveryCost;

    CrashlyticsService.log('Pickup point selected: ${point.id}');

    notifyListeners();
  }

  void setBonusAmount(int amount) {
    _bonusAmount = amount;

    CrashlyticsService.log('Bonus amount set: $amount');

    notifyListeners();
  }

  void setCourierReady(bool ready) {
    _courierReady = ready;
    notifyListeners();
  }

  void setCourierAddress(String address) {
    _courierAddress = address;
    _courierData['address'] = address;
    notifyListeners();
  }

  void setCourierData(Map<String, String> data) {
    _courierData = Map<String, String>.from(data);
    _courierAddress = data['address'] ?? _courierAddress;
    _courierReady = _courierAddress.length > 3;

    CrashlyticsService.log(
      'Courier data set: address length ${_courierAddress.length}',
    );

    notifyListeners();
  }
}