// lib/screens/product/product_reviews_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_logger.dart';
import '../../services/api_service.dart';
import '../../widgets/product/fullscreen_media_viewer.dart';

class ProductReviewsScreen extends StatefulWidget {
  final int productId;
  final String productName;
  final int initialReviewCount;
  final double averageRating;

  const ProductReviewsScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.initialReviewCount = 0,
    this.averageRating = 0,
  });

  @override
  State<ProductReviewsScreen> createState() => _ProductReviewsScreenState();
}

class _ProductReviewsScreenState extends State<ProductReviewsScreen> {
  static const _logTag = 'ProductReviewsScreen';

  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  int _totalReviews = 0;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String _sort = 'newest';
  bool _onlyWithMedia = false;

  final List<Map<String, String>> _sortOptions = [
    {'key': 'newest', 'label': 'Новые'},
    {'key': 'oldest', 'label': 'Старые'},
    {'key': 'high_rating', 'label': 'С высокой оценкой'},
    {'key': 'low_rating', 'label': 'С низкой оценкой'},
  ];

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _scrollController.addListener(_onScroll);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadReviews();
    }
  }

  String _formatUserName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'Аноним';

    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'Аноним';

    return parts[0];
  }

  Future<void> _loadReviews({bool refresh = false}) async {
    if (_isLoading) return;
    if (!_hasMore && !refresh) return;

    if (refresh) {
      _page = 1;
      _hasMore = true;
      _reviews = [];
    }

    setState(() => _isLoading = true);

    final queryParams = <String, dynamic>{
      'product_id': widget.productId.toString(),
      'page': _page.toString(),
      'limit': '20',
      'sort': _sort,
      'only_with_media': _onlyWithMedia ? '1' : '0',
    };

    if (_searchController.text.isNotEmpty) {
      queryParams['search'] = _searchController.text;
    }

    final result = await ApiService.get(
      '/api/reviews/product',
      queryParams: queryParams,
      forceRefresh: true,
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadReviews(page=$_page) failed: ${result.errorOrNull?.message}',
      );
      setState(() {
        _hasMore = false;
        _isLoading = false;
      });
      return;
    }

    final data = result.valueOrNull?['data'];

    List<Map<String, dynamic>> items = [];

    if (data is Map && data['reviews'] is List) {
      items = (data['reviews'] as List)
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();

      final total = data['total'];
      if (total is int) {
        _totalReviews = total;
      }
    } else if (data is List) {
      items = data
          .whereType<Map>()
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
      _totalReviews = items.length;
    }

    setState(() {
      if (_page == 1) {
        _reviews = items;
      } else {
        _reviews.addAll(items);
      }
      _hasMore = data is Map
          ? (data['has_more'] ?? (items.length >= 20))
          : (items.length >= 20);
      if (_hasMore) _page++;
      _isLoading = false;
    });
  }

  String _sortLabel() => _sortOptions
      .firstWhere(
        (s) => s['key'] == _sort,
        orElse: () => _sortOptions[0],
      )['label']!;

  String _pluralReviews(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'отзыв';
    if ([2, 3, 4].contains(m10) && ![12, 13, 14].contains(m100)) {
      return 'отзыва';
    }
    return 'отзывов';
  }

  String _imageUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://xn--80abvyjk6cts.xn--p1ai/$url';
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Сортировка',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ..._sortOptions.map(
              (s) => GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _sort = s['key']!);
                  _loadReviews(refresh: true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: _sort == s['key']
                        ? const Color(0xFFFDF2F5)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        s['label']!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: _sort == s['key']
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _sort == s['key']
                              ? const Color(0xFFDD1847)
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      if (_sort == s['key']) const Spacer(),
                      if (_sort == s['key'])
                        const Icon(
                          Icons.check,
                          color: Color(0xFFDD1847),
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final reviewCount =
        _totalReviews > 0 ? _totalReviews : widget.initialReviewCount;

    final allVideos = <Map<String, String>>[];
    final allPhotos = <String>[];
    for (final review in _reviews) {
      if (review['video'] != null &&
          review['video'].toString().isNotEmpty) {
        allVideos.add({
          'video': review['video'].toString(),
          'preview': (review['video_preview'] ?? '').toString(),
        });
      }
      if (review['photos'] is List) {
        allPhotos.addAll(List<String>.from(review['photos']));
      }
    }

    /// 🔥 AnnotatedRegion перебивает родительский экран и гарантирует,
    /// что иконки статус-бара будут тёмными на светлом фоне.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: EdgeInsets.only(top: topPadding, bottom: 12),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Color(0xFFFF2E6E),
                      size: 22,
                    ),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Оценки и отзывы',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          '$reviewCount ${_pluralReviews(reviewCount)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF0F0F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: (value) => _loadReviews(refresh: true),
                  onChanged: (value) {
                    if (value.isEmpty) _loadReviews(refresh: true);
                  },
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Поиск по отзывам...',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF999999),
                      size: 22,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _loadReviews(refresh: true);
                            },
                            child: const Icon(
                              Icons.close,
                              size: 18,
                              color: Color(0xFF999999),
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _showSortSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _sort != 'newest'
                            ? const Color(0xFFDD1847)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _sort != 'newest'
                              ? const Color(0xFFDD1847)
                              : const Color(0xFFE0E0E0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _sortLabel(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _sort != 'newest'
                                  ? Colors.white
                                  : const Color(0xFF555555),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 16,
                            color: _sort != 'newest'
                                ? Colors.white
                                : const Color(0xFF999999),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() => _onlyWithMedia = !_onlyWithMedia);
                      _loadReviews(refresh: true);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _onlyWithMedia
                            ? const Color(0xFFFDF2F5)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _onlyWithMedia
                              ? const Color(0xFFDD1847)
                              : const Color(0xFFE0E0E0),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: Checkbox(
                              value: _onlyWithMedia,
                              onChanged: (v) {
                                setState(
                                  () => _onlyWithMedia = v ?? false,
                                );
                                _loadReviews(refresh: true);
                              },
                              activeColor: const Color(0xFFDD1847),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Только с фото и видео',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _onlyWithMedia
                                  ? const Color(0xFFDD1847)
                                  : const Color(0xFF555555),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (allVideos.isNotEmpty || allPhotos.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Фото и видео',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          ...allVideos.map(
                            (v) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _buildVideoThumbnail(
                                v['video']!,
                                v['preview'],
                                context,
                              ),
                            ),
                          ),
                          ...allPhotos.map(
                            (photo) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _buildPhotoThumbnail(photo, context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoading && _reviews.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFDD1847),
                      ),
                    )
                  : _reviews.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_border,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Отзывов пока нет',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Color(0xFF999999),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Будьте первым, кто оставит отзыв',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFBBBBBB),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadReviews(refresh: true),
                          color: const Color(0xFFDD1847),
                          child: ListView.builder(
                            controller: _scrollController,
                            physics:
                                const AlwaysScrollableScrollPhysics(),
                            padding:
                                EdgeInsets.only(bottom: 100 + bottomPadding),
                            itemCount:
                                _reviews.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _reviews.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFFDD1847),
                                    ),
                                  ),
                                );
                              }
                              return _buildReviewCard(_reviews[index]);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(
    String videoUrl,
    String? videoPreview,
    BuildContext context,
  ) {
    return GestureDetector(
      onTap: () => _openFullscreenMedia(
        context,
        videoUrl,
        isVideo: true,
        videoPreview: videoPreview,
      ),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(6),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (videoPreview != null && videoPreview.isNotEmpty)
                Image.network(
                  _imageUrl(videoPreview),
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                )
              else
                Container(color: Colors.black),
              const Center(
                child: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(String photo, BuildContext context) {
    return GestureDetector(
      onTap: () =>
          _openFullscreenMedia(context, photo, isVideo: false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          _imageUrl(photo),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  void _openFullscreenMedia(
    BuildContext context,
    String mediaUrl, {
    required bool isVideo,
    String? videoPreview,
  }) {
    final items = <FullscreenMediaItem>[];

    for (final review in _reviews) {
      final userName = _formatUserName(review['user_name']?.toString());
      final rating = review['rating'] ?? 5;
      final photos = review['photos'] is List
          ? List<String>.from(review['photos'])
          : [];
      final video = review['video']?.toString();
      final preview = review['video_preview']?.toString();
      final productImage = review['product_image']?.toString();
      final productName = review['product_name']?.toString();
      final productPriceRaw = review['product_price'];
      final productSalePriceRaw = review['product_sale_price'];
      final productCardPriceRaw = review['product_card_price'];

      final productPrice = productPriceRaw is num
          ? productPriceRaw.toDouble()
          : double.tryParse(productPriceRaw?.toString() ?? '');
      final productSalePrice = productSalePriceRaw is num
          ? productSalePriceRaw.toDouble()
          : double.tryParse(productSalePriceRaw?.toString() ?? '');
      final productCardPrice = productCardPriceRaw is num
          ? productCardPriceRaw.toDouble()
          : double.tryParse(productCardPriceRaw?.toString() ?? '');

      final pros = review['pros']?.toString() ?? '';
      final cons = review['cons']?.toString() ?? '';
      final text = review['text']?.toString() ?? '';

      final commentParts = <String>[];
      if (pros.isNotEmpty) {
        commentParts.add('Достоинства: $pros');
      }
      if (cons.isNotEmpty) {
        commentParts.add('Недостатки: $cons');
      }
      if (text.isNotEmpty) {
        commentParts.add(text);
      }
      final comment = commentParts.join('\n');

      if (video != null && video.isNotEmpty) {
        items.add(FullscreenMediaItem(
          mediaUrl: video,
          isVideo: true,
          videoPreview: preview,
          userName: userName,
          comment: comment,
          rating: rating,
          productImage: productImage,
          productName: productName,
          productPrice: productPrice,
          productSalePrice: productSalePrice,
          productCardPrice: productCardPrice,
        ));
      }

      for (final photo in photos) {
        items.add(FullscreenMediaItem(
          mediaUrl: photo,
          isVideo: false,
          userName: userName,
          comment: comment,
          rating: rating,
          productImage: productImage,
          productName: productName,
          productPrice: productPrice,
          productSalePrice: productSalePrice,
          productCardPrice: productCardPrice,
        ));
      }
    }

    if (items.isEmpty) return;

    int initialIndex = items.indexWhere((item) => item.mediaUrl == mediaUrl);
    if (initialIndex < 0) initialIndex = 0;

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => FullscreenMediaViewer(
          items: items,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final userName = _formatUserName(review['user_name']?.toString());
    final rating = review['rating'] ?? 0;
    final text = review['text']?.toString() ?? '';
    final pros = review['pros']?.toString() ?? '';
    final cons = review['cons']?.toString() ?? '';
    final createdAt = review['created_at']?.toString() ?? '';
    final photos = review['photos'] is List
        ? List<String>.from(review['photos'])
        : [];
    final video = review['video']?.toString();
    final videoPreview = review['video_preview']?.toString();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFF0F0F5),
                radius: 16,
                child: Text(
                  userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF666666),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (createdAt.isNotEmpty)
                      Text(
                        createdAt.length >= 10
                            ? createdAt.substring(0, 10)
                            : createdAt,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF999999),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Text(
                    i < rating ? '★' : '☆',
                    style: TextStyle(
                      fontSize: 16,
                      color: i < rating
                          ? const Color(0xFFFFB800)
                          : const Color(0xFFD0D0D0),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (pros.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildLabeledText('Достоинства', pros),
          ],
          if (cons.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildLabeledText('Недостатки', cons),
          ],
          if (text.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildLabeledText('Комментарий', text),
          ],
          if (video != null || photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (video != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildVideoThumbnail(
                        video,
                        videoPreview,
                        context,
                      ),
                    ),
                  ...photos.map(
                    (photo) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _buildPhotoThumbnail(photo, context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLabeledText(String label, String text) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF999999),
            ),
          ),
          TextSpan(
            text: text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF1A1A1A),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}