import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class LiveActivityBridge {
  static const MethodChannel _channel = MethodChannel('beautyrosha/live_activity');
  static bool _loggingInitialized = false;

  static void initLogging() {
    if (_loggingInitialized) return;
    _loggingInitialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onSwiftLog') {
        debugPrint(call.arguments?.toString() ?? '');
      }
      return null;
    });
  }

  static Future<bool> syncOrderActivity(Map<String, dynamic> state) async {
    initLogging();
    if (!Platform.isIOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>('startOrUpdate', state);
      return res ?? false;
    } on PlatformException {
      return false;
    }
  }

  static Future<bool> stopOrderActivity(int orderId) async {
    initLogging();
    if (!Platform.isIOS) return false;
    try {
      final res = await _channel.invokeMethod<bool>('endActivity', {'order_id': orderId});
      return res ?? false;
    } on PlatformException {
      return false;
    }
  }
}
