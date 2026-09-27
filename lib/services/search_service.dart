// lib/services/search_service.dart
import '../core/app_logger.dart';
import 'api_service.dart';

class SearchService {
  static const _logTag = 'SearchService';

  static Future<Map<String, dynamic>> search(
    String query, {
    int page = 1,
    int limit = 24,
    String sort = 'popular',
    String? brand,
    double? priceFrom,
    double? priceTo,
    String stock = 'all',
    int? categoryId,
  }) async {
    final params = <String, String>{
      'q': query,
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (sort != 'popular') params['sort'] = sort;
    if (brand != null) params['brand'] = brand;
    if (priceFrom != null) params['price_from'] = priceFrom.toString();
    if (priceTo != null) params['price_to'] = priceTo.toString();
    if (stock != 'all') params['stock'] = stock;
    if (categoryId != null) params['category'] = categoryId.toString();

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final result = await ApiService.get('/api/search?$queryString');

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'search("$query") failed: ${result.errorOrNull?.message}',
      );
      return {'products': [], 'total': 0, 'badges': []};
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return {'products': [], 'total': 0, 'badges': []};

    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> getSuggestions(
    String query, {
    String? brand,
  }) async {
    final params = <String, String>{'q': query};
    if (brand != null && brand.isNotEmpty) {
      params['brand'] = brand;
    }

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    final result =
        await ApiService.get('/api/search/suggestions?$queryString');

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'suggestions("$query") failed: ${result.errorOrNull?.message}',
      );
      return {'popular': [], 'history': [], 'suggestions': []};
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return {'popular': [], 'history': [], 'suggestions': []};

    return Map<String, dynamic>.from(data);
  }
}