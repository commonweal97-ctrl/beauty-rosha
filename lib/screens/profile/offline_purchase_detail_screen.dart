// lib/screens/profile/offline_purchase_detail_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_logger.dart';
import '../../providers/currency_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/image_loader.dart';
import '../main_shell.dart';
import '../product/product_detail_screen.dart';
import '../../core/app_colors.dart';
import '../../services/store_service.dart';

class OfflinePurchaseDetailScreen extends StatefulWidget {
  final int purchaseId;

  const OfflinePurchaseDetailScreen({
    super.key,
    required this.purchaseId,
  });

  @override
  State<OfflinePurchaseDetailScreen> createState() =>
      _OfflinePurchaseDetailScreenState();
}

class _OfflinePurchaseDetailScreenState
    extends State<OfflinePurchaseDetailScreen> {
  static const _logTag = 'OfflinePurchaseDetailScreen';

  Map<String, dynamic>? _purchase;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    final result = await ApiService.get(
      '/api/offline-purchases/detail?id=${widget.purchaseId}',
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadDetail(${widget.purchaseId}) failed: '
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

    setState(() {
      _purchase = Map<String, dynamic>.from(data);
      _isLoading = false;
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

  String _formatPrice(double price) {
    final currency = context.read<CurrencyProvider>();
    if (price == price.roundToDouble()) {
      return '${price.toInt()} ${currency.symbol}';
    }
    return '${price.toStringAsFixed(2)} ${currency.symbol}';
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
        'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _callPhone(String phone) async {
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.colors.surfaceAlt,
        body: Stack(
          children: [
            Center(
              child: CircularProgressIndicator(color: context.colors.brand),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildHeader(topPadding, 'Чек', ''),
            ),
          ],
        ),
      );
    }

    if (_purchase == null) {
      return Scaffold(
        backgroundColor: context.colors.surfaceAlt,
        body: Stack(
          children: [
            Center(
              child: Text(
                'Чек не найден',
                style: TextStyle(color: context.colors.textMuted),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildHeader(topPadding, 'Чек', ''),
            ),
          ],
        ),
      );
    }

    final items = _parseItems(_purchase!['items']);
    final total = _parseDouble(_purchase!['total']);
    final checkId = _purchase!['check_id'] ?? '';
    final shopName = _purchase!['shop_name'] ?? 'Б•Роща — Брянск';
    final shopAddress = _purchase!['shop_address'] ??
        StoreService.getDefaultAddress();
    final date = _purchase!['purchase_date'] ?? '';
    final paymentMethod = _purchase!['payment_method'] ?? 'Не указан';
    final itemCount = items.length;

    return Scaffold(
      backgroundColor: context.colors.surfaceAlt,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: topPadding + 48),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          color: context.colors.surface,
                          padding: EdgeInsets.fromLTRB(0, 20, 0, 0),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  shopName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  shopAddress,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: context.colors.textMuted,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: context.colors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      _InfoRow(
                                        label: 'График',
                                        value: 'Будни: 10:00–19:00\n'
                                            'Выходные: 10:00–18:00',
                                      ),
                                      SizedBox(height: 10),
                                      GestureDetector(
                                        onTap: () =>
                                            _callPhone('+79208447732'),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .spaceBetween,
                                          children: [
                                            Text(
                                              'Телефон',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color:
                                                    context.colors.textMuted,
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.phone_outlined,
                                                  size: 16,
                                                  color:
                                                      context.colors.brand,
                                                ),
                                                SizedBox(width: 6),
                                                Text(
                                                  '+7 (920) 844-77-32',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: context.colors.brand,
                                                    fontWeight:
                                                        FontWeight.w500,
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
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          color: context.colors.surface,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.fromLTRB(
                                  12,
                                  20,
                                  12,
                                  8,
                                ),
                                child: Text(
                                  'Товары',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textMuted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              ...items.map((item) {
                                final itemTotal = _parseDouble(
                                      item['price'],
                                    ) *
                                    _parseDouble(item['quantity']);
                                final imageRaw = item['main_image_card'] ??
                                    item['main_image'] ??
                                    '';
                                final image = imageRaw
                                    .toString()
                                    .replaceAll('main.webp', 'main_card.webp');
                                final slug = item['slug'] ?? '';
                                return Container(
                                  padding: EdgeInsets.fromLTRB(
                                    12,
                                    14,
                                    12,
                                    14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: context.colors.border,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (image.isNotEmpty)
                                        GestureDetector(
                                          onTap: () {
                                            if (slug.isNotEmpty) {
                                              MainShell.push(
                                                context,
                                                ProductDetailScreen(
                                                  slug: slug,
                                                ),
                                              );
                                            }
                                          },
                                          child: ImageLoader(
                                            imageUrl: image,
                                            width: 64,
                                            height: 86,
                                            borderRadius: 10,
                                          ),
                                        ),
                                      SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['name'] ?? '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight:
                                                    FontWeight.w600,
                                                color: context.colors.textPrimary,
                                              ),
                                            ),
                                            SizedBox(height: 6),
                                            Text(
                                              _formatPrice(itemTotal),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight:
                                                    FontWeight.w700,
                                                color: context.colors.brand,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              '${item['quantity']} шт.',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: context.colors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          color: context.colors.surface,
                          padding: EdgeInsets.fromLTRB(
                            12,
                            20,
                            12,
                            24,
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$itemCount ${_pluralItems(itemCount)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: context.colors.textMuted,
                                    ),
                                  ),
                                  Text(
                                    _formatPrice(total),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              Divider(),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Итого',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    _formatPrice(total),
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4EDDA),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    paymentMethod,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF155724),
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
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(
              topPadding,
              'Чек $checkId',
              _formatDate(date),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    double topPadding,
    String title,
    String subtitle,
  ) {
    return ClipRRect(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _callPhone('+79208447732'),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.support_agent,
                    color: context.colors.textSecondary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _pluralItems(int n) {
    final m10 = n % 10;
    final m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'товар';
    if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) return 'товара';
    return 'товаров';
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: context.colors.textMuted,
          ),
        ),
        SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textPrimary,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}