// lib/models/mobile_menu_data.dart
class MobileMenuData {
  final List<MenuCategory> categories;
  final List<MenuBanner> banners;
  final int unreadNotifications;
  final String city;

  MobileMenuData({
    required this.categories,
    required this.banners,
    required this.unreadNotifications,
    required this.city,
  });

  factory MobileMenuData.fromJson(Map<String, dynamic> json) {
    return MobileMenuData(
      categories: (json['categories'] as List? ?? [])
          .map((c) => MenuCategory.fromJson(c))
          .toList(),
      banners: (json['banners'] as List? ?? [])
          .map((b) => MenuBanner.fromJson(b))
          .toList(),
      unreadNotifications: json['unread_notifications'] ?? 0,
      city: json['city'] ?? 'Брянск',
    );
  }
}

class MenuCategory {
  final int id;
  final String name;
  final String slug;
  final String? imageUrl;
  final String? iconUrl;
  final int subCount;

  MenuCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.iconUrl,
    this.subCount = 0,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      imageUrl: json['image_url'],
      iconUrl: json['icon_url'],
      subCount: json['sub_count'] ?? 0,
    );
  }
}

class MenuBanner {
  final int id;
  final String title;
  final String imageUrl;
  final String linkUrl;
  final String bannerType;
  final int sortOrder;

  MenuBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.linkUrl,
    required this.bannerType,
    required this.sortOrder,
  });

  factory MenuBanner.fromJson(Map<String, dynamic> json) {
    return MenuBanner(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      imageUrl: json['image_url'] ?? '',
      linkUrl: json['link_url'] ?? '',
      bannerType: json['type'] ?? json['banner_type'] ?? 'medium',
      sortOrder: json['sort_order'] ?? 0,
    );
  }
}