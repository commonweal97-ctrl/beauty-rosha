// lib/widgets/order_preview.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_logger.dart';
import '../providers/order_refresh_provider.dart';
import '../screens/main_shell.dart';
import '../screens/profile/orders_screen.dart';
import '../services/api_service.dart';
import 'image_loader.dart';

class OrderPreview extends StatefulWidget {
  const OrderPreview({super.key});

  @override
  State<OrderPreview> createState() => OrderPreviewState();
}

class OrderPreviewState extends State<OrderPreview> {
  static const _logTag = 'OrderPreview';

  Map<String, dynamic>? _lastOrder;
  List<String> _images = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLastOrder();
    context.read<OrderRefreshProvider>().addListener(_onOrderChanged);
  }

  @override
  void dispose() {
    try {
      context.read<OrderRefreshProvider>().removeListener(_onOrderChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onOrderChanged() {
    _loadLastOrder();
  }

  Future<void> refresh() async {
    ApiService.invalidateCache(prefix: '/api/orders/');
    await _loadLastOrder();
  }

  Future<void> _loadLastOrder() async {
    final result = await ApiService.get('/api/orders/history');
    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadLastOrder failed: ${result.errorOrNull?.message}',
      );
      setState(() => _isLoading = false);
      return;
    }

    final data = result.valueOrNull?['data'];

    List orders = [];
    if (data is List) {
      orders = data;
    } else if (data is Map) {
      orders = (data['orders'] as List?) ??
          (data['items'] as List?) ??
          (data['data'] as List?) ??
          const [];
    }

    if (!mounted) return;

    if (orders.isEmpty) {
      setState(() {
        _lastOrder = null;
        _images = [];
        _isLoading = false;
      });
      return;
    }

    final firstItem = orders.first;
    if (firstItem is! Map) {
      setState(() {
        _lastOrder = null;
        _images = [];
        _isLoading = false;
      });
      return;
    }

    final order = Map<String, dynamic>.from(firstItem);
    final orderId = order['id'];
    final images = <String>[];

    if (orderId != null) {
      final detailResult = await ApiService.get(
        '/api/orders/detail?order_id=$orderId',
      );

      if (!mounted) return;

      if (detailResult.isSuccess) {
        List detailItems = [];
        final detailData = detailResult.valueOrNull?['data'];
        if (detailData is List) {
          detailItems = detailData;
        } else if (detailData is Map) {
          detailItems = (detailData['items'] as List?) ?? const [];
        }

        for (final item in detailItems.take(2)) {
          if (item is Map) {
            final img = item['main_image'] ?? item['image'];
            if (img != null && img.toString().isNotEmpty) {
              images.add(img.toString());
            }
          }
        }
      } else {
        AppLogger.warning(
          _logTag,
          'detail($orderId) failed: ${detailResult.errorOrNull?.message}',
        );
      }
    }

    if (!mounted) return;

    setState(() {
      _lastOrder = order;
      _images = images;
      _isLoading = false;
    });
  }

  String _getStatusText(Map<String, dynamic> order) {
    final status = order['status'] ?? '';
    if (status == 'pending') return 'Черновик';
    if (status == 'awaiting_payment') return 'Ожидает оплаты';
    if (status == 'cancelled') return 'Отменён';
    if (status == 'returned') return 'Возвращён';
    if (status == 'completed') return 'Уже доставили';
    if (status == 'processing') return 'Собираем ваш заказ';
    if (status == 'shipping') return 'Доставляется';
    if (status == 'ready_pickup') return 'Готов к получению';
    return 'В обработке';
  }

  Color _getStatusColor(Map<String, dynamic> order) {
    final status = order['status'] ?? '';
    if (status == 'awaiting_payment') return const Color(0xFF856404);
    if (status == 'cancelled') return const Color(0xFFB0B0B0);
    if (order['payment_status'] == 'paid') return const Color(0xFF155724);
    return const Color(0xFF004085);
  }

  Map<String, dynamic> _parseDeliveryData(Map<String, dynamic> order) {
    try {
      final d = order['delivery_data'];
      if (d is String) return jsonDecode(d) as Map<String, dynamic>;
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (e) {
      AppLogger.warning(_logTag, 'parseDeliveryData failed', e);
    }
    return {};
  }

  String _getDeliveryLabel(Map<String, dynamic> order) {
    final method = order['delivery_method'] ?? '';
    final data = _parseDeliveryData(order);
    switch (method) {
      case 'pickup-point':
        final provider = (data['provider'] ?? '').toString().toUpperCase();
        switch (provider) {
          case 'CDEK':
            return 'Доставка СДЭК';
          case 'YANDEX':
            return 'Доставка Яндекс';
          case 'FIVEPOST':
            return 'Доставка 5Post';
          case 'RUSSIAN_POST':
            return 'Доставка Почта России';
          case 'OZON':
            return 'Доставка Ozon';
          default:
            return 'Доставка в ПВЗ';
        }
      case 'courier':
        return 'Курьером до двери';
      case 'pickup-store':
        return 'Самовывоз';
      default:
        return '';
    }
  }

  String _getDeliverySubtitle(Map<String, dynamic> order) {
    final method = order['delivery_method'] ?? '';
    final data = _parseDeliveryData(order);
    switch (method) {
      case 'pickup-point':
        return data['point_address'] ?? '';
      case 'courier':
        final date = data['delivery_date'] ?? '';
        final time = data['delivery_time'] ?? '';
        if (date.isNotEmpty && time.isNotEmpty) {
          final d = DateTime.tryParse(date);
          if (d != null) {
            return '${d.day.toString().padLeft(2, '0')}.'
                '${d.month.toString().padLeft(2, '0')} $time';
          }
        }
        return data['address'] ?? '';
      case 'pickup-store':
        return 'пр. Станке Димитрова, 65';
      default:
        return '';
    }
  }

  Widget _getProviderIcon(String provider) {
    final icons = {
      'CDEK': 'assets/images/CDEKLogo.png',
      'YANDEX': 'assets/images/YandexLogo.png',
      'FIVEPOST': 'assets/images/5postlogo.png',
      'RUSSIAN_POST': 'assets/images/Pochalogo.png',
      'OZON': 'assets/images/OzonLogo.png',
    };
    final path = icons[provider.toUpperCase()];
    if (path == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Image.asset(
        path,
        width: 18,
        height: 18,
        fit: BoxFit.contain,
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
        'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
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

  @override
  Widget build(BuildContext context) {
    return _buildContent();
  }

  Widget _buildContent() {
    if (_isLoading) return _buildSkeleton();
    if (_lastOrder == null) return const SizedBox.shrink();

    final order = _lastOrder!;
    final statusText = _getStatusText(order);
    final statusColor = _getStatusColor(order);
    final deliveryLabel = _getDeliveryLabel(order);
    final deliverySubtitle = _getDeliverySubtitle(order);
    final dateText = _formatDate(order['created_at'] ?? '');
    final timeText = _formatTime(order['created_at'] ?? '');
    final data = _parseDeliveryData(order);
    final provider = (data['provider'] ?? '').toString().toUpperCase();

    return GestureDetector(
      onTap: () => MainShell.push(context, const OrdersScreen()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Заказы',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                        if (deliveryLabel.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (provider.isNotEmpty)
                                _getProviderIcon(provider),
                              Flexible(
                                child: Text(
                                  deliveryLabel,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (deliverySubtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            deliverySubtitle,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8F8F9A),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          '#${order['id']} от $dateText $timeText',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_images.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: _images.length == 1 ? 64 : 72,
                      height: _images.length == 1 ? 86 : 104,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: _images.asMap().entries.map((entry) {
                          final i = entry.key;
                          final img = entry.value;
                          final isSingle = _images.length == 1;
                          return Positioned(
                            left: isSingle ? 2.0 : (i == 0 ? 0.0 : null),
                            right: isSingle ? 2.0 : (i == 1 ? 0.0 : null),
                            top: isSingle ? 0.0 : (i == 0 ? 14.0 : 0.0),
                            child: Transform.rotate(
                              angle: isSingle ? 0 : (i == 0 ? -0.08 : 0.10),
                              child: Container(
                                width: 60,
                                height: 82,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFF0F0F0),
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
                                  width: 60,
                                  height: 82,
                                  borderRadius: 10,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => MainShell.push(context, const OrdersScreen()),
                  child: const Text(
                    'Все заказы →',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFDD1847),
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

    Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Заказы',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerBox(height: 24, width: 180, borderRadius: 6),
                      SizedBox(height: 12),
                      ShimmerBox(height: 18, width: 140, borderRadius: 6),
                      SizedBox(height: 8),
                      ShimmerBox(height: 16, borderRadius: 6),
                      SizedBox(height: 8),
                      ShimmerBox(height: 14, width: 100, borderRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 72,
                  height: 104,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: 14,
                        child: Transform.rotate(
                          angle: -0.08,
                          child: const ShimmerBox(
                            height: 82,
                            width: 60,
                            borderRadius: 10,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Transform.rotate(
                          angle: 0.10,
                          child: const ShimmerBox(
                            height: 82,
                            width: 60,
                            borderRadius: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const ShimmerBox(height: 16, width: 120, borderRadius: 6),
          ],
        ),
      ),
    );
  }
}