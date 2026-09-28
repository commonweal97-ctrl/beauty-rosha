// lib/screens/profile/support_chat_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_logger.dart';
import '../../models/support_message.dart';
import '../../models/support_ticket.dart';
import '../../services/api_service.dart';
import '../../services/camera_service.dart';
import '../../core/app_colors.dart';

class SupportChatScreen extends StatefulWidget {
  final SupportTicket ticket;

  const SupportChatScreen({super.key, required this.ticket});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  static const _logTag = 'SupportChatScreen';

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  late final CameraService _cameraService;

  List<SupportMessage> _messages = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String _currentStatus = '';

  Timer? _pollTimer;
  String? _lastMessageId;

  final Map<int, bool> _showDateCache = {};

  @override
  void initState() {
    super.initState();
    _cameraService = CameraService();
    _currentStatus = widget.ticket.status;
    _loadMessages();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollNewMessages(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final result = await ApiService.get(
      '/api/support/messages?ticket_id=${widget.ticket.id}',
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadMessages failed: ${result.errorOrNull?.message}',
      );
      setState(() => _isLoading = false);
      return;
    }

    final data = result.valueOrNull?['data'];
    final List<dynamic> messagesData = data is List ? data : const [];

    final serverMessages = messagesData
        .whereType<Map>()
        .map((m) => SupportMessage.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    setState(() {
      _messages = _mergeWithLocal(serverMessages);
      _isLoading = false;
      _showDateCache.clear();

      if (serverMessages.isNotEmpty) {
        _lastMessageId = serverMessages.last.id.toString();
      }
    });
    _scrollToBottom();
  }

  Future<void> _pollNewMessages() async {
    if (_isUploading) return;

    String path = '/api/support/messages?ticket_id=${widget.ticket.id}';
    if (_lastMessageId != null) {
      path += '&after_id=$_lastMessageId';
    }

    final result = await ApiService.get(path, forceRefresh: true);

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'pollNewMessages failed: ${result.errorOrNull?.message}',
      );
      return;
    }

    final data = result.valueOrNull?['data'];
    final List<dynamic> messagesData = data is List ? data : const [];

    if (messagesData.isEmpty) return;

    final serverMessages = messagesData
        .whereType<Map>()
        .map((m) => SupportMessage.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    setState(() {
      _messages = _mergeWithLocal(serverMessages);
      _showDateCache.clear();

      if (serverMessages.isNotEmpty) {
        _lastMessageId = serverMessages.last.id.toString();
      }
    });
    _scrollToBottom();
  }

  List<SupportMessage> _mergeWithLocal(List<SupportMessage> serverMessages) {
    final merged = <SupportMessage>[];
    final seenTexts = <String>{};

    for (final sm in serverMessages) {
      merged.add(sm);
      if (sm.message != null) seenTexts.add(sm.message!);
    }

    for (final local in _messages) {
      if (local.id == 0 && local.message != null) {
        if (!seenTexts.contains(local.message)) {
          merged.add(local);
        }
      }
    }

    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return merged;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent > 0) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();

    final localMsg = SupportMessage(
      id: 0,
      userId: 1,
      message: text,
      createdAt: DateTime.now().toIso8601String(),
      isMine: true,
      isPending: true,
    );

    setState(() {
      _messages.add(localMsg);
      _showDateCache.clear();
      _messageController.clear();
    });

    _scrollToBottom();
    _focusNode.requestFocus();

