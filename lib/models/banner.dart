// lib/models/banner.dart
import '../services/cdn_service.dart';
class BannerItem {
  final int id;
  final String title;
  final String imageUrl;
  final String? linkUrl;
  final int sortOrder;

  BannerItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.linkUrl,
    required this.sortOrder,
  });

  String get fullImageUrl {
    if (imageUrl.startsWith('http')) return imageUrl;
    return CdnService.imageUrl(imageUrl);
  }

  factory BannerItem.fromJson(Map<String, dynamic> json) {
    return BannerItem(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      imageUrl: json['image_url'] ?? '',
      linkUrl: json['link_url'],
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}