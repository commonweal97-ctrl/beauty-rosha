// lib/screens/checkout/thank_you_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_logger.dart';
import '../../models/product.dart';
import '../../services/analytics_service.dart';
import '../../services/api_service.dart';
import '../../services/crashlytics_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/product_card.dart';
import '../main_shell.dart';
import '../profile/orders_screen.dart';
import '../../core/app_colors.dart';

class ThankYouScreen extends StatefulWidget {
  final int orderId;

  const ThankYouScreen({super.key, required this.orderId});

  @override
  State<ThankYouScreen> createState() => _ThankYouScreenState();
}

class _ThankYouScreenState extends State<ThankYouScreen> {
  static const _logTag = 'ThankYouScreen';

  Map<String, dynamic>? _order;
  List<String> _orderImages = [];
  List<Product> _upsells = [];
  List<Product> _recommendations = [];
  bool _loading = true;
  bool _upsellsLoading = false;
  bool _recsLoading = false;
  bool _upsellsEnded = false;
  int _upsellsPage = 1;
  int _recsPage = 1;
  bool _hasMoreUpsells = true;
  bool _hasMoreRecommendations = true;
  bool _loadingMore = false;
  bool _showContent = false;
  final ScrollController _scrollController = ScrollController();
  double _lastOffset = 0.0;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();

    CrashlyticsService.log(
      'ThankYouScreen shown: order ${widget.orderId}',
    );

    _loadOrderData();
    _startStatusPolling();
    _scrollController.addListener(() {
      final newOffset = _scrollController.offset;
      if ((newOffset - _lastOffset).abs() > 0.5) {
        _lastOffset = newOffset;
        setState(() {});
      }
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 400) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startStatusPolling() {
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_order != null && _order!['payment_status'] != 'paid') {
        await _refreshOrderStatus();
      } else {
        _statusTimer?.cancel();
      }
    });
  }

  Future<void> _refreshOrderStatus() async {
    final result = await ApiService.get(
      '/api/orders/detail?order_id=${widget.orderId}',
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'refreshOrderStatus(${widget.orderId}) failed: '
            '${result.errorOrNull?.message}',
      );
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! List || data.isEmpty) return;

    final first = data.first;
    if (first is! Map) return;

    final newStatus = Map<String, dynamic>.from(first);

    if (newStatus['payment_status'] != _order?['payment_status']) {
      await CrashlyticsService.log(
        'Order ${widget.orderId} payment status changed: '
        '${_order?['payment_status']} -> ${newStatus['payment_status']}',
      );

      if (!mounted) return;
      setState(() => _order = newStatus);
    }
  }

  Future<void> _onRefresh() async {
    _upsellsPage = 1;
    _hasMoreUpsells = true;
    _upsellsEnded = false;
    _upsells = [];
    _recsPage = 1;
    _hasMoreRecommendations = true;
    _recommendations = [];
    await _loadOrderData();
  }

  List<String> _extractProductIds(List items) {
    return items
        .map((i) => (i is Map ? i['product_id']?.toString() : null) ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
  }

  void _extractImages(List items) {
    _orderImages = items
        .map((item) {
          if (item is! Map) return null;
          final img = item['main_image']?.toString() ?? '';
          if (img.isEmpty) return null;
          return img.startsWith('http')
              ? img
              : 'https://xn--80abvyjk6cts.xn--p1ai/$img';
        })
        .whereType<String>()
        .toSet()
        .toList();
  }

  Future<void> _loadOrderData() async {
    final result = await ApiService.get(
      '/api/orders/detail?order_id=${widget.orderId}',
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadOrderData(${widget.orderId}) failed: '
            '${result.errorOrNull?.message}',
      );
    } else {
      final data = result.valueOrNull?['data'];
      if (data is List && data.isNotEmpty) {
        final first = data.first;
        if (first is Map) {
          _order = Map<String, dynamic>.from(first);
          _extractImages(data);

          final totalRaw = _order?['total'];
          final double total;
          if (totalRaw is num) {
            total = totalRaw.toDouble();
          } else if (totalRaw is String) {
            total = double.tryParse(totalRaw) ?? 0;
          } else {
            total = 0;
          }

          await CrashlyticsService.log(
            'Order ${widget.orderId} loaded: total $total, '
            'payment ${_order?['payment_status']}',
          );

          AnalyticsService.logPurchase(widget.orderId.toString(), total);

          final productIds = _extractProductIds(data);
          if (productIds.isNotEmpty) {
            await _loadUpsells(productIds);
          } else {
            _upsellsEnded = true;
            await _loadRecommendations();
          }
        }
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _showContent = true);
    });
  }

  Future<void> _loadUpsells(List<String> productIds) async {
    setState(() => _upsellsLoading = true);

    await CrashlyticsService.log(
      'Loading upsells for order ${widget.orderId}: '
      '${productIds.length} products',
    );

    final products = await _loadProducts(
      '/api/products/upsells'
      '?product_ids=${productIds.join(',')}&limit=12&page=1',
    );

    if (products.isEmpty) {
      _upsellsEnded = true;
      _hasMoreUpsells = false;
      await _loadRecommendations();
    }

    if (!mounted) return;
    setState(() {
      _upsells = products;
      _upsellsLoading = false;
    });
  }

  Future<void> _loadRecommendations() async {
    if (_recsLoading) return;
    setState(() => _recsLoading = true);
    _recsPage = 1;

    await CrashlyticsService.log(
      'Loading recommendations for order ${widget.orderId}',
    );

    final products = await _loadProducts(
      '/api/recommendations/user?page=1&limit=12',
    );

    if (!mounted) return;
    setState(() {
      _recommendations = products;
      _recsLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);

    try {
      if (!_upsellsEnded && _hasMoreUpsells) {
        _upsellsPage++;
        final items = _order?['items'];
        final itemsList = items is List ? items : const [];
        final productIds = _extractProductIds(itemsList);

        final products = await _loadProducts(
          '/api/products/upsells'
          '?product_ids=${productIds.join(',')}&limit=12&page=$_upsellsPage',
        );

        if (products.isEmpty || products.length < 12) {
          _upsellsEnded = true;
          _hasMoreUpsells = false;
          await _loadRecommendations();
        } else if (mounted) {
          setState(() => _upsells.addAll(products));
        }
      } else if (_hasMoreRecommendations) {
        _recsPage++;
        final products = await _loadProducts(
          '/api/recommendations/user?page=$_recsPage&limit=12',
        );

        if (products.isEmpty) {
          _hasMoreRecommendations = false;
        } else if (mounted) {
          setState(() => _recommendations.addAll(products));
        }
      }
    } catch (e) {
      AppLogger.warning(_logTag, 'loadMore failed', e);
    }

    if (mounted) setState(() => _loadingMore = false);
  }

  Future<List<Product>> _loadProducts(String url) async {
    final result = await ApiService.get(url);

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadProducts("$url") failed: ${result.errorOrNull?.message}',
      );
      return [];
    }

    final data = result.valueOrNull?['data'];

    List<dynamic> productsRaw = const [];
    if (data is Map && data['products'] is List) {
      productsRaw = data['products'] as List;
    } else if (data is List) {
      productsRaw = data;
    }

    return productsRaw
        .whereType<Map>()
        .map((p) => Product.fromJson(Map<String, dynamic>.from(p)))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset.clamp(0.0, 100.0)
        : 0.0;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final totalHeaderHeight = statusBarHeight + 56.0 + 30;

    if (_loading) {
      return Scaffold(
        backgroundColor: context.colors.surfaceAlt,
        body: Stack(
          children: [
            SafeArea(child: _buildSkeleton()),
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppHeader(scrollOffset: 0),
            ),
          ],
        ),
      );
    }

    final paymentMethod = _order?['payment_method'] ?? '';
    final paymentStatus = _order?['payment_status'] ?? '';

    final isReallyPaid = paymentStatus == 'paid';
    final isPodeli = paymentMethod == 'podeli';

    String titleText;
    String subtitleText;
    Color iconBgColor;
    IconData iconData;

    if (isReallyPaid) {
      titleText = 'Успешно оплачен';
      subtitleText = 'Ваш заказ успешно оплачен и уже обрабатывается';
      iconBgColor = const Color(0xFFDCFCE7);
      iconData = Icons.check;
    } else if (isPodeli) {
      titleText = 'Ожидание оплаты';
      subtitleText =
          'Подтверждаем оплату через Подели. Это займёт несколько секунд.';
      iconBgColor = const Color(0xFFFFF3E0);
      iconData = Icons.hourglass_top;
    } else if (paymentMethod == 'card') {
      titleText = 'Ожидание оплаты';
      subtitleText =
          'Подтверждаем оплату картой. Это займёт несколько секунд.';
      iconBgColor = Color(0xFFFFF3E0);
      iconData = Icons.hourglass_top;
    } else {
      titleText = 'Заказ принят';
      subtitleText = 'Ожидайте подтверждения, оплата при получении';
      iconBgColor = Color(0xFFE3F2FD);
      iconData = Icons.receipt_long;
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Color(0xFFc1163d),
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.colors.surfaceAlt,
        body: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(top: totalHeaderHeight),
              child: RefreshIndicator(
                color: context.colors.brand,
                onRefresh: _onRefresh,
                child: ListView(
                  controller: _scrollController,
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(top: 20, bottom: 120),
                  children: [
                    _buildThankYouCard(
                      titleText,
                      subtitleText,
                      iconBgColor,
                      iconData,
                    ),
                    if (_upsellsLoading && _upsells.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: context.colors.brand,
                          ),
                        ),
                      ),
                    if (_upsells.isNotEmpty) ...[
                      SizedBox(height: 32),
                      _buildSectionHeader('С этим товаром покупают'),
                      _buildProductGrid(_upsells),
                    ],
                    if (_recsLoading && _recommendations.isEmpty)
                      Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: context.colors.brand,
                          ),
                        ),
                      ),
                    if (_recommendations.isNotEmpty) ...[
                      SizedBox(height: 32),
                      _buildSectionHeader('Также будут интересны'),
                      _buildProductGrid(_recommendations),
                    ],
                    if (_loadingMore)
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: context.colors.brand,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppHeader(scrollOffset: scrollOffset),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(top: 100),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16),
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 200,
                        height: 28,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 18,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThankYouCard(
    String titleText,
    String subtitleText,
    Color iconBgColor,
    IconData iconData,
  ) {
    return AnimatedOpacity(
      opacity: _showContent ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    iconData,
                    color: Color(0xFF15803D),
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitleText,
                        style: TextStyle(
                          fontSize: 15,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_orderImages.isNotEmpty) ...[
              SizedBox(height: 16),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _orderImages.length,
                  separatorBuilder: (_, _) => SizedBox(width: 8),
                  itemBuilder: (_, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 60,
                      height: 80,
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Image.network(
                        _orderImages[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            Container(color: context.colors.surfaceAlt),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.of(context).pop();
                MainShell.popToRootAndSwitchTab(context, 3);
                MainShell.push(context, OrdersScreen());
              },
              child: Text(
                'Следите за статусом и доставкой в заказах →',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.colors.brand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildProductGrid(List<Product> products) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.54,
          crossAxisSpacing: 1,
          mainAxisSpacing: 1,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) =>
            ProductCard(product: products[index]),
      ),
    );
  }
}