// lib/providers/order_refresh_provider.dart
import 'package:flutter/material.dart';

/// Сигнализирует о необходимости обновить список заказов
class OrderRefreshProvider extends ChangeNotifier {
  int _refreshCount = 0;

  int get refreshCount => _refreshCount;

  /// Вызвать при создании/изменении заказа — обновит OrderPreview и OrdersScreen
  void notifyOrderChanged() {
    _refreshCount++;
    notifyListeners();
  }
}