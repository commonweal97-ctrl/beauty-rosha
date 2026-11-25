// lib/widgets/product/product_info_section.dart
import 'package:flutter/material.dart';
import '../../models/product_detail.dart';
import 'product_delivery_estimate.dart';
import '../../core/app_colors.dart';

class ProductInfoSection extends StatefulWidget {
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

  @override
  State<ProductInfoSection> createState() => _ProductInfoSectionState();
}

class _ProductInfoSectionState extends State<ProductInfoSection> {
  final Set<int> _expandedReviewIds = {};

  String _imageUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://xn--80abvyjk6cts.xn--p1ai/$url';
  }

  String _reviewPreviewText(ProductReview review) {
    if (review.text != null && review.text!.trim().isNotEmpty) {
      return review.text!.trim();
    }
    if (review.pros != null && review.pros!.trim().isNotEmpty) {
      return 'Достоинства: ${review.pros!.trim()}';
    }
    if (review.cons != null && review.cons!.trim().isNotEmpty) {
      return 'Недостатки: ${review.cons!.trim()}';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final delivery = widget.delivery;
    final reviewPhotos = widget.reviewPhotos;
    final onReviewsTap = widget.onReviewsTap;
    final onQuestionsTap = widget.onQuestionsTap;
    final onBrandTap = widget.onBrandTap;
    final onAboutTap = widget.onAboutTap;
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
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.star, color: context.colors.warning, size: 28),
                              SizedBox(width: 6),
                              Text(
                                product.averageRating > 0 ? product.averageRating.toStringAsFixed(1) : '—',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: context.colors.textPrimary),
                              ),
                            ],
                          ),
                          Text(
                            '${product.reviewCount} ${_pluralReviews(product.reviewCount)}',
                            style: TextStyle(fontSize: 13, color: context.colors.textMuted),
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
                decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: context.colors.textDisabled)),
                          child: Center(child: Text('?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.colors.textMuted))),
                        ),
                        SizedBox(width: 6),
                        Text('${product.questionCount}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(_pluralQuestions(product.questionCount), style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Отзывы
        if (product.reviews.isNotEmpty)
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 132,
                maxHeight: _expandedReviewIds.isNotEmpty ? 236 : 134,
              ),
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
          decoration: BoxDecoration(color: context.colors.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.brand != null)
                GestureDetector(
                  onTap: onBrandTap,
                  child: Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(20)),
                    child: Text(product.brand!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.colors.textSecondary)),
                  ),
                ),
              Text(product.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3, color: context.colors.textPrimary)),
              if (product.description != null && product.description!.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  product.description!.replaceAll(RegExp(r'<[^>]+>'), '').length > 120
                      ? '${product.description!.replaceAll(RegExp(r'<[^>]+>'), '').substring(0, 120)}...'
                      : product.description!.replaceAll(RegExp(r'<[^>]+>'), ''),
                  style: TextStyle(fontSize: 14, color: context.colors.textSecondary, height: 1.5),
                ),
                SizedBox(height: 4),
                GestureDetector(
                  onTap: onAboutTap,
                  child: Text('О товаре', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.brand)),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(ProductReview review, BuildContext context) {
    final isExpanded = _expandedReviewIds.contains(review.id);
    final preview = _reviewPreviewText(review);
    final maxLines = isExpanded ? 5 : 3;

    return GestureDetector(
      onTap: () {
        if (preview.isEmpty) {
          widget.onReviewsTap?.call();
          return;
        }
        setState(() {
          if (isExpanded) {
            _expandedReviewIds.remove(review.id);
          } else {
            _expandedReviewIds.add(review.id);
          }
        });
      },
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          review.firstName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                      if (review.isPinned) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.push_pin,
                          size: 13,
                          color: context.colors.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Закреплён',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: List.generate(
                    5,
                    (i) => Text(
                      i < review.rating ? '★' : '☆',
                      style: TextStyle(
                        fontSize: 13,
                        color: i < review.rating
                            ? context.colors.warning
                            : context.colors.border,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final textStyle = TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textPrimary.withValues(alpha: 0.88),
                    height: 1.38,
                  );
                  final span = TextSpan(text: preview, style: textStyle);
                  final tp = TextPainter(
                    text: span,
                    maxLines: maxLines,
                    textDirection: TextDirection.ltr,
                  )..layout(maxWidth: constraints.maxWidth);

                  final hasMore = tp.didExceedMaxLines;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        preview,
                        maxLines: maxLines,
                        overflow: TextOverflow.ellipsis,
                        style: textStyle,
                      ),
                      if (!isExpanded && hasMore)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'ещё',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: context.colors.brand,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
            if (isExpanded) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  if (widget.onReviewsTap != null) {
                    widget.onReviewsTap!();
                  }
                },
                child: Text(
                  'Перейти к отзывам',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.brand,
                  ),
                ),
              ),
            ],
          ],
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