// lib/screens/profile/offline_purchases_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/app_logger.dart';
import '../../services/api_service.dart';
import '../../widgets/image_loader.dart';
import 'offline_purchase_detail_screen.dart';
import '../../core/app_colors.dart';
import '../../core/price_formatter.dart';

class OfflinePurchasesScreen extends StatefulWidget {
  const OfflinePurchasesScreen({super.key});

  @override
  State<OfflinePurchasesScreen> createState() =>
      _OfflinePurchasesScreenState();
}

class _OfflinePurchasesScreenState extends State<OfflinePurchasesScreen> {
  static const _logTag = 'OfflinePurchasesScreen';

  List<Map<String, dynamic>> _purchases = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 1;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _loadPurchases();
    _scrollController.addListener(_onScroll);
    _scrollController.addListener(_onScrollForTopButton);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _onScrollForTopButton() {
    final show =
        _scrollController.hasClients && _scrollController.offset > 300;
    if (show != _showScrollToTop) {
      setState(() => _showScrollToTop = show);
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  Future<void> _refresh() async {
    ApiService.invalidateCache(prefix: '/api/offline-purchases/');

    setState(() {
      _purchases = [];
      _page = 1;
      _hasMore = true;
      _isLoading = true;
    });

    await _loadPurchases();
  }

  Future<void> _loadPurchases() async {
    final result = await ApiService.get(
      '/api/offline-purchases/my-list?page=$_page',
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadPurchases(page=$_page) failed: '
            '${result.errorOrNull?.message}',
      );
      setState(() => _isLoading = false);
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      setState(() => _isLoading = false);
      return;
    }

    final purchasesRaw = data['purchases'];
    final purchases = purchasesRaw is List
        ? purchasesRaw
            .whereType<Map>()
            .map((p) => Map<String, dynamic>.from(p))
            .toList()
        : <Map<String, dynamic>>[];

    final pages = data['pages'] ?? 1;

    setState(() {
      _purchases = purchases;
      _hasMore = _page < pages;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;
    _page++;

    final result = await ApiService.get(
      '/api/offline-purchases/my-list?page=$_page',
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadMore(page=$_page) failed: ${result.errorOrNull?.message}',
      );
      _page--;
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      _page--;
      return;
    }

    final purchasesRaw = data['purchases'];
    final purchases = purchasesRaw is List
        ? purchasesRaw
            .whereType<Map>()
            .map((p) => Map<String, dynamic>.from(p))
            .toList()
        : <Map<String, dynamic>>[];

    final pages = data['pages'] ?? 1;

    setState(() {
      _purchases.addAll(purchases);
      _hasMore = _page < pages;
    });
  }

  List<Map<String, dynamic>> _parseItems(dynamic items) {
    if (items == null) return [];
    if (items is List) {
      return items
          .whereType<Map>()
          .map((i) => Map<String, dynamic>.from(i))
          .toList();
    }
    if (items is String) {
      try {
        final decoded = jsonDecode(items);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((i) => Map<String, dynamic>.from(i))
              .toList();
        }
      } catch (_) {
        // Штатный fallback — не удалось распарсить строку.
      }
    }
    return [];
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _pluralItems(int n) {
    final m10 = n % 10;
    final m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'товар';
    if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) return 'товара';
    return 'товаров';
  }

  List<_GroupedPurchases> _groupByMonth(
    List<Map<String, dynamic>> purchases,
  ) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
    ];
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final purchase in purchases) {
      final dateStr = purchase['purchase_date'] ?? '';
      if (dateStr.isEmpty) continue;
      try {
        final date = DateTime.parse(dateStr);
        final key = '${months[date.month - 1]} ${date.year}';
        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(purchase);
      } catch (_) {}
    }

    return grouped.entries
        .map(
          (entry) => _GroupedPurchases(
            header: entry.key,
            purchases: entry.value,
          ),
        )
        .toList();
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
                SizedBox(height: topPadding + 48),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    color: context.colors.brand,
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: context.colors.brand,
                            ),
                          )
                        : _purchases.isEmpty
                            ? Center(
                                child: ListView(
                                  physics:
                                      AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(height: 200),
                                    Text(
                                      '🛒',
                                      style: TextStyle(fontSize: 48),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'У вас пока нет офлайн покупок',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.colors.textMuted,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Покупки в магазине появятся здесь',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: context.colors.textDisabled,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  100,
                                ),
                                itemCount:
                                    _groupByMonth(_purchases).length,
                                itemBuilder: (context, index) {
                                  final group =
                                      _groupByMonth(_purchases)[index];
                                  return _buildMonthGroup(group);
                                },
                              ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(20)),
              child: Container(
                padding: EdgeInsets.only(top: topPadding, bottom: 4),
                color: context.colors.surface,
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
                        'Офлайн покупки',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: bottomPadding > 0 ? bottomPadding + 90 : 106,
            right: 20,
            child: AnimatedOpacity(
              opacity: _showScrollToTop ? 1.0 : 0.0,
              duration: Duration(milliseconds: 200),
              child: AnimatedSlide(
                offset:
                    _showScrollToTop ? Offset.zero : Offset(0, 0.5),
                duration: Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: GestureDetector(
                  onTap: _scrollToTop,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.colors.brand
                          .withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: context.colors.brand
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.keyboard_arrow_up,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthGroup(_GroupedPurchases group) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 8, bottom: 8, left: 4),
          child: Text(
            group.header,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        ...group.purchases.map((purchase) {
          final items = _parseItems(purchase['items']);
          final itemCount = items.length;
          final images = _getImages(items);
          final shopName = purchase['shop_name'] ?? 'Магазин';
          final total = _parseDouble(purchase['total']);
          final date = purchase['purchase_date'] ?? '';
          final formattedDate = _formatDate(date);
          final checkId = purchase['check_id'] ?? '';

          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OfflinePurchaseDetailScreen(
                    purchaseId: purchase['id'],
                  ),
                ),
              );
            },
            child: Container(
              margin: EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: context.colors.brandLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.shopping_cart_outlined,
                      color: context.colors.brand,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Чек №$checkId',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: context.colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          '$formattedDate · $itemCount ${_pluralItems(itemCount)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (images.isNotEmpty)
                    SizedBox(
                      width: 60,
                      height: 78,
                      child: Stack(
                        children: images.asMap().entries.map((entry) {
                          final i = entry.key;
                          final img = entry.value;
                          final isSingle = images.length == 1;
                          return Positioned(
                            left: isSingle ? 5.0 : (i == 0 ? 0.0 : null),
                            right: isSingle ? 5.0 : (i == 1 ? 0.0 : null),
                            top: isSingle ? 5.0 : (i == 0 ? 5.0 : 0.0),
                            child: Transform.rotate(
                              angle: isSingle
                                  ? 0
                                  : (i == 0 ? -0.09 : 0.10),
                              child: Container(
                                width: 50,
                                height: 68,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: context.colors.surfaceAlt,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: i == 1 ? 0.12 : 0.08,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ImageLoader(
                                  imageUrl: img,
                                  width: 50,
                                  height: 68,
                                  borderRadius: 8,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      context.formatPrice(
                        total,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: context.colors.brand,
                      ),
                      SizedBox(height: 2),
                      Text(
                        shopName,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  List<String> _getImages(List<Map<String, dynamic>> items) {
    final images = <String>[];
    for (final item in items) {
      final img = item['main_image_card'] ?? item['main_image'];
      if (img != null &&
          img.toString().isNotEmpty &&
          images.length < 2) {
        images.add(img.toString().replaceAll('main.webp', 'main_card.webp'));
      }
    }
    return images;
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}.'
          '${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _GroupedPurchases {
  final String header;
  final List<Map<String, dynamic>> purchases;

  const _GroupedPurchases({
    required this.header,
    required this.purchases,
  });
}