// lib/services/cart_service.dart
import '../core/result.dart';
import 'api_service.dart';

class CartService {
  static Future<Result<Map<String, dynamic>>> addToCart(
    int productId, {
    int quantity = 1,
  }) async {
    return await ApiService.post('/api/cart/add', {
      'product_id': productId,
      'quantity': quantity,
    });
  }

  static Future<Result<Map<String, dynamic>>> removeFromCart(
    int productId,
  ) async {
    return await ApiService.post('/api/cart/remove', {
      'product_id': productId,
    });
  }

  static Future<Result<Map<String, dynamic>>> updateQuantity(
    int productId,
    int quantity,
  ) async {
    return await ApiService.post('/api/cart/update', {
      'product_id': productId,
      'quantity': quantity,
    });
  }

  static Future<Result<Map<String, dynamic>>> getItems() async {
    return await ApiService.get('/api/cart/items');
  }

  static Future<Result<Map<String, dynamic>>> removeMultiple(
    List<int> productIds,
  ) async {
    return await ApiService.post('/api/cart/remove-multiple', {
      'product_ids': productIds,
    });
  }

  static Future<Result<Map<String, dynamic>>> syncCart(
    List<Map<String, dynamic>> items,
  ) async {
    return await ApiService.post('/api/cart/sync', {
      'items': items,
    });
  }
}