// lib/models/category.dart
class Category {
  final int id;
  final String name;
  final String slug;
  final String? imageUrl;
  final int? parentId;

  Category({
    required this.id,
    required this.name,
    required this.slug,
    this.imageUrl,
    this.parentId,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      imageUrl: json['image_url'],
      parentId: json['parent_id'],
    );
  }
}