// lib/services/image_error_handler.dart
import 'package:flutter/foundation.dart';

class ImageErrorHandler {
  static bool _initialized = false;
  
  static void init() {
    if (_initialized) return;
    _initialized = true;
    
    // Сохраняем оригинальный обработчик
    final originalHandler = FlutterError.onError;
    
    FlutterError.onError = (FlutterErrorDetails details) {
      final exception = details.exception;
      
      // Игнорируем сетевые ошибки при загрузке изображений
      if (_isNetworkError(exception)) {
        debugPrint('🔇 Сетевая ошибка при загрузке изображения проигнорирована');
        return;
      }
      
      // Для остальных ошибок используем оригинальный обработчик
      originalHandler?.call(details);
    };
  }
  
  static bool _isNetworkError(dynamic exception) {
    final errorString = exception.toString();
    
    return errorString.contains('ClientException') ||
           errorString.contains('HandshakeException') ||
           errorString.contains('Connection closed') ||
           errorString.contains('Connection terminated') ||
           errorString.contains('SocketException') ||
           errorString.contains('TimeoutException') ||
           errorString.contains('NetworkImageLoadException');
  }
}