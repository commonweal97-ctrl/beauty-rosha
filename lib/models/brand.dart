// lib/models/brand.dart
class Brand {
  final int? id;
  final String name;
  final String? logoUrl;
  final String initials;
  final bool isFavorite;

  Brand({
    this.id,
    required this.name,
    this.logoUrl,
    required this.initials,
    this.isFavorite = false,
  });

  factory Brand.fromJson(Map<String, dynamic> json) {
    return Brand(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      name: json['name'] ?? '',
      logoUrl: json['logo_url'],
      initials: json['initials'] ?? '',
      isFavorite: json['is_favorite'] ?? false,
    );
  }
}