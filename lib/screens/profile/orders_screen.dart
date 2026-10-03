// lib/screens/profile/orders_screen.dart
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_logger.dart';
import '../../providers/order_refresh_provider.dart';
import '../../services/orders_service.dart';
import '../../widgets/scroll_to_top_button.dart';
import 'order_detail_screen.dart';
import '../../core/app_colors.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const _logTag = 'OrdersScreen';

  List<_GroupedOrders> _groupedOrders = [];
  bool _isLoading = true;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadOrders();
    context.read<OrderRefreshProvider>().addListener(_onOrderChanged);
  }

  @override
  void dispose() {
    try {
      context.read<OrderRefreshProvider>().removeListener(_onOrderChanged);
    } catch (_) {}
    _scrollController.dispose();
    super.dispose();
  }

  void _onOrderChanged() {
    _loadOrders(forceRefresh: true);
  }

  Future<void> _loadOrders({bool forceRefresh = false}) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final result = await OrdersService.loadOrders(
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;

      final grouped = _groupByMonth(result.data);

      setState(() {
        _groupedOrders = grouped;
        _isLoading = false;
      });
    } catch (e, st) {
      AppLogger.error(_logTag, 'loadOrders failed', e, st);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (_groupedOrders.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось загрузить заказы')),
        );
      }
    }
  }

  String _getStatusText(Map<String, dynamic> order) {
    final status = order['status'] ?? '';
    final delivery = order['delivery_method'] ?? '';

    switch (status) {
      case 'pending':
        return 'Черновик';
      case 'awaiting_payment':
        return 'Ожидает оплаты';
      case 'cancelled':
        return 'Отменён';
      case 'returned':
        return 'Возвращён';
      case 'completed':
        return 'Уже доставили';
      case 'processing':
        return delivery == 'pickup-store'
            ? 'Готовим к самовывозу'
            : 'Собираем ваш заказ';
      case 'shipping':
        return 'Доставляется';
      case 'ready_pickup':
        return delivery == 'pickup-store'
            ? 'Готов к получению'
            : 'Прибыл в пункт выдачи';
      default:
        return 'В обработке';
    }
  }

  Color _getStatusColor(Map<String, dynamic> order) {
    final status = order['status'] ?? '';
    final payment = order['payment_status'] ?? '';

    if (status == 'awaiting_payment') return const Color(0xFF856404);
    if (status == 'cancelled') return const Color(0xFFB0B0B0);
    if (payment == 'paid') return const Color(0xFF155724);
    return const Color(0xFF004085);
  }

  String _getDeliveryText(Map<String, dynamic> order) {
    final method = order['delivery_method'] ?? '';
    switch (method) {
      case 'pickup-store':
        return 'Самовывоз: пр. Станке Димитрова, 65';
      case 'courier':
        return 'Курьерская доставка';
      case 'pickup-point':
        final deliveryData = order['delivery_data'];
        Map<String, dynamic> data = {};
        if (deliveryData is String) {
          try {
            data = jsonDecode(deliveryData);
          } catch (_) {
            // Не удалось распарсить — оставляем пустым.
          }
        } else if (deliveryData is Map) {
          data = Map<String, dynamic>.from(deliveryData);
        }
        final pointAddress = data['point_address'] ?? '';
        if (pointAddress is String && pointAddress.isNotEmpty) {
          return pointAddress;
        }
        return 'Пункт выдачи';
      default:
        return '';
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
        'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
      ];
      return '${date.day} ${months[date.month - 1]}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  List<_GroupedOrders> _groupByMonth(
    List<Map<String, dynamic>> orders,
  ) {
    const months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
    ];
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final order in orders) {
      final dateStr = order['created_at'] ?? '';
      if (dateStr.isEmpty) continue;
      try {
        final date = DateTime.parse(dateStr);
        final key = '${months[date.month - 1]} ${date.year}';
        grouped.putIfAbsent(key, () => []);
        grouped[key]!.add(order);
      } catch (_) {}
    }

    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) {
        final aParts = a.key.split(' ');
        final bParts = b.key.split(' ');
        final aYear = int.tryParse(aParts.last) ?? 0;
        final bYear = int.tryParse(bParts.last) ?? 0;
        final aMonth = months.indexOf(aParts.first);
        final bMonth = months.indexOf(bParts.first);

        if (aYear != bYear) return bYear.compareTo(aYear);
        return bMonth.compareTo(aMonth);
      });

    return sortedEntries
        .map((entry) => _GroupedOrders(
              header: entry.key,
              orders: entry.value,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              Theme.of(context).brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
          statusBarBrightness:
              Theme.of(context).brightness == Brightness.dark
                  ? Brightness.dark
                  : Brightness.light,
        ),
      child: Scaffold(
        backgroundColor: context.colors.surfaceAlt,
        body: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  SizedBox(height: topPadding + 48),
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: context.colors.brand,
                            ),
                          )
                        : RefreshIndicator(
                            color: context.colors.brand,
                            onRefresh: () =>
                                _loadOrders(forceRefresh: true),
                            child: _groupedOrders.isEmpty
                                ? ListView(
                                    children: [_buildEmptyState()],
                                  )
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      100,
                                    ),
                                    itemCount: _groupedOrders.length,
                                    itemBuilder: (context, index) =>
                                        _buildMonthGroup(
                                      _groupedOrders[index],
                                    ),
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
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
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
                          'Заказы',
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
              bottom: bottomPadding + 20,
              right: 40,
              child: ScrollToTopButton(
                scrollController: _scrollController,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📦', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text(
              'У вас пока нет заказов',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Перейдите в каталог, чтобы выбрать товары',
              style: TextStyle(
                fontSize: 14,
                color: context.colors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthGroup(_GroupedOrders group) {
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
        ...group.orders.map((order) => _buildOrderCard(order)),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final statusText = _getStatusText(order);
    final statusColor = _getStatusColor(order);
    final deliveryText = _getDeliveryText(order);
    final dateText = _formatDate(order['created_at'] ?? '');
    final timeText = _formatTime(order['created_at'] ?? '');
    // 🔥 Первая картинка заказа — заполняется OrdersService (batch-details, main_image_thumb)
    final image = order['_first_image'] as String?;

    final deliveryData = order['delivery_data'];
    Map<String, dynamic> data = {};
    if (deliveryData is String) {
      try {
        data = jsonDecode(deliveryData);
      } catch (_) {
        // Не удалось распарсить — оставляем пустым.
      }
    } else if (deliveryData is Map) {
      data = Map<String, dynamic>.from(deliveryData);
    }
    final provider = data['provider'] ?? '';
    final providerIcons = {
      'cdek': 'assets/images/CDEKLogo.png',
      'yandex': 'assets/images/YandexLogo.png',
      'fivepost': 'assets/images/5postlogo.png',
      'russian_post': 'assets/images/Pochalogo.png',
      'ozon': 'assets/images/OzonLogo.png',
    };
    final iconPath = providerIcons[provider];

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                OrderDetailScreen(orderId: order['id'] as int),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                  if (deliveryText.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Row(
                      children: [
                        if (iconPath != null)
                          Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: Image.asset(
                              iconPath,
                              width: 16,
                              height: 16,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            deliveryText,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 4),
                  Text(
                    '#${order['id']} от $dateText $timeText',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
            if (image != null) ...[
              SizedBox(width: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 48,
                  height: 64,
                  decoration: BoxDecoration(
                    border: Border.all(color: context.colors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: image,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Container(color: context.colors.surfaceAlt),
                    errorWidget: (_, _, _) =>
                        Container(color: context.colors.surfaceAlt),
                  ),
                ),
              ),
            ],
            SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              color: context.colors.border,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupedOrders {
  final String header;
  final List<Map<String, dynamic>> orders;

  const _GroupedOrders({
    required this.header,
    required this.orders,
  });
}