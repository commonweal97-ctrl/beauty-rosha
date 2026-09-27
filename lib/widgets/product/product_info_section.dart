// lib/widgets/product/product_info_section.dart
import 'package:flutter/material.dart';
import '../../models/product_detail.dart';
import 'product_delivery_estimate.dart';

class ProductInfoSection extends StatelessWidget {
  final ProductDetail product;
  final VoidCallback onAboutTap;
  final VoidCallback? onBrandTap;
  final List<String> reviewPhotos;
  final VoidCallback? onReviewsTap;
  final VoidCallback? onQuestionsTap;
  final DeliveryEstimate? delivery;

  const ProductInfoSection({
    super.key,
    required this.product,
    required this.onAboutTap,
    this.onBrandTap,
    this.reviewPhotos = const [],
    this.onReviewsTap,
    this.onQuestionsTap,
    this.delivery,
  });

  String _imageUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://xn--80abvyjk6cts.xn--p1ai/$url';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),

        // Блок рейтинга и вопросов — от края до края
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onReviewsTap,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star, color: Color(0xFFF5A623), size: 28),
                              const SizedBox(width: 6),
                              Text(
                                product.averageRating > 0 ? product.averageRating.toStringAsFixed(1) : '—',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
                              ),
                            ],
                          ),
                          Text(
                            '${product.reviewCount} ${_pluralReviews(product.reviewCount)}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF8F8F9A)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (reviewPhotos.isNotEmpty)
                        SizedBox(
                          width: 70,
                          height: 70,
                          child: Stack(
                            children: reviewPhotos.take(3).toList().asMap().entries.map((entry) {
                              final i = entry.key;
                              final photo = entry.value;
                              return Positioned(
                                left: i * 10.0,
                                child: Transform.rotate(
                                  angle: i == 0 ? -0.08 : (i == 1 ? 0.05 : -0.03),
                                  child: Container(
                                    width: 56,
                                    height: 70,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 3)],
                                      image: DecorationImage(image: NetworkImage(_imageUrl(photo)), fit: BoxFit.cover),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onQuestionsTap,
              child: Container(
                width: 90,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFC0C0C0))),
                          child: const Center(child: Text('?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF999999)))),
                        ),
                        const SizedBox(width: 6),
                        Text('${product.questionCount}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_pluralQuestions(product.questionCount), style: const TextStyle(fontSize: 11, color: Color(0xFF8F8F9A))),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Отзывы
        if (product.reviews.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: product.reviews.length,
              itemBuilder: (context, index) {
                final review = product.reviews[index];
                final isLast = index == product.reviews.length - 1;
                return Padding(
                  padding: EdgeInsets.only(right: isLast ? 0 : 8),
                  child: _buildReviewCard(review, context),
                );
              },
            ),
          ),

        if (product.reviews.isNotEmpty) const SizedBox(height: 8),

        // Доставка
        if (delivery != null)
          ProductDeliveryEstimate(delivery: delivery),

        if (delivery != null) const SizedBox(height: 8),

        // Бренд + название + описание
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.brand != null)
                GestureDetector(
                  onTap: onBrandTap,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFFE8E8EC), borderRadius: BorderRadius.circular(20)),
                    child: Text(product.brand!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF555555))),
                  ),
                ),
              Text(product.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3, color: Color(0xFF1A1A1A))),
              if (product.description != null && product.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  product.description!.replaceAll(RegExp(r'<[^>]+>'), '').length > 120
                      ? '${product.description!.replaceAll(RegExp(r'<[^>]+>'), '').substring(0, 120)}...'
                      : product.description!.replaceAll(RegExp(r'<[^>]+>'), ''),
                  style: const TextStyle(fontSize: 14, color: Color(0xFF555555), height: 1.5),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onAboutTap,
                  child: const Text('О товаре', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFDD1847))),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(ProductReview review, BuildContext context) {
    return GestureDetector(
      onTap: () => _showReviewPopup(context, review),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(review.firstName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                Row(
                  children: List.generate(5, (i) => Text(
                    i < review.rating ? '★' : '☆',
                    style: TextStyle(fontSize: 13, color: i < review.rating ? const Color(0xFFFFB800) : const Color(0xFFD0D0D0)),
                  )),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              review.createdAt.length >= 10 ? review.createdAt.substring(0, 10) : review.createdAt,
              style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
            ),
            if (review.text != null) ...[
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  review.text!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF555555), height: 1.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReviewPopup(BuildContext context, ProductReview review) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 500),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    CircleAvatar(backgroundColor: const Color(0xFFF0F0F5), child: Text(review.firstName.isNotEmpty ? review.firstName[0].toUpperCase() : '?', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF666666)))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(review.firstName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          Text(review.createdAt.length >= 10 ? review.createdAt.substring(0, 10) : review.createdAt, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                        ],
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => Text(
                  i < review.rating ? '★' : '☆',
                  style: TextStyle(fontSize: 32, color: i < review.rating ? const Color(0xFFFFB800) : const Color(0xFFD0D0D0)),
                )),
              ),
              if (review.photos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: review.photos.map((photo) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(_imageUrl(photo), width: 80, height: 106, fit: BoxFit.cover),
                    )).toList(),
                  ),
                ),
              if (review.text != null)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Text(review.text!, style: const TextStyle(fontSize: 14, color: Color(0xFF3B3B44), height: 1.5)),
                  ),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  String _pluralReviews(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'оценка';
    if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) return 'оценки';
    return 'оценок';
  }

  String _pluralQuestions(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'вопрос';
    if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) return 'вопроса';
    return 'вопросов';
  }
}