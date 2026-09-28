// lib/screens/notifications/notifications_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_logger.dart';
import '../../models/support_ticket.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/notification_service.dart';
import '../../services/push_service.dart';
import '../catalog/catalog_screen.dart';
import '../main_shell.dart';
import '../product/product_detail_screen.dart';
import '../profile/order_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../profile/support_chat_screen.dart';
import '../profile/support_screen.dart';
import '../../core/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  static const _logTag = 'NotificationsScreen';

  final NotificationService _notificationService = NotificationService();

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 1;
  bool _isDisposed = false;

  final ScrollController _scrollController = ScrollController();
  final Set<int> _deletingIds = {};
  final Map<int, Timer> _deleteTimers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);

    _loadNotifications();

    _notificationService.clearBadge();
    Future.microtask(() {
      if (mounted) {
        context.read<NotificationProvider>().setUnreadCount(0);
      }
    });

    _notificationService.markAllAsRead().then((success) {
      if (!success) {
        AppLogger.warning(_logTag, 'markAllAsRead returned false (initState)');
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _applyAllPendingDeletes();
    WidgetsBinding.instance.removeObserver(this);
    _cancelAllTimers();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_isDisposed) {
      _notificationService.clearBadge();
      _notificationService.markAllAsRead().then((success) {
        if (!success) {
          AppLogger.warning(
            _logTag,
            'markAllAsRead returned false (resume)',
          );
        }
      });
      Future.microtask(() {
        if (mounted) {
          context.read<NotificationProvider>().setUnreadCount(0);
        }
      });
      _refreshNotifications();
    }
  }

  Future<void> _refreshNotifications() async {
    _page = 1;
    _hasMore = true;
    await _loadNotifications();
    _notificationService.clearBadge();
  }

  Future<void> _loadNotifications() async {
    if (_isLoading && _notifications.isNotEmpty) return;
    if (!_hasMore && _page > 1) return;

    setState(() => _isLoading = true);

    try {
      final result = await _notificationService.getNotifications(page: _page);
      if (!mounted) return;

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        final rawList = data['notifications'];

        final notifications = rawList is List
            ? rawList
                .whereType<Map>()
                .map((n) => Map<String, dynamic>.from(n))
                .toList()
            : <Map<String, dynamic>>[];

        setState(() {
          if (_page == 1) {
            _notifications = notifications;
          } else {
            _notifications.addAll(notifications);
          }
          _hasMore = data['has_more'] ?? false;
          if (_hasMore) _page++;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      AppLogger.warning(_logTag, 'loadNotifications failed', e);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      _loadNotifications();
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) {
    final link = notification['link'] as String?;
    if (link == null || link.isEmpty) return;

    final uri = Uri.tryParse(link);
    if (uri == null) return;

    if (link.contains('/profile#')) {
      final fragment = uri.fragment;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileScreen(initialTab: fragment),
        ),
      );
      return;
    }

    if (link == '/profile' || link.endsWith('/profile')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
        ),
      );
      return;
    }

    if (link.contains('/product/')) {
      final slug = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (slug.isNotEmpty) {
        MainShell.push(context, ProductDetailScreen(slug: slug));
        return;
      }
    }

    if (link.contains('/catalog')) {
      final categoryId = uri.queryParameters['category'] != null
          ? int.tryParse(uri.queryParameters['category']!)
          : null;
      final brand = uri.queryParameters['brand'];
      final sort = uri.queryParameters['sort'];
      final search = uri.queryParameters['search'];

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider(
            create: (_) => CatalogProvider(),
            child: CatalogScreen(
              initialCategoryId: categoryId,
              initialBrand: brand,
              initialSort: sort,
              searchQuery: search,
            ),
          ),
        ),
      );
      return;
    }

    if (link.contains('#support') || link == '/profile#support') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SupportScreen()),
      );
      return;
    }

    if (link.contains('/profile/support')) {
      final ticketIdStr = uri.queryParameters['ticket_id'];
      if (ticketIdStr != null) {
        final ticketId = int.tryParse(ticketIdStr);
        if (ticketId != null && ticketId > 0) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SupportChatScreen(
                ticket: SupportTicket(
                  id: ticketId,
                  subject: '',
                  status: '',
                  unread: 0,
                  createdAt: '',
                ),
              ),
            ),
          );
          return;
        }
      }
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SupportScreen()),
      );
      return;
    }

    if (link.contains('order-detail')) {
      final orderId = uri.queryParameters['id'];
      if (orderId != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: int.parse(orderId)),
          ),
        );
        return;
      }
    }

    PushService.onNotificationTap?.call(link);
  }

  int _getNotificationId(Map<String, dynamic> notification) {
    final id = notification['id'];
    if (id is int) return id;
    if (id is String) return int.tryParse(id) ?? 0;
    return 0;
  }

  void _startDelete(int notificationId) {
    if (notificationId == 0) return;
    if (_deletingIds.contains(notificationId)) {
      _cancelDelete(notificationId);
      return;
    }

    setState(() => _deletingIds.add(notificationId));

    final timer = Timer(const Duration(seconds: 5), () {
      if (mounted && _deletingIds.contains(notificationId)) {
        _confirmDelete(notificationId);
      }
    });

    _deleteTimers[notificationId] = timer;
  }

  void _cancelDelete(int notificationId) {
    _deleteTimers[notificationId]?.cancel();
    _deleteTimers.remove(notificationId);
    setState(() => _deletingIds.remove(notificationId));
  }

  void _undoAll() {
    final ids = _deletingIds.toList();
    for (final id in ids) {
      _cancelDelete(id);
    }
  }

  Future<void> _confirmDelete(int notificationId) async {
    _deleteTimers[notificationId]?.cancel();
    _deleteTimers.remove(notificationId);

    setState(() {
      _notifications.removeWhere(
        (n) => _getNotificationId(n) == notificationId,
      );
      _deletingIds.remove(notificationId);
    });

    try {
      final success =
          await _notificationService.deleteNotification(notificationId);
      if (!success && mounted) {
        _refreshNotifications();
        _showErrorSnackbar('Не удалось удалить уведомление');
      }
    } catch (e) {
      AppLogger.warning(_logTag, 'confirmDelete failed', e);
      if (mounted) {
        _refreshNotifications();
        _showErrorSnackbar('Не удалось удалить уведомление');
      }
    }
  }

  void _applyAllPendingDeletes() {
    if (_deletingIds.isEmpty) return;
    final idsToDelete = _deletingIds.toList();
    _cancelAllTimers();

    setState(() {
      _notifications.removeWhere(
        (n) => idsToDelete.contains(_getNotificationId(n)),
      );
      _deletingIds.clear();
    });

    if (idsToDelete.isNotEmpty) {
      _notificationService.deleteNotifications(idsToDelete).then((success) {
        if (!success) {
          AppLogger.warning(
            _logTag,
            'deleteNotifications returned false',
          );
        }
      });
    }
  }

  void _cancelAllTimers() {
    for (final timer in _deleteTimers.values) {
      timer.cancel();
    }
    _deleteTimers.clear();
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    final utc = DateTime.tryParse(dateStr);
    if (utc == null) return dateStr;

    final local = utc.toLocal();
    final now = DateTime.now();
    final hours = local.hour.toString().padLeft(2, '0');
    final mins = local.minute.toString().padLeft(2, '0');
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(dateDay).inDays;

    if (diffDays == 0) return 'Сегодня $hours:$mins';
    if (diffDays == 1) return 'Вчера $hours:$mins';
    return '${local.day.toString().padLeft(2, '0')}.'
        '${local.month.toString().padLeft(2, '0')}.'
        '${local.year} $hours:$mins';
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null &&
              details.primaryVelocity! > 300) {
            Navigator.pop(context);
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFFF8F8F8),
          body: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    SizedBox(height: topPadding + 48),
                    Expanded(child: _buildBody(bottomPadding)),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  child: Container(
                    padding: EdgeInsets.only(top: topPadding, bottom: 4),
                    color: Colors.white,
                    child: Row(
                      children: [
                        SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.arrow_forward_ios,
                            color: context.colors.error,
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
                          child: Text(
                            'Уведомления',
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
              if (_deletingIds.isNotEmpty) _buildUndoToast(bottomPadding),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(double bottomPadding) {
    if (_isLoading && _notifications.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: context.colors.brand),
      );
    }

    if (!_isLoading && _notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.brand.withValues(alpha: 0.06),
              ),
              child: Icon(
                Icons.notifications_outlined,
                size: 28,
                color: context.colors.textMuted,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Уведомлений пока нет',
              style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Здесь будут появляться уведомления\n'
              'о заказах, акциях и новостях',
              style: TextStyle(
                color: context.colors.textMuted,
                fontSize: 15,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshNotifications,
      color: context.colors.brand,
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(top: 6, bottom: 100 + bottomPadding),
        itemCount: _notifications.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _notifications.length) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: context.colors.brand,
                ),
              ),
            );
          }
          return _buildNotificationCard(_notifications[index]);
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final notificationId = _getNotificationId(notification);
    final isDeleting = _deletingIds.contains(notificationId);
    final isUnread = notification['is_read'] != true;
    final date = _formatDate(notification['created_at'] ?? '');
    final title = notification['title'] ?? '';
    final message = notification['message'] ?? '';
    final type = notification['type'] ?? 'system';
    final hasLink = (notification['link'] as String?)?.isNotEmpty == true;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: EdgeInsets.fromLTRB(16, 20, 12, 20),
      decoration: BoxDecoration(
        color: isDeleting
            ? Color(0xFFFFF5F5)
            : (isUnread ? context.colors.brandLight : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: isDeleting
            ? Border.all(
                color: context.colors.error.withValues(alpha: 0.3),
              )
            : (isUnread
                ? Border.all(color: const Color(0xFFFCE4E9))
                : null),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                margin: EdgeInsets.only(right: 12, top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.brand,
                ),
              )
            else
              const SizedBox(width: 20),
            Expanded(
              child: GestureDetector(
                onTap: hasLink
                    ? () => _handleNotificationTap(notification)
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getTypeLabel(type),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textMuted,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Spacer(),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            isUnread ? FontWeight.w700 : FontWeight.w600,
                        color: context.colors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    if (message.isNotEmpty && message != title) ...[
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF777777),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 8),
              child: GestureDetector(
                onTap: () => _startDelete(notificationId),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDeleting
                        ? context.colors.error.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.03),
                  ),
                  child: isDeleting
                      ? const _DeleteProgressIndicator()
                      : const Icon(
                          Icons.close,
                          size: 16,
                          color: Color(0xFFBBBBBB),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUndoToast(double bottomPadding) {
    final count = _deletingIds.length;
    return Positioned(
      bottom: 20 + bottomPadding,
      left: 20,
      right: 20,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: context.colors.textPrimary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white60,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                count == 1
                    ? 'Уведомление удаляется'
                    : 'Удалено $count уведомления',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            GestureDetector(
              onTap: _undoAll,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Отменить',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.colors.textPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'order':
        return 'ЗАКАЗ';
      case 'payment':
        return 'ОПЛАТА';
      case 'bonus':
        return 'БОНУСЫ';
      case 'promotion':
        return 'АКЦИЯ';
      case 'support':
        return 'ПОДДЕРЖКА';
      default:
        return 'УВЕДОМЛЕНИЕ';
    }
  }
}

class _DeleteProgressIndicator extends StatefulWidget {
  const _DeleteProgressIndicator();

  @override
  State<_DeleteProgressIndicator> createState() =>
      _DeleteProgressIndicatorState();
}

class _DeleteProgressIndicatorState extends State<_DeleteProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            value: 1.0 - _controller.value,
            strokeWidth: 2.5,
            backgroundColor: Colors.transparent,
            valueColor:
                AlwaysStoppedAnimation<Color>(context.colors.error),
          ),
        );
      },
    );
  }
}