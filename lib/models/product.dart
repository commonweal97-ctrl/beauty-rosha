// lib/models/product.dart
import 'dart:convert';
import '../services/cdn_service.dart';

class Product {
  final int id;
  final String name;
  final String slug;
  final String? sku;
  final double price;
  final double? salePrice;
  final double? cardPrice;
  final int stock;
  final String? mainImage;
  final String? mainImageCard;
  final String? mainImageDetail;
  final String? mainImageThumb;
  final String? mainImageOriginal;
  final List<String> gallery;
  final String? brand;
  final double averageRating;
  final int reviewCount;
  final Map<String, dynamic>? attributes;
  String? badge;
  final String? videoUrl;
  final DateTime? saleDateFrom;
  final DateTime? saleDateTo;

  Product({
    required this.id,
    required this.name,
    required this.slug,
    this.sku,
    required this.price,
    this.salePrice,
    this.cardPrice,
    required this.stock,
    this.mainImage,
    this.mainImageCard,
    this.mainImageDetail,
    this.mainImageThumb,
    this.mainImageOriginal,
    this.gallery = const [],
    this.brand,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.attributes,
    this.badge,
    this.videoUrl,
    this.saleDateFrom,
    this.saleDateTo,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? attributes;
    final attr = json['attributes'];
    if (attr is Map) {
      attributes = Map<String, dynamic>.from(attr);
    } else if (attr is String && attr.isNotEmpty) {
      try {
        final decoded = jsonDecode(attr);
        if (decoded is Map) {
          attributes = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    List<String> gallery = [];
    final gal = json['gallery'];
    if (gal is List) {
      gallery = List<String>.from(gal.map((g) => g.toString()));
    }

    final price = (json['price'] ?? 0).toDouble();
    final salePrice = json['sale_price']?.toDouble();
    final cardPrice = json['card_price']?.toDouble();

    String? videoUrl;
    if (json['video_url'] != null && json['video_url'].toString().isNotEmpty) {
      final raw = json['video_url'].toString();
      videoUrl = raw.startsWith('http') ? raw : 'https://xn--80abvyjk6cts.xn--p1ai/$raw';
    }

    return Product(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      sku: json['sku'],
      price: price,
      salePrice: salePrice,
      cardPrice: cardPrice,
      stock: json['stock'] ?? 0,
      mainImage: json['main_image'],
      mainImageCard: json['main_image_card'],
      mainImageDetail: json['main_image_detail'],
      mainImageThumb: json['main_image_thumb'],
      mainImageOriginal: json['main_image_original'],
      gallery: gallery,
      brand: json['brand'],
      averageRating: (json['average_rating'] ?? 0).toDouble(),
      reviewCount: json['review_count'] ?? 0,
      attributes: attributes,
      badge: json['badge'],
      videoUrl: videoUrl,
      saleDateFrom: json['sale_date_from'] != null 
          ? DateTime.tryParse(json['sale_date_from'].toString()) 
          : null,
      saleDateTo: json['sale_date_to'] != null 
          ? DateTime.tryParse(json['sale_date_to'].toString()) 
          : null,
    );
  }

  bool get hasSale => salePrice != null && salePrice! > 0 && salePrice! < price;
  bool get inStock => stock > 0;
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;
  
  // 🔥 Есть ли действующая акция со сроком
  bool get hasActiveSaleDate => hasSale && saleDateTo != null && saleDateTo!.isAfter(DateTime.now());
  DateTime? get saleEndDate => saleDateTo;

  // 🔥 ВИДЕО ДЛЯ ВОСПРОИЗВЕДЕНИЯ — всегда основной домен
  String? get videoUrlForPlayback {
    if (videoUrl == null) return null;
    return videoUrl!.replaceFirst(
      'https://xn--80aaf6ac.xn--80abvyjk6cts.xn--p1ai',
      'https://xn--80abvyjk6cts.xn--p1ai',
    );
  }

  double get effectivePrice {
    if (hasSale) return salePrice!;
    if (cardPrice != null && cardPrice! < price) return cardPrice!;
    return price;
  }

  int get salePercent {
    if (!hasSale) return 0;
    return ((1 - salePrice! / price) * 100).round();
  }

  List<String> get allImages {
    final images = <String>[];
    if (mainImage != null && mainImage!.isNotEmpty) images.add(mainImage!);
    for (final img in gallery) {
      if (img != mainImage) images.add(img);
    }
    return images;
  }

  // 🔥 Возвращает URL с CDN для быстрой загрузки из любого региона
  String get imageUrl {
    if (mainImage != null && mainImage!.isNotEmpty) {
      return CdnService.imageUrl(mainImage!);
    }
    return '';
  }

  /// URL картинки для карточки каталога (~11 KB вместо 72 KB).
  /// Fallback на main_image, если сервер не отдал отдельный размер.
  String get imageUrlCard {
    final src = mainImageCard ?? mainImage;
    if (src != null && src.isNotEmpty) {
      return CdnService.imageUrl(src);
    }
    return '';
  }

  /// URL картинки для детального экрана (~28 KB).
  String get imageUrlDetail {
    final src = mainImageDetail ?? mainImage;
    if (src != null && src.isNotEmpty) {
      return CdnService.imageUrl(src);
    }
    return '';
  }

  /// URL картинки для превью — заказы, отзывы, cross-sells (~3 KB).
  String get imageUrlThumb {
    final src = mainImageThumb ?? mainImage;
    if (src != null && src.isNotEmpty) {
      return CdnService.imageUrl(src);
    }
    return '';
  }

  /// URL оригинала — full-screen viewer.
  String get imageUrlOriginal {
    final src = mainImageOriginal ?? mainImage;
    if (src != null && src.isNotEmpty) {
      return CdnService.imageUrl(src);
    }
    return '';
  }
  
  // 🔥 Возвращает все изображения с CDN
  List<String> get allImagesCdn {
    return allImages.map((img) => CdnService.imageUrl(img)).toList();
  }
}