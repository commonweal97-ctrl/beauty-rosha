// lib/widgets/product/product_reviews_section.dart
import 'package:flutter/material.dart';
import '../../models/product_detail.dart';
import '../../core/app_colors.dart';

class ProductReviewsSection extends StatelessWidget {
  final List<ProductReview> reviews;

  const ProductReviewsSection({
    super.key,
    required this.reviews,
  });

  String _imageUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://xn--80abvyjk6cts.xn--p1ai/$url';
  }

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              final isFirst = index == 0;
              final isLast = index == reviews.length - 1;
              return Padding(
                padding: EdgeInsets.only(
                  left: isFirst ? 16 : 0,
                  right: isLast ? 16 : 8,
                ),
                child: _buildReviewCard(review, context),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildReviewCard(ProductReview review, BuildContext context) {
    final hasMedia = review.photos.isNotEmpty || review.video != null;
    final hasText = (review.text?.isNotEmpty ?? false) ||
        (review.pros?.isNotEmpty ?? false) ||
        (review.cons?.isNotEmpty ?? false);

    return GestureDetector(
      onTap: () => _showReviewPopup(context, review),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    review.firstName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: List.generate(5, (i) => Text(
                    i < review.rating ? '★' : '☆',
                    style: TextStyle(
                      fontSize: 13,
                      color: i < review.rating ? context.colors.warning : context.colors.border,
                    ),
                  )),
                ),
              ],
            ),
            SizedBox(height: 2),
            Text(
              review.createdAt.length >= 10 ? review.createdAt.substring(0, 10) : review.createdAt,
              style: TextStyle(fontSize: 11, color: context.colors.textMuted),
            ),

            const SizedBox(height: 6),

            // Текстовые поля
            if (hasText) ...[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (review.pros?.isNotEmpty ?? false) ...[
                        _buildLabeledText(context, 'Достоинства', review.pros!),
                        const SizedBox(height: 4),
                      ],
                      if (review.cons?.isNotEmpty ?? false) ...[
                        _buildLabeledText(context, 'Недостатки', review.cons!),
                        const SizedBox(height: 4),
                      ],
                      if (review.text?.isNotEmpty ?? false)
                        _buildLabeledText(context, 'Комментарий', review.text!),
                    ],
                  ),
                ),
              ),
            ] else
              const Spacer(),

            // Медиа
            if (hasMedia) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 56,
                child: Row(
                  children: [
                    if (review.video != null) ...[
                      _buildVideoThumbnail(review.video!, context),
                      const SizedBox(width: 6),
                    ],
                    ...review.photos.take(3).map((photo) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildPhotoThumbnail(photo, context),
                    )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledText(BuildContext context, String label, String text) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.colors.textMuted,
            ),
          ),
          TextSpan(
            text: text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: context.colors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildVideoThumbnail(String videoUrl, BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullscreenMedia(context, videoUrl, isVideo: true),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(String photo, BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullscreenMedia(context, photo, isVideo: false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _imageUrl(photo),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  void _openFullscreenMedia(BuildContext context, String mediaUrl, {required bool isVideo}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenMediaViewer(
          mediaUrl: _imageUrl(mediaUrl),
          isVideo: isVideo,
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
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: context.colors.surfaceAlt,
                      child: Text(
                        review.firstName.isNotEmpty ? review.firstName[0].toUpperCase() : '?',
                        style: TextStyle(fontWeight: FontWeight.w600, color: context.colors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(review.firstName, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          Text(
                            review.createdAt.length >= 10 ? review.createdAt.substring(0, 10) : review.createdAt,
                            style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => Text(
                  i < review.rating ? '★' : '☆',
                  style: TextStyle(
                    fontSize: 32,
                    color: i < review.rating ? context.colors.warning : context.colors.border,
                  ),
                )),
              ),

              if (review.photos.isNotEmpty || review.video != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (review.video != null)
                        _buildVideoThumbnail(review.video!, ctx),
                      ...review.photos.map((photo) => _buildPhotoThumbnail(photo, ctx)),
                    ],
                  ),
                ),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (review.pros?.isNotEmpty ?? false) ...[
                        _buildLabeledText(context, 'Достоинства', review.pros!),
                        const SizedBox(height: 8),
                      ],
                      if (review.cons?.isNotEmpty ?? false) ...[
                        _buildLabeledText(context, 'Недостатки', review.cons!),
                        const SizedBox(height: 8),
                      ],
                      if (review.text?.isNotEmpty ?? false)
                        _buildLabeledText(context, 'Комментарий', review.text!),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullscreenMediaViewer extends StatefulWidget {
  final String mediaUrl;
  final bool isVideo;

  const _FullscreenMediaViewer({
    required this.mediaUrl,
    required this.isVideo,
  });

  @override
  State<_FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<_FullscreenMediaViewer> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: widget.isVideo
            ? InteractiveViewer(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
                ),
              )
            : InteractiveViewer(
                child: Image.network(
                  widget.mediaUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              ),
      ),
    );
  }
}