    try {
      if (_currentStatus == 'closed') {
        final statusResult = await ApiService.post(
          '/api/support/toggle-status',
          {'ticket_id': widget.ticket.id},
        );

        if (!mounted) return;

        if (statusResult.isFailure) {
          AppLogger.warning(
            _logTag,
            'toggle-status failed: ${statusResult.errorOrNull?.message}',
          );
        }
      }

      final result = await ApiService.post('/api/support/send', {
        'ticket_id': widget.ticket.id,
        'message': text,
      });

      if (!mounted) return;

      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'send message failed: ${result.errorOrNull?.message}',
        );
        _markMessageFailed(text);
        return;
      }

      final data = result.valueOrNull?['data'];
      if (data is! Map) {
        _markMessageFailed(text);
        return;
      }

      _currentStatus = (data['status'] as String?) ?? 'open';
      final sentId = (data['id'] as num?)?.toInt() ?? 0;

      setState(() {
        final index = _messages.indexWhere(
          (m) => m.id == 0 && m.message == text && m.isPending,
        );

        if (index != -1) {
          _messages[index] = SupportMessage(
            id: sentId,
            userId: 1,
            message: text,
            createdAt: _messages[index].createdAt,
            isMine: true,
            isPending: false,
            isSent: true,
          );
        }
        _showDateCache.clear();
      });

      if (sentId > 0) {
        _lastMessageId = sentId.toString();
      }
    } catch (e, st) {
      AppLogger.error(_logTag, 'sendMessage unexpected error', e, st);
      _markMessageFailed(text);
    }
  }

  void _markMessageFailed(String text) {
    if (!mounted) return;

    setState(() {
      final index = _messages.indexWhere(
        (m) => m.id == 0 && m.message == text && m.isPending,
      );

      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isPending: false,
          isFailed: true,
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ошибка отправки'),
        backgroundColor: context.colors.brand,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Повторить',
          textColor: Colors.white,
          onPressed: () => _retrySend(text),
        ),
      ),
    );
  }

  Future<void> _retrySend(String text) async {
    setState(() {
      final index = _messages.indexWhere(
        (m) => m.id == 0 && m.message == text && m.isFailed,
      );
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isPending: true,
          isFailed: false,
        );
      }
    });

    try {
      final result = await ApiService.post('/api/support/send', {
        'ticket_id': widget.ticket.id,
        'message': text,
      });

      if (!mounted) return;

      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'retrySend failed: ${result.errorOrNull?.message}',
        );
        _markMessageFailed(text);
        return;
      }

      final data = result.valueOrNull?['data'];
      if (data is! Map) {
        _markMessageFailed(text);
        return;
      }

      final sentId = (data['id'] as num?)?.toInt() ?? 0;

      setState(() {
        final index = _messages.indexWhere(
          (m) => m.id == 0 && m.message == text,
        );

        if (index != -1) {
          _messages[index] = SupportMessage(
            id: sentId,
            userId: 1,
            message: text,
            createdAt: _messages[index].createdAt,
            isMine: true,
            isPending: false,
            isSent: true,
          );
        }
      });
    } catch (e, st) {
      AppLogger.error(_logTag, 'retrySend unexpected error', e, st);
      _markMessageFailed(text);
    }
  }

  Future<void> _attachFile() async {
    if (_currentStatus == 'closed') {
      final statusResult = await ApiService.post(
        '/api/support/toggle-status',
        {'ticket_id': widget.ticket.id},
      );

      if (!mounted) return;

      if (statusResult.isFailure) {
        AppLogger.warning(
          _logTag,
          'attachFile/toggle-status failed: '
              '${statusResult.errorOrNull?.message}',
        );
        return;
      }
      _currentStatus = 'open';
    }

    final hasCamera = await _cameraService.isCameraAvailable;
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Прикрепить фото',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16),
              if (hasCamera)
                ListTile(
                  leading: Icon(
                    Icons.camera_alt,
                    color: context.colors.brand,
                  ),
                  title: Text('Сделать снимок'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleImagePick(ImageSource.camera);
                  },
                ),
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: context.colors.brand,
                ),
                title: const Text('Выбрать из галереи'),
                onTap: () {
                  Navigator.pop(ctx);
                  _handleImagePick(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleImagePick(ImageSource source) async {
    try {
      final fileWithMeta = await _cameraService.pickImage(source);
      if (fileWithMeta == null) return;

      if (!mounted) return;

      if (fileWithMeta.isTooLarge) {
        _showError(const CameraException(
          code: CameraErrorCode.tooLarge,
          message: 'Файл слишком большой',
        ));
        return;
      }

      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final localMsg = SupportMessage(
        id: 0,
        userId: 1,
        message: '',
        attachmentUrl: fileWithMeta.file.path,
        attachmentName: fileWithMeta.name,
        createdAt: DateTime.now().toIso8601String(),
        isMine: true,
        isPending: true,
        tempId: tempId,
      );

      setState(() {
        _messages.add(localMsg);
        _showDateCache.clear();
        _isUploading = true;
      });
      _scrollToBottom();

      final response = await ApiService.uploadFile(
        '/api/support/upload-file',
        filePath: fileWithMeta.file.path,
        fileName: fileWithMeta.name,
        fieldName: 'file',
        additionalFields: {'ticket_id': widget.ticket.id.toString()},
      );

      if (!mounted) return;

      if (response.isFailure) {
        AppLogger.warning(
          _logTag,
          'uploadFile failed: ${response.errorOrNull?.message}',
        );
        _markFileFailed(tempId);
        return;
      }

      final data = response.valueOrNull?['data'];
      if (data is! Map) {
        _markFileFailed(tempId);
        return;
      }

      _currentStatus = (data['status'] as String?) ?? 'open';

      setState(() {
        final index = _messages.indexWhere((m) => m.tempId == tempId);
        if (index != -1) {
          _messages[index] = SupportMessage(
            id: (data['file_id'] as num?)?.toInt() ?? 0,
            userId: 1,
            message: '',
            attachmentUrl: (data['file_path'] as String?) ?? '',
            attachmentName: (data['file_name'] as String?) ?? '',
            createdAt: _messages[index].createdAt,
            isMine: true,
            isPending: false,
            isSent: true,
          );
        }
      });

      final fileId = data['file_id'];
      if (fileId != null) {
        _lastMessageId = fileId.toString();
      }

      await _loadMessages();
    } on CameraException catch (e) {
      if (mounted) _showError(e);
    } catch (e, st) {
      AppLogger.error(_logTag, 'handleImagePick failed', e, st);
      if (mounted) {
        _showError(const CameraException(
          code: CameraErrorCode.unknown,
          message: 'Ошибка загрузки',
        ));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _markFileFailed(String tempId) {
    setState(() {
      final index = _messages.indexWhere((m) => m.tempId == tempId);
      if (index != -1) {
        _messages[index] = _messages[index].copyWith(
          isPending: false,
          isFailed: true,
        );
      }
    });
  }

  void _showError(CameraException error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.userFriendlyMessage),
        backgroundColor: context.colors.brand,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
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

  bool _isDifferentDay(String date1, String date2) {
    try {
      final d1 = DateTime.parse(date1.replaceFirst(' ', 'T'));
      final d2 = DateTime.parse(date2.replaceFirst(' ', 'T'));
      return d1.day != d2.day || d1.month != d2.month || d1.year != d2.year;
    } catch (_) {
      return false;
    }
  }

  bool _shouldShowDate(int index) {
    if (_showDateCache.containsKey(index)) {
      return _showDateCache[index]!;
    }

    final showDate = index == 0 ||
        _isDifferentDay(
          _messages[index - 1].createdAt,
          _messages[index].createdAt,
        );

    _showDateCache[index] = showDate;
    return showDate;
  }

  @override
  Widget build(BuildContext context) {
    final isClosed = _currentStatus == 'closed';

    return Scaffold(
      backgroundColor: context.colors.surfaceAlt,
      appBar: _buildAppBar(isClosed),
      body: GestureDetector(
        onTap: () => _focusNode.unfocus(),
        child: Column(
          children: [
            if (_isUploading) _buildUploadBanner(),
            Expanded(child: _buildBody()),
            _buildInputArea(isClosed),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isClosed) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.ticket.subject,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Text(
                'Обращение #${widget.ticket.id}',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: isClosed
                      ? Colors.white24
                      : context.colors.success.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isClosed ? 'Закрыто' : 'Открыто',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: context.colors.brand,
      elevation: 0,
    );
  }

  Widget _buildUploadBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: context.colors.surfaceAlt,
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.colors.brand,
            ),
          ),
          SizedBox(width: 12),
          Text(
            'Загрузка фото...',
            style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: context.colors.brand),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: 40,
                color: context.colors.brand,
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Нет сообщений',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Напишите первое сообщение',
              style: TextStyle(fontSize: 14, color: context.colors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      key: const ValueKey('chat_list'),
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: _messages.length,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        final showDate = _shouldShowDate(index);
        return Column(
          key: ValueKey('msg_${msg.id}_${msg.tempId ?? index}'),
          children: [
            if (showDate) _DateDivider(date: msg.createdAt),
            _MessageBubble(
              message: msg,
              formatTime: _formatTime,
              onRetry: msg.isFailed
                  ? () => _retrySend(msg.message ?? '')
                  : null,
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputArea(bool isClosed) {
    final hasText = _messageController.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildAttachButton(),
              Expanded(child: _buildTextField(isClosed)),
              const SizedBox(width: 8),
              _buildSendButton(hasText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachButton() {
    return Container(
      width: 44,
      height: 44,
      margin: EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isUploading ? null : _attachFile,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Icon(
              Icons.camera_alt,
              size: 22,
              color: _isUploading
                  ? context.colors.textDisabled
                  : context.colors.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(bool isClosed) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _focusNode.hasFocus
              ? context.colors.brand.withValues(alpha: 0.3)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _messageController,
        focusNode: _focusNode,
        maxLines: 5,
        minLines: 1,
        textInputAction: TextInputAction.newline,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(
          fontSize: 15,
          color: context.colors.textPrimary,
          height: 1.4,
        ),
        decoration: InputDecoration(
          hintText: isClosed
              ? 'Обращение закрыто. Напишите, чтобы открыть...'
              : 'Сообщение...',
          hintStyle: TextStyle(color: context.colors.textDisabled, fontSize: 15),
          border: InputBorder.none,
          contentPadding: EdgeInsets.fromLTRB(16, 12, 12, 12),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildSendButton(bool hasText) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: hasText ? context.colors.brand : context.colors.border,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: hasText ? _sendMessage : null,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: Icon(
              Icons.arrow_upward,
              color: hasText ? Colors.white : context.colors.textMuted,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final String date;

  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    String label;
    try {
      final d = DateTime.parse(date.replaceFirst(' ', 'T'));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDate = DateTime(d.year, d.month, d.day);
      final diff = today.difference(msgDate).inDays;

      if (diff == 0) {
        label = 'Сегодня';
      } else if (diff == 1) {
        label = 'Вчера';
      } else {
        const months = [
          'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
          'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
        ];
        label = '${d.day} ${months[d.month - 1]}';
        if (d.year != now.year) label += ' ${d.year}';
      }
    } catch (_) {
      return SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: context.colors.border)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.colors.textMuted,
              ),
            ),
          ),
          Expanded(child: Divider(color: context.colors.border)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final SupportMessage message;
  final String Function(String) formatTime;
  final VoidCallback? onRetry;

  const _MessageBubble({
    required this.message,
    required this.formatTime,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final hasFile = message.isFile;
    final hasText = (message.message ?? '').isNotEmpty;
    final showRetry = message.isFailed && onRetry != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) _buildSupportAvatar(context),
          Flexible(
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (hasFile && message.isImage)
                  _buildImagePreview(context, isMine),
                if (hasFile && !message.isImage)
                  _buildFileAttachment(context, isMine),
                if (hasText)
                  _buildTextBubble(message.message!, isMine, context),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isPending)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: context.colors.textDisabled,
                            ),
                          ),
                        ),
                      if (showRetry)
                        GestureDetector(
                          onTap: onRetry,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.error_outline,
                              size: 14,
                              color: Colors.red[400],
                            ),
                          ),
                        ),
                      Text(
                        formatTime(message.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.colors.textDisabled,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMine) _buildUserAvatar(context),
        ],
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context, bool isMine) {
    final url = message.displayUrl;
    if (url.isEmpty) return const SizedBox.shrink();

    final isLocalFile = message.tempId != null &&
        message.attachmentUrl != null &&
        !message.attachmentUrl!.startsWith('http') &&
        !message.attachmentUrl!.startsWith('/uploads');

    Widget imageWidget;

    if (isLocalFile && File(message.attachmentUrl!).existsSync()) {
      imageWidget = Image.file(
        File(message.attachmentUrl!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildImageError(context, isMine),
      );
    } else {
      imageWidget = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: 500,
        memCacheHeight: 500,
        maxWidthDiskCache: 500,
        maxHeightDiskCache: 500,
        placeholder: (_, _) => Container(
          width: 200,
          height: 200,
          color: isMine ? const Color(0xFFC9153E) : context.colors.border,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.colors.brand,
            ),
          ),
        ),
        errorWidget: (_, _, _) => _buildImageError(context, isMine),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250, maxHeight: 250),
          child: imageWidget,
        ),
      ),
    );
  }

  Widget _buildImageError(BuildContext context, bool isMine) {
    return Container(
      width: 200,
      height: 100,
      color: isMine ? const Color(0xFFC9153E) : context.colors.border,
      child: Center(
        child: Icon(
          Icons.broken_image,
          color: context.colors.textDisabled,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildFileAttachment(BuildContext context, bool isMine) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFFC9153E) : context.colors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.attach_file,
              size: 20,
              color: isMine ? Colors.white70 : context.colors.textSecondary,
            ),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                message.attachmentName ?? 'Файл',
                style: TextStyle(
                  color: isMine ? Colors.white : context.colors.textPrimary,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextBubble(String text, bool isMine, BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMine ? context.colors.brand : context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: (isMine ? context.colors.brand : Colors.black)
                .withValues(alpha: isMine ? 0.15 : 0.04),
            blurRadius: isMine ? 8 : 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: _buildRichText(context, text, isMine),
    );
  }

  Widget _buildRichText(BuildContext context, String text, bool isMine) {
    final textColor = isMine ? Colors.white : context.colors.textPrimary;
    final linkColor =
        isMine ? const Color(0xFFFFD54F) : const Color(0xFF1D4ED8);

    final urlRegex = RegExp(r'https?://[^\s]+');
    final matches = urlRegex.allMatches(text);

    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 15,
          height: 1.45,
        ),
      );
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      final url = match.group(0)!;
      spans.add(TextSpan(
        text: url,
        style: TextStyle(
          color: linkColor,
          fontSize: 15,
          height: 1.45,
          decoration: TextDecoration.underline,
          decorationColor: linkColor,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
      ));

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return Text.rich(
      TextSpan(
        style: TextStyle(color: textColor, fontSize: 15, height: 1.45),
        children: spans,
      ),
    );
  }

  Widget _buildSupportAvatar(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      margin: EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: context.colors.brandLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: CustomPaint(
          size: Size(18, 18),
          painter: _HeadsetIconPainter(color: context.colors.brand),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 8),
      child: SizedBox(
        width: 32,
        height: 32,
        child: Center(
          child: Icon(
            Icons.person,
            color: context.colors.brand,
            size: 24,
          ),
        ),
      ),
    );
  }
}

class _HeadsetIconPainter extends CustomPainter {
  final Color color;
  _HeadsetIconPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final scaleX = size.width / 24;
    final scaleY = size.height / 24;
    canvas.scale(scaleX, scaleY);

    canvas.drawPath(
      Path()
        ..moveTo(3, 18)
        ..lineTo(3, 12)
        ..cubicTo(3, 7.03, 7.03, 3, 12, 3)
        ..cubicTo(16.97, 3, 21, 7.03, 21, 12)
        ..lineTo(21, 18),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(3, 19)
        ..cubicTo(3, 20.1, 3.9, 21, 5, 21)
        ..lineTo(6, 21)
        ..cubicTo(7.1, 21, 8, 20.1, 8, 19)
        ..lineTo(8, 16)
        ..cubicTo(8, 14.9, 7.1, 14, 6, 14)
        ..lineTo(3, 14),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(21, 19)
        ..cubicTo(21, 20.1, 20.1, 21, 19, 21)
        ..lineTo(18, 21)
        ..cubicTo(16.9, 21, 16, 20.1, 16, 19)
        ..lineTo(16, 16)
        ..cubicTo(16, 14.9, 16.9, 14, 18, 14)
        ..lineTo(21, 14),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}