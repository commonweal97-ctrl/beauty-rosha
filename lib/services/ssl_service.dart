// lib/services/ssl_service.dart
import 'package:flutter/services.dart';

import '../core/app_logger.dart';

class SslService {
  static const _logTag = 'SslService';

  static const MethodChannel _channel = MethodChannel('beautyrosha/ssl');

  static Future<bool> trustAllCertificates() async {
    try {
      final result = await _channel.invokeMethod('trustAllCertificates');
      return result == true;
    } catch (e) {
      AppLogger.warning(_logTag, 'trustAllCertificates failed', e);
      return false;
    }
  }
}