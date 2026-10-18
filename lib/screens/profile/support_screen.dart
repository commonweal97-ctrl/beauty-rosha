// lib/screens/profile/support_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_logger.dart';
import '../../models/support_ticket.dart';
import '../../providers/menu_provider.dart';
import '../../providers/support_badge_provider.dart';
import '../../services/api_service.dart';
import 'support_chat_screen.dart';
import '../../core/app_colors.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const _logTag = 'SupportScreen';

  List<SupportTicket> _tickets = [];
  bool _isLoading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadTickets(),
    );

    // Сбрасываем бейдж непрочитанных сообщений поддержки.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SupportBadgeProvider>().markAsRead();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    final result = await ApiService.get('/api/support/my-tickets');

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadTickets failed: ${result.errorOrNull?.message}',
      );
      setState(() => _isLoading = false);
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      setState(() => _isLoading = false);
      return;
    }

    final ticketsRaw = data['tickets'];
    final ticketsData = ticketsRaw is List ? ticketsRaw : const [];

    setState(() {
      _tickets = ticketsData
          .whereType<Map>()
          .map((t) => SupportTicket.fromJson(Map<String, dynamic>.from(t)))
          .toList();
      _isLoading = false;
    });
  }

  void _openTicket(SupportTicket ticket) {
    try {
      context.read<MenuProvider>().close();
    } catch (_) {
      // Меню может быть не подключено — не критично.
    }

    Navigator.of(context, rootNavigator: true)
        .push(
          MaterialPageRoute(
            builder: (_) => SupportChatScreen(ticket: ticket),
          ),
        )
        .then((_) => _loadTickets());
  }

  void _showCreateTicketDialog() {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();
    String? errorText;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          margin: EdgeInsets.only(top: MediaQuery.of(ctx).padding.top + 40),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                SizedBox(height: 20),
                Row(
                  children: [
                    Icon(
                      Icons.support_agent,
                      color: context.colors.brand,
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Новое обращение',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  'Опишите проблему и мы поможем',
                  style: TextStyle(fontSize: 14, color: context.colors.textMuted),
                ),
                SizedBox(height: 24),
                if (errorText != null)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: context.colors.error,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorText!,
                            style: TextStyle(
                              color: context.colors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  'Тема',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textSecondary,
                  ),
                ),
                SizedBox(height: 6),
                TextField(
                  controller: subjectController,
                  style: TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Например: Проблема с заказом',
                    hintStyle:
                        TextStyle(color: context.colors.textDisabled, fontSize: 15),
                    filled: true,
                    fillColor: context.colors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: context.colors.brand,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Описание',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.textSecondary,
                  ),
                ),
                SizedBox(height: 6),
                TextField(
                  controller: messageController,
                  maxLines: 4,
                  style: TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText:
                        'Опишите ситуацию — мы обязательно поможем',
                    hintStyle:
                        TextStyle(color: context.colors.textDisabled, fontSize: 15),
                    filled: true,
                    fillColor: context.colors.surfaceAlt,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: context.colors.brand,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting
                            ? null
                            : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side:
                              BorderSide(color: context.colors.border),
                        ),
                        child: Text(
                          'Отмена',
                          style: TextStyle(
                            color: context.colors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (subjectController.text
                                    .trim()
                                    .isEmpty) {
                                  setSheetState(() => errorText =
                                      'Укажите тему обращения');
                                  return;
                                }
                                if (messageController.text
                                    .trim()
                                    .isEmpty) {
                                  setSheetState(
                                    () => errorText =
                                        'Опишите вашу проблему',
                                  );
                                  return;
                                }

                                setSheetState(() {
                                  isSubmitting = true;
                                  errorText = null;
                                });

                                try {
                                  final result = await ApiService.post(
                                    '/api/support/create-ticket',
                                    {
                                      'subject': subjectController.text.trim(),
                                      'message': messageController.text.trim(),
                                    },
                                  );

                                  if (result.isFailure) {
                                    AppLogger.warning(
                                      _logTag,
                                      'create-ticket failed: '
                                          '${result.errorOrNull?.message}',
                                    );
                                    if (ctx.mounted) {
                                      setSheetState(() => errorText =
                                          result.errorOrNull?.userMessage ??
                                              'Ошибка создания обращения');
                                    }
                                    return;
                                  }

                                  final data = result.valueOrNull?['data'];
                                  if (data is! Map) {
                                    if (ctx.mounted) {
                                      setSheetState(() => errorText =
                                          'Ошибка создания обращения');
                                    }
                                    return;
                                  }

                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _loadTickets();

                                  final ticket = SupportTicket(
                                    id: (data['ticket_id'] as num?)?.toInt() ?? 0,
                                    subject:
                                        subjectController.text.trim(),
                                    status:
                                        (data['status'] as String?) ?? 'open',
                                    unread: 0,
                                    createdAt:
                                        DateTime.now().toIso8601String(),
                                  );
                                  _openTicket(ticket);
                                } catch (e, st) {
                                  AppLogger.error(
                                    _logTag,
                                    'create-ticket unexpected error',
                                    e,
                                    st,
                                  );
                                  if (ctx.mounted) {
                                    setSheetState(() => errorText =
                                        'Ошибка соединения с сервером');
                                  }
                                } finally {
                                  if (ctx.mounted) {
                                    setSheetState(
                                      () => isSubmitting = false,
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.colors.brand,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isSubmitting ? 'Отправка...' : 'Отправить',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr.replaceFirst(' ', 'T'));
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) return 'Сегодня';
      if (diff.inDays == 1) return 'Вчера';
      if (diff.inDays < 7) return '${diff.inDays} дн. назад';

      return '${date.day.toString().padLeft(2, '0')}.'
          '${date.month.toString().padLeft(2, '0')}.${date.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr.replaceFirst(' ', 'T'));
      return '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: context.colors.background,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.colors.surfaceAlt,
        body: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  SizedBox(height: topPadding + 56),
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: context.colors.brand,
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadTickets,
                            color: context.colors.brand,
                            child: _tickets.isEmpty
                                ? ListView(
                                    children: [
                                      SizedBox(
                                        height: MediaQuery.of(context)
                                                .size
                                                .height *
                                            0.7,
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 80,
                                                height: 80,
                                                decoration: BoxDecoration(
                                                  color: context.colors.surface,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    24,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(
                                                        alpha: 0.04,
                                                      ),
                                                      blurRadius: 12,
                                                      offset:
                                                          Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: Icon(
                                                  Icons.support_agent,
                                                  size: 40,
                                                  color: context.colors.brand,
                                                ),
                                              ),
                                              SizedBox(height: 20),
                                              Text(
                                                'Нет обращений',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w600,
                                                  color: context.colors.textPrimary,
                                                ),
                                              ),
                                              SizedBox(height: 6),
                                              Text(
                                                'Создайте обращение — мы поможем',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: context.colors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _tickets.length,
                                    itemBuilder: (context, index) {
                                      final ticket = _tickets[index];
                                      return _TicketCard(
                                        ticket: ticket,
                                        onTap: () => _openTicket(ticket),
                                        formatDate: _formatDate,
                                        formatTime: _formatTime,
                                      );
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
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                child: Container(
                  padding: EdgeInsets.only(top: topPadding, bottom: 4),
                  color: context.colors.surface,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 48),
                        child: Text(
                          'Поддержка',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: IconButton(
                              icon: Icon(
                                Icons.arrow_back,
                                color: context.colors.error,
                                size: 22,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: TextButton.icon(
                              onPressed: _showCreateTicketDialog,
                              icon: Icon(
                                Icons.add,
                                color: context.colors.brand,
                                size: 20,
                              ),
                              label: Text(
                                'Создать',
                                style: TextStyle(
                                  color: context.colors.brand,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
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
}

class _TicketCard extends StatelessWidget {
  final SupportTicket ticket;
  final VoidCallback onTap;
  final String Function(String) formatDate;
  final String Function(String) formatTime;

  const _TicketCard({
    required this.ticket,
    required this.onTap,
    required this.formatDate,
    required this.formatTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _statusBgColor(ticket.status),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _statusIcon(ticket.status),
                        size: 18,
                        color: _statusColor(context, ticket.status),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.subject,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: ticket.isClosed
                                  ? context.colors.textMuted
                                  : context.colors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${formatDate(ticket.createdAt)} в '
                            '${formatTime(ticket.createdAt)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusBgColor(ticket.status),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ticket.statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _statusColor(context, ticket.status),
                            ),
                          ),
                        ),
                        if (ticket.unread > 0) ...[
                          SizedBox(height: 4),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.brand,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '+${ticket.unread}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, String status) {
    switch (status) {
      case 'open':
        return Color(0xFF1D4ED8);
      case 'waiting_reply':
        return Color(0xFF92400E);
      case 'closed':
        return Color(0xFF6B7280);
      default:
        return context.colors.textSecondary;
    }
  }

  Color _statusBgColor(String status) {
    switch (status) {
      case 'open':
        return const Color(0xFFDBEAFE);
      case 'waiting_reply':
        return const Color(0xFFFEF3C7);
      case 'closed':
        return const Color(0xFFF3F4F6);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'open':
        return Icons.check_circle_outline;
      case 'waiting_reply':
        return Icons.hourglass_empty;
      case 'closed':
        return Icons.lock_outline;
      default:
        return Icons.help_outline;
    }
  }
}