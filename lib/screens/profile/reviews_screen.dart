// lib/screens/profile/reviews_screen.dart
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/app_logger.dart';
import '../../services/api_service.dart';
import '../../widgets/rate_product_sheet.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../main_shell.dart';
import '../product/product_detail_screen.dart';
import '../../core/app_colors.dart';

class ReviewsScreen extends StatefulWidget {
  final int initialTab;

  const ReviewsScreen({super.key, this.initialTab = 0});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen>
    with SingleTickerProviderStateMixin {
  static const _logTag = 'ReviewsScreen';

  late TabController _tabController;
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _toRate = [];
  bool _isLoading = true;

  final ScrollController _reviewsScrollController = ScrollController();
  final ScrollController _toRateScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _tabController.addListener(_onTabChanged);
    _loadData();
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _reviewsScrollController.dispose();
    _toRateScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final result = await ApiService.get(
      '/api/reviews/my',
      forceRefresh: true,
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadData failed: ${result.errorOrNull?.message}',
      );
      setState(() => _isLoading = false);
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      setState(() => _isLoading = false);
      return;
    }

    final reviewsRaw = data['reviews'];
    final toRateRaw = data['to_rate'];

    setState(() {
      _reviews = reviewsRaw is List
          ? reviewsRaw
              .whereType<Map>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList()
          : <Map<String, dynamic>>[];
      _toRate = toRateRaw is List
          ? toRateRaw
              .whereType<Map>()
              .map((r) => Map<String, dynamic>.from(r))
              .toList()
          : <Map<String, dynamic>>[];
      _isLoading = false;
    });
  }

  String _imageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return 'https://xn--80abvyjk6cts.xn--p1ai/$url';
  }

  ScrollController _getCurrentScrollController() {
    switch (_tabController.index) {
      case 0:
        return _reviewsScrollController;
      case 1:
        return _toRateScrollController;
      default:
        return _reviewsScrollController;
    }
  }

  Widget _buildToRateTabWidget() {
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'Ждут оценки',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          TextSpan(
            text: ' ${_toRate.length}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: context.colors.surfaceAlt,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: topPadding + 48 + 46),
                SizedBox(height: 12),
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: context.colors.brand,
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildReviewsTab(),
                            _buildToRateTab(),
                            const _QuestionsTab(),
                          ],
                        ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PhysicalModel(
              color: context.colors.surface,
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              elevation: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: topPadding, bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: context.colors.error,
                            size: 22,
                          ),
                          onPressed: () => Navigator.pop(context),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Отзывы и вопросы',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(width: 48),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.transparent,
                          width: 0,
                        ),
                      ),
                    ),
                    indicatorWeight: 0,
                    dividerColor: Colors.transparent,
                    labelColor: context.colors.textPrimary,
                    unselectedLabelColor: context.colors.textMuted,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(text: 'Отзывы ${_reviews.length}'),
                      Tab(child: _buildToRateTabWidget()),
                      const Tab(text: 'Вопросы'),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: bottomPadding + 20,
            right: 40,
            child: ScrollToTopButton(
              key: ValueKey('scroll_to_top_${_tabController.index}'),
              scrollController: _getCurrentScrollController(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_reviews.isEmpty) {
      return Center(
        child: Text(
          'У вас пока нет отзывов',
          style: TextStyle(color: context.colors.textMuted),
        ),
      );
    }
    return RefreshIndicator(
      color: context.colors.brand,
      onRefresh: _loadData,
      child: ListView.builder(
        controller: _reviewsScrollController,
        padding: EdgeInsets.fromLTRB(12, 0, 12, 100),
        itemCount: _reviews.length,
        itemBuilder: (context, index) => _buildReviewCard(_reviews[index]),
      ),
    );
  }

  Widget _buildToRateTab() {
    if (_toRate.isEmpty) {
      return Center(
        child: Text(
          'Нет товаров для оценки',
          style: TextStyle(color: context.colors.textMuted),
        ),
      );
    }
    return RefreshIndicator(
      color: context.colors.brand,
      onRefresh: _loadData,
      child: ListView.builder(
        controller: _toRateScrollController,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
        itemCount: _toRate.length,
        itemBuilder: (context, index) => _buildToRateCard(_toRate[index]),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final brand = review['brand'] ?? 'Без бренда';
    final name = review['name'] ?? '';
    final date = review['created_at'] ?? '';
    final rating = review['rating'] ?? 0;
    final image = review['main_image_card'] ?? review['main_image'];
    final slug = review['product_slug'] ?? review['slug'] ?? '';
    final bonusAmount = review['bonus_amount'] ?? 0;
    final reviewId = review['id'] ?? 0;
    final status = review['status'] ?? 'pending';

    final priceValue = review['price'] ?? 0;
    final price = priceValue is num
        ? priceValue.toDouble()
        : double.tryParse(priceValue.toString()) ?? 0;

    String statusText;
    Color statusColor;
    switch (status) {
      case 'approved':
        statusText = 'Опубликован';
        statusColor = const Color(0xFF2e7d32);
        break;
      case 'pending':
        statusText = 'На проверке';
        statusColor = const Color(0xFFf59e0b);
        break;
      case 'rejected':
        statusText = 'Нарушает правила';
        statusColor = Color(0xFFc62828);
        break;
      default:
        statusText = 'На проверке';
        statusColor = Color(0xFFf59e0b);
    }

    return GestureDetector(
      onTap: slug.isNotEmpty
          ? () {
              MainShell.push(context, ProductDetailScreen(slug: slug));
            }
          : null,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 96,
                height: 128,
                child: image != null
                    ? CachedNetworkImage(
                        imageUrl: _imageUrl(image),
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: context.colors.surfaceAlt),
                        errorWidget: (_, _, _) =>
                            Container(color: context.colors.surfaceAlt),
                      )
                    : Container(color: context.colors.surfaceAlt),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          brand,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (bonusAmount > 0) ...[
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.brandLight,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: context.colors.brand
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    'assets/icons/bonus-logo.svg',
                                    width: 14,
                                    height: 14,
                                    placeholderBuilder: (context) =>
                                        Text(
                                      '🎁',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '+$bonusAmount',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: context.colors.brand,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                          GestureDetector(
                            onTap: () {
                              Map<String, dynamic> editItem;

                              if (price < 300 && price > 0) {
                                editItem = <String, dynamic>{
                                  ...review,
                                  'id': review['product_id'] ?? 0,
                                  'name': review['name'] ?? '',
                                  'brand': review['brand'] ?? 'Без бренда',
                                  'main_image': review['main_image'] ?? '',
                                  'order_date': review['created_at'] ?? '',
                                  'price': price,
                                  'max_bonus': 10,
                                  'review_id': reviewId,
                                  'existing_rating': rating,
                                  'existing_text': review['text'] ?? '',
                                  'existing_pros': review['pros'] ?? '',
                                  'existing_cons': review['cons'] ?? '',
                                  'existing_photos': review['images'] is List
                                      ? List<String>.from(review['images'])
                                      : [],
                                  'existing_video': review['video'],
                                  'is_edit': true,
                                  'comment_bonus': 0,
                                  'photo_bonus': 5,
                                  'video_bonus': 5,
                                };
                              } else {
                                final maxBonus = price > 0
                                    ? min(200, (price * 0.05).floor())
                                    : 0;
                                final commentBonus = price >= 300
                                    ? min(
                                        50,
                                        max(5, (price * 0.01).floor()),
                                      )
                                    : 0;
                                final photoBonus = price > 0
                                    ? min(
                                        50,
                                        max(5, (price * 0.01).floor()),
                                      )
                                    : 0;
                                final videoBonus = price > 0
                                    ? min(
                                        100,
                                        max(5, (price * 0.02).floor()),
                                      )
                                    : 0;

                                editItem = <String, dynamic>{
                                  ...review,
                                  'id': review['product_id'] ?? 0,
                                  'name': review['name'] ?? '',
                                  'brand': review['brand'] ?? 'Без бренда',
                                  'main_image': review['main_image'] ?? '',
                                  'order_date': review['created_at'] ?? '',
                                  'price': price,
                                  'max_bonus': maxBonus,
                                  'review_id': reviewId,
                                  'existing_rating': rating,
                                  'existing_text': review['text'] ?? '',
                                  'existing_pros': review['pros'] ?? '',
                                  'existing_cons': review['cons'] ?? '',
                                  'existing_photos': review['images'] is List
                                      ? List<String>.from(review['images'])
                                      : [],
                                  'existing_video': review['video'],
                                  'is_edit': true,
                                  'comment_bonus': commentBonus,
                                  'photo_bonus': photoBonus,
                                  'video_bonus': videoBonus,
                                };
                              }

                              RateProductSheet.show(
                                context,
                                editItem,
                                _loadData,
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: context.colors.surfaceAlt,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: context.colors.border,
                                ),
                              ),
                              child: Text(
                                'Править',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    date.length >= 10 ? date.substring(0, 10) : date,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMuted,
                    ),
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      ...List.generate(
                        5,
                        (i) => Padding(
                          padding: EdgeInsets.only(right: 2),
                          child: Icon(
                            Icons.star,
                            size: 28,
                            color: i < rating
                                ? context.colors.warning
                                : context.colors.border,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToRateCard(Map<String, dynamic> item) {
    final brand = item['brand'] ?? 'Без бренда';
    final name = item['name'] ?? '';
    final date = item['order_date'] ?? '';
    final image = item['main_image_card'] ?? item['main_image'];
    final slug = item['product_slug'] ?? item['slug'] ?? '';

    final maxBonus = item['max_bonus'] ?? 0;
    final commentBonus = item['comment_bonus'] ?? 0;
    final photoBonus = item['photo_bonus'] ?? 0;
    final videoBonus = item['video_bonus'] ?? 0;

    final itemWithBonuses = <String, dynamic>{
      ...item,
      'comment_bonus': commentBonus,
      'photo_bonus': photoBonus,
      'video_bonus': videoBonus,
    };

    return GestureDetector(
      onTap: slug.isNotEmpty
          ? () {
              MainShell.push(context, ProductDetailScreen(slug: slug));
            }
          : null,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 96,
                height: 128,
                child: image != null
                    ? CachedNetworkImage(
                        imageUrl: _imageUrl(image),
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: context.colors.surfaceAlt),
                        errorWidget: (_, _, _) =>
                            Container(color: context.colors.surfaceAlt),
                      )
                    : Container(color: context.colors.surfaceAlt),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          brand,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (maxBonus > 0) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.brandLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: context.colors.brand
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SvgPicture.asset(
                                'assets/icons/bonus-logo.svg',
                                width: 16,
                                height: 16,
                                placeholderBuilder: (context) =>
                                    Text(
                                  '🎁',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                '$maxBonus',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: context.colors.brand,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Получен: ${date.length >= 10 ? date.substring(0, 10) : 'Офлайн-покупка'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () async {
                      final result = await RateProductSheet.show(
                        context,
                        itemWithBonuses,
                        _loadData,
                      );
                      if (result == true) {
                        _loadData();
                      }
                    },
                    child: Row(
                      children: List.generate(
                        5,
                        (i) => Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.star,
                            size: 32,
                            color: context.colors.border,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionsTab extends StatefulWidget {
  const _QuestionsTab();

  @override
  State<_QuestionsTab> createState() => _QuestionsTabState();
}

class _QuestionsTabState extends State<_QuestionsTab> {
  static const _logTag = 'QuestionsTab';

  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = true;
  String _filter = 'all';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);

    final params = <String, String>{'filter': _filter};
    if (_search.isNotEmpty) params['search'] = _search;
    final uri = Uri.https('', '/api/questions/my', params);

    final result = await ApiService.get('${uri.path}?${uri.query}');

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadQuestions failed: ${result.errorOrNull?.message}',
      );
      setState(() => _isLoading = false);
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      setState(() => _isLoading = false);
      return;
    }

    final questionsRaw = data['questions'];

    setState(() {
      _questions = questionsRaw is List
          ? questionsRaw
              .whereType<Map>()
              .map((q) => Map<String, dynamic>.from(q))
              .toList()
          : <Map<String, dynamic>>[];
      _isLoading = false;
    });
  }

  String _imageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return 'https://xn--80abvyjk6cts.xn--p1ai/$url';
  }

  void _showQuestionDetail(Map<String, dynamic> q) {
    final brand = q['brand'] ?? 'Без бренда';
    final name = q['product_name'] ?? '';
    final text = q['text'] ?? '';
    final answer = q['answer'] ?? '';
    final date = q['created_at'] ?? '';
    final image = q['main_image_card'] ?? q['main_image'];
    final slug = q['product_slug'] ?? '';
    final statusClass = answer.toString().isNotEmpty ? 'answered' : 'waiting';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border(
                    bottom: BorderSide(color: context.colors.surfaceAlt),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: _imageUrl(image),
                        width: 44,
                        height: 58,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: context.colors.surfaceAlt),
                        errorWidget: (_, _, _) =>
                            Container(color: context.colors.surfaceAlt),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            brand,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textMuted,
                            ),
                          ),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.close,
                          size: 18,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: statusClass == 'answered'
                              ? Color(0xFFE8F5E9)
                              : context.colors.brandLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              statusClass == 'answered'
                                  ? 'Ответ видят все'
                                  : 'Ждёт ответа',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: statusClass == 'answered'
                                    ? context.colors.success
                                    : context.colors.brand,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              statusClass == 'answered'
                                  ? 'Другие покупатели смогут прочитать его в карточке товара'
                                  : 'Продавец получит ваш вопрос и постарается ответить в течение 3 дней',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.colors.textMuted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        date.length >= 10 ? date.substring(0, 10) : date,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.colors.textMuted,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 16,
                          color: context.colors.textPrimary,
                          height: 1.5,
                        ),
                      ),
                      if (answer.toString().isNotEmpty) ...[
                        SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.colors.surfaceAlt,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ответ магазина',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.success,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                answer,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: context.colors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 12 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border(
                    top: BorderSide(color: context.colors.surfaceAlt),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (slug.isNotEmpty) {
                        MainShell.push(
                          context,
                          ProductDetailScreen(slug: slug),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.brand,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Перейти к товару',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: _showFilterMenu,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _filter == 'all'
                            ? 'Все вопросы'
                            : _filter == 'with_answer'
                                ? 'С ответом'
                                : 'Без ответа',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 18,
                        color: context.colors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: TextField(
                    onSubmitted: (value) {
                      _search = value;
                      _loadQuestions();
                    },
                    decoration: InputDecoration(
                      hintText: 'Поиск по товарам...',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: context.colors.textMuted,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: context.colors.brand,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: context.colors.brand,
                  ),
                )
              : _questions.isEmpty
                  ? Center(
                      child: Text(
                        'Вопросы не найдены',
                        style: TextStyle(color: context.colors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                      itemCount: _questions.length,
                      itemBuilder: (context, index) =>
                          _buildQuestionCard(_questions[index]),
                    ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q) {
    final hasAnswer = q['answer'] != null;
    final statusClass = hasAnswer ? 'answered' : 'waiting';
    final statusLabel = hasAnswer ? 'Отвечен' : 'Ждёт ответа';
    final name = q['product_name'] ?? '';
    final text = q['text'] ?? '';
    final answer = q['answer'] ?? '';
    final date = q['created_at'] ?? '';
    final image = q['main_image_card'] ?? q['main_image'];

    return GestureDetector(
      onTap: () => _showQuestionDetail(q),
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 74,
                child: image != null
                    ? CachedNetworkImage(
                        imageUrl: _imageUrl(image),
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            Container(color: context.colors.surfaceAlt),
                        errorWidget: (_, _, _) =>
                            Container(color: context.colors.surfaceAlt),
                      )
                    : Container(color: context.colors.surfaceAlt),
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusClass == 'answered'
                          ? Color(0xFFE8F5E9)
                          : context.colors.brandLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusClass == 'answered'
                            ? context.colors.success
                            : context.colors.brand,
                      ),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    text,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.colors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  if (answer.toString().isNotEmpty) ...[
                    SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ответ магазина',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.colors.success,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            answer,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 8),
                  Text(
                    date.length >= 10 ? date.substring(0, 10) : date,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterMenu() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
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
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildFilterOption('Все вопросы', 'all'),
            _buildFilterOption('С ответом', 'with_answer'),
            _buildFilterOption('Без ответа', 'without_answer'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, String value) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        setState(() => _filter = value);
        _loadQuestions();
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: _filter == value
              ? context.colors.brandLight
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: _filter == value
                    ? FontWeight.w600
                    : FontWeight.w400,
                color: _filter == value
                    ? context.colors.brand
                    : context.colors.textPrimary,
              ),
            ),
            if (_filter == value) Spacer(),
            if (_filter == value)
              Icon(
                Icons.check,
                color: context.colors.brand,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}