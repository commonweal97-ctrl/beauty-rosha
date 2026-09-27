// lib/widgets/bonus_history_popup.dart
import 'package:flutter/material.dart';

import '../core/app_logger.dart';
import '../services/api_service.dart';

// ========================================================================
// BONUS HISTORY POPUP
// ========================================================================

class BonusHistoryPopup extends StatefulWidget {
  const BonusHistoryPopup({super.key});

  @override
  State<BonusHistoryPopup> createState() => _BonusHistoryPopupState();

  // ========================================================================
  // STATIC SHOW METHOD — ПОВЕРХ ВСЕГО (как CityPicker)
  // ========================================================================

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => const BonusHistoryPopup(),
    );
  }
}

class _BonusHistoryPopupState extends State<BonusHistoryPopup> {
  static const _logTag = 'BonusHistoryPopup';

  final List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _currentPage = 1;
  bool _loadingMore = false;
  int _totalItems = 0;

  List<Map<String, dynamic>> _expiringBatches = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadExpiringBatches();
  }

  Future<void> _loadHistory() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);

    final result = await ApiService.get(
      '/api/bonus/history',
      queryParams: {'page': _currentPage, 'limit': 20},
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadHistory failed: ${result.errorOrNull?.message}',
      );
      setState(() {
        _isLoading = false;
        _loadingMore = false;
        _hasMore = false;
      });
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      setState(() {
        _isLoading = false;
        _loadingMore = false;
        _hasMore = false;
      });
      return;
    }

    final items = (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final total = data['total'] ?? 0;

    setState(() {
      _history.addAll(items);
      _totalItems = total;
      _hasMore = _history.length < total;
      _isLoading = false;
      _loadingMore = false;
      _currentPage++;
    });
  }

  Future<void> _loadExpiringBatches() async {
    final result = await ApiService.get('/api/bonus/expiring');

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadExpiringBatches failed: ${result.errorOrNull?.message}',
      );
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return;

    setState(() {
      _expiringBatches = (data['batches'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'История бонусов',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                if (_totalItems > 0)
                  Text(
                    '$_totalItems ${_pluralize(_totalItems)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF999999),
                    ),
                  ),
                const SizedBox(width: 8),
                const SizedBox(width: 36),
              ],
            ),
          ),

          // Секция сгорающих бонусов
          if (_expiringBatches.isNotEmpty) _buildExpiringSection(),

          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // Content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiringSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCE4E9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                size: 16,
                color: Color(0xFFDD1847),
              ),
              const SizedBox(width: 4),
              const Text(
                'Сгорят скоро',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _expiringBatches.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final batch = _expiringBatches[index];
                return _buildExpiringCard(batch);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiringCard(Map<String, dynamic> batch) {
    final amount = batch['amount'] ?? 0;
    final daysLeft = batch['days_left'] ?? 0;
    final expiresAt = batch['expires_at'] ?? '';
    final formattedDate = _formatExpiryDate(expiresAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$amount бонусов',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                daysLeft <= 1 ? 'Сгорят завтра' : 'Сгорят $formattedDate',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFDD1847),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFDD1847)),
      );
    }

    if (_history.isEmpty && _expiringBatches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFDD1847).withValues(alpha: 0.06),
              ),
              child: const Icon(
                Icons.card_giftcard,
                size: 32,
                color: Color(0xFFDD1847),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Пока нет операций',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Совершайте покупки и получайте бонусы',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF999999),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _history.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _history.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFFDD1847),
                ),
              ),
            ),
          );
        }

        return _buildHistoryItem(_history[index]);
      },
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    final amount = item['amount'] ?? 0;
    final isPositive = amount > 0;
    final reason = item['reason'] ?? '';
    final createdAt = item['created_at'] ?? '';
    final orderId = item['order_id'];

    final formattedDate = _formatDate(createdAt);
    final icon =
        isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline;
    final iconColor =
        isPositive ? const Color(0xFF4CAF50) : const Color(0xFFDD1847);
    final amountText = isPositive ? '+$amount' : '$amount';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: iconColor,
                ),
              ),
              if (orderId != null)
                Text(
                  'Заказ #$orderId',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFCCCCCC),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _pluralize(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'операция';
    if ([2, 3, 4].contains(m10) && ![12, 13, 14].contains(m100)) {
      return 'операции';
    }
    return 'операций';
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        return 'Сегодня, ${_pad(date.hour)}:${_pad(date.minute)}';
      } else if (diff.inDays == 1) {
        return 'Вчера, ${_pad(date.hour)}:${_pad(date.minute)}';
      } else if (diff.inDays < 7) {
        return '${diff.inDays} дн. назад';
      } else {
        return '${_pad(date.day)}.${_pad(date.month)}.${date.year}';
      }
    } catch (_) {
      return dateStr;
    }
  }

  String _formatExpiryDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      const months = [
        'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
        'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
      ];
      return '${date.day} ${months[date.month - 1]}';
    } catch (_) {
      return dateStr;
    }
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}