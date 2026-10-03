// lib/models/product_detail.dart
import 'dart:convert';

import '../core/app_logger.dart';
import '../services/cdn_service.dart';

class ProductDetail {
  static const _logTag = 'ProductDetail';

  final int id;
  final String name;
  final String slug;
  final String? sku;
  final String? article;
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
  final String? brandSlug;
  final String? description;
  final double averageRating;
  final int reviewCount;
  final Map<String, dynamic>? attributes;
  final List<ProductCrossSell> crossSells;
  final List<ProductCrossSell> upsells;
  final List<ProductReview> reviews;
  final List<String> reviewPhotos;
  final int questionCount;
  final DeliveryEstimate? delivery;
  final String? badge;
  final String? badgeColor;
  final bool purchased;
  final bool alreadyRated;
  final Map<String, dynamic>? purchaseItem;
  final String? videoUrl;
  final DateTime? saleDateFrom;
  final DateTime? saleDateTo;

  ProductDetail({
    required this.id,
    required this.name,
    required this.slug,
    this.sku,
    this.article,
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
    this.brandSlug,
    this.description,
    this.averageRating = 0,
    this.reviewCount = 0,
    this.attributes,
    this.crossSells = const [],
    this.upsells = const [],
    this.reviews = const [],
    this.reviewPhotos = const [],
    this.questionCount = 0,
    this.delivery,
    this.badge,
    this.badgeColor,
    this.purchased = false,
    this.alreadyRated = false,
    this.purchaseItem,
    this.videoUrl,
    this.saleDateFrom,
    this.saleDateTo,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    final product = json['product'] ?? json;

    AppLogger.info(_logTag, 'Ключи product: ${product.keys.toList()}');
    AppLogger.info(_logTag, 'sale_date_from: ${product['sale_date_from']}');
    AppLogger.info(_logTag, 'sale_date_to: ${product['sale_date_to']}');

    List<String> gallery = [];
    final gal = product['gallery'];
    if (gal is List) {
      gallery = List<String>.from(gal.map((g) => g.toString()));
    } else if (gal is String && gal.isNotEmpty) {
      try {
        final decoded = jsonDecode(gal);
        if (decoded is List) {
          gallery = List<String>.from(decoded.map((g) => g.toString()));
        }
      } catch (_) {}
    }

    Map<String, dynamic>? attributes;
    final attr = product['attributes'];
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

    List<ProductCrossSell> crossSells = [];
    if (json['cross_sells'] is List) {
      crossSells = (json['cross_sells'] as List)
          .map((cs) => ProductCrossSell.fromJson(cs))
          .toList();
    }

    List<ProductCrossSell> upsells = [];
    if (json['upsells'] != null && json['upsells'] is List) {
      upsells = (json['upsells'] as List)
          .map((u) => ProductCrossSell.fromJson(u))
          .toList();
    }

    List<ProductReview> reviews = [];
    if (json['reviews'] is List) {
      reviews = (json['reviews'] as List)
          .map((r) => ProductReview.fromJson(r))
          .toList();
    }

    List<String> reviewPhotos = [];
    if (json['review_photos'] is List) {
      reviewPhotos =
          List<String>.from(json['review_photos'].map((p) => p.toString()));
    }

    DeliveryEstimate? delivery;
    if (json['delivery'] != null && json['delivery'] is Map) {
      delivery = DeliveryEstimate.fromJson(json['delivery']);
    }

    String? badge;
    String? badgeColor;
    final badges = json['badges'];
    if (badges is Map && badges.containsKey(product['id']?.toString())) {
      final b = badges[product['id'].toString()];
      if (b is Map) {
        badge = (b['text'] ?? b['title'] ?? '').toString();
        badgeColor = b['color']?.toString();
      }
    }

    final purchased = json['purchased'] ?? false;
    final alreadyRated = json['already_rated'] ?? false;
    Map<String, dynamic>? purchaseItem;
    if (json['purchase_item'] is Map) {
      purchaseItem = Map<String, dynamic>.from(json['purchase_item']);
    }

    String? videoUrl;
    if (product['video_url'] != null &&
        product['video_url'].toString().isNotEmpty) {
      final raw = product['video_url'].toString();
      videoUrl = raw.startsWith('http')
          ? raw
          : 'https://xn--80abvyjk6cts.xn--p1ai/$raw';
    }

    return ProductDetail(
      id: product['id'] ?? 0,
      name: product['name'] ?? '',
      slug: product['slug'] ?? '',
      sku: product['sku'],
      article: product['article'],
      price: (product['price'] ?? 0).toDouble(),
      salePrice: product['sale_price']?.toDouble(),
      cardPrice: product['card_price']?.toDouble(),
      stock: product['stock'] ?? 0,
      mainImage: product['main_image'],
      mainImageCard: product['main_image_card'],
      mainImageDetail: product['main_image_detail'],
      mainImageThumb: product['main_image_thumb'],
      mainImageOriginal: product['main_image_original'],
      gallery: gallery,
      brand: product['brand'],
      brandSlug: product['brand_slug'],
      description: product['description'],
      averageRating: (product['average_rating'] ?? 0).toDouble(),
      reviewCount: product['review_count'] ?? 0,
      attributes: attributes,
      crossSells: crossSells,
      upsells: upsells,
      reviews: reviews,
      reviewPhotos: reviewPhotos,
      questionCount: json['question_count'] ?? 0,
      delivery: delivery,
      badge: badge,
      badgeColor: badgeColor,
      purchased: purchased,
      alreadyRated: alreadyRated,
      purchaseItem: purchaseItem,
      videoUrl: videoUrl,
      saleDateFrom: product['sale_date_from'] != null
          ? DateTime.tryParse(product['sale_date_from'].toString())
          : null,
      saleDateTo: product['sale_date_to'] != null
          ? DateTime.tryParse(product['sale_date_to'].toString())
          : null,
    );
  }

  bool get hasSale => salePrice != null && salePrice! > 0 && salePrice! < price;
  bool get inStock => stock > 0;
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;

  // 🔥 Есть ли действующая акция со сроком
  bool get hasActiveSaleDate =>
      hasSale && saleDateTo != null && saleDateTo!.isAfter(DateTime.now());
  DateTime? get saleEndDate => saleDateTo;

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

  /// URL галереи с правильными размерами:
  ///   - main → detail (28 KB)
  ///   - gallery → обычный CDN
  List<String> get allImagesDetail {
    final images = <String>[];
    final mainUrl = imageUrlDetail;
    if (mainUrl.isNotEmpty) {
      images.add(mainUrl);
    }
    for (final img in gallery) {
      if (img != mainImage && img.isNotEmpty) {
        final cdnUrl = CdnService.imageUrl(img);
        if (cdnUrl.isNotEmpty) images.add(cdnUrl);
      }
    }
    return images;
  }

  String get imageUrl {
    if (mainImage != null && mainImage!.isNotEmpty) {
      return CdnService.imageUrl(mainImage!);
    }
    return '';
  }

  /// URL картинки для карточки каталога (~11 KB вместо 72 KB).
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

  Map<String, dynamic> toCartItem({int quantity = 1}) {
    return {
      'product_id': id,
      'quantity': quantity,
      'name': name,
      'slug': slug,
      'price': price,
      'sale_price': salePrice,
      'card_price': cardPrice,
      'main_image': mainImage ?? '',
      'stock': stock,
      'brand': brand ?? '',
      'category_id': null,
      'unavailable': false,
    };
  }
}

class ProductCrossSell {
  final int id;
  final String name;
  final String slug;
  final double price;
  final double? salePrice;
  final double? cardPrice;
  final String? mainImage;
  final String? mainImageCard;
  final String? mainImageDetail;
  final String? mainImageThumb;
  final List<String> gallery;
  final int stock;
  final String? videoUrl;

  ProductCrossSell({
    required this.id,
    required this.name,
    required this.slug,
    required this.price,
    this.salePrice,
    this.cardPrice,
    this.mainImage,
    this.mainImageCard,
    this.mainImageDetail,
    this.mainImageThumb,
    this.gallery = const [],
    required this.stock,
    this.videoUrl,
  });

  factory ProductCrossSell.fromJson(Map<String, dynamic> json) {
    List<String> gallery = [];
    final gal = json['gallery'];
    if (gal is List) {
      gallery = List<String>.from(gal.map((g) => g.toString()));
    }

    String? videoUrl;
    if (json['video_url'] != null && json['video_url'].toString().isNotEmpty) {
      final raw = json['video_url'].toString();
      videoUrl = raw.startsWith('http')
          ? raw
          : 'https://xn--80abvyjk6cts.xn--p1ai/$raw';
    }

    return ProductCrossSell(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      salePrice: json['sale_price']?.toDouble(),
      cardPrice: json['card_price']?.toDouble(),
      mainImage: json['main_image'],
      mainImageCard: json['main_image_card'],
      mainImageDetail: json['main_image_detail'],
      mainImageThumb: json['main_image_thumb'],
      gallery: gallery,
      stock: json['stock'] ?? 0,
      videoUrl: videoUrl,
    );
  }

  bool get hasSale => salePrice != null && salePrice! > 0 && salePrice! < price;
  bool get hasVideo => videoUrl != null && videoUrl!.isNotEmpty;

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

  String get imageUrl {
    if (mainImage != null && mainImage!.isNotEmpty) {
      return CdnService.imageUrl(mainImage!);
    }
    return '';
  }

  Map<String, dynamic> toCartItem({int quantity = 1}) {
    return {
      'product_id': id,
      'quantity': quantity,
      'name': name,
      'slug': slug,
      'price': price,
      'sale_price': salePrice,
      'card_price': cardPrice,
      'main_image': mainImage ?? '',
      'stock': stock,
      'brand': '',
      'category_id': null,
      'unavailable': false,
    };
  }
}

class ProductReview {
  final int id;
  final int userId;
  final String userName;
  final int rating;
  final String? text;
  final String? pros;
  final String? cons;
  final String? video;
  final String? videoPreview;
  final List<String> photos;
  final bool isPinned;
  final String? pinnedAt;
  final String createdAt;

  ProductReview({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rating,
    this.text,
    this.pros,
    this.cons,
    this.video,
    this.videoPreview,
    this.photos = const [],
    this.isPinned = false,
    this.pinnedAt,
    required this.createdAt,
  });

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    List<String> photos = [];
    final p = json['photos'] ?? json['images'];
    if (p is List) {
      photos = List<String>.from(p.map((ph) => ph.toString()));
    } else if (p is String && p.isNotEmpty) {
      try {
        final decoded = jsonDecode(p);
        if (decoded is List) {
          photos = List<String>.from(decoded.map((ph) => ph.toString()));
        }
      } catch (_) {}
    }

    return ProductReview(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userName: json['user_name'] ?? 'Аноним',
      rating: json['rating'] ?? 0,
      text: json['text'],
      pros: json['pros'],
      cons: json['cons'],
      video: json['video'],
      videoPreview: json['video_preview'],
      photos: photos,
      isPinned: json['is_pinned'] == 1 || json['is_pinned'] == true,
      pinnedAt: json['pinned_at'],
      createdAt: json['created_at'] ?? '',
    );
  }

  String get firstName => userName.split(' ').first;
}

class DeliveryEstimate {
  final String title;
  final String subtitle;
  final String city;
  final List<String> providers;

  DeliveryEstimate({
    required this.title,
    required this.subtitle,
    required this.city,
    this.providers = const [],
  });

  factory DeliveryEstimate.fromJson(Map<String, dynamic> json) {
    return DeliveryEstimate(
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      city: json['city'] ?? '',
      providers: (json['providers'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}