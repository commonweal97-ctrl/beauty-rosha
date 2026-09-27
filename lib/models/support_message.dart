// lib/models/support_message.dart
class SupportMessage {
  final int id;
  final int? userId;
  final String? message;
  final String? attachmentUrl;
  final String? attachmentName;
  final String createdAt;
  final bool isMine;
  final bool isPending;
  final bool isFailed;
  final bool isSent;
  final String? tempId;

  SupportMessage({
    required this.id,
    this.userId,
    this.message,
    this.attachmentUrl,
    this.attachmentName,
    required this.createdAt,
    required this.isMine,
    this.isPending = false,
    this.isFailed = false,
    this.isSent = false,
    this.tempId,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    final rawMessage = json['message'] ?? '';
    
    String? attachmentUrl;
    String? attachmentName;
    String cleanMessage = rawMessage;
    
    final regex = RegExp(r'\[Файл:\s*(.+?)\]\((.+?)\)');
    final match = regex.firstMatch(rawMessage);
    
    if (match != null) {
      attachmentName = match.group(1) ?? '';
      attachmentUrl = match.group(2) ?? '';
      cleanMessage = rawMessage.replaceAll(match.group(0) ?? '', '').trim();
    }
    
    if (json['attachment_url'] != null && json['attachment_url'].toString().isNotEmpty) {
      attachmentUrl = json['attachment_url'].toString();
    }
    if (json['attachment_name'] != null && json['attachment_name'].toString().isNotEmpty) {
      attachmentName = json['attachment_name'].toString();
    }
    
    if (json['file_path'] != null && json['file_path'].toString().isNotEmpty) {
      attachmentUrl = json['file_path'].toString();
    }
    if (json['file_name'] != null && json['file_name'].toString().isNotEmpty) {
      attachmentName = json['file_name'].toString();
    }

    return SupportMessage(
      id: json['id'] ?? 0,
      userId: json['user_id'],
      message: cleanMessage.isEmpty ? null : cleanMessage,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
      isMine: json['user_id'] != null,
      isPending: false,
      isFailed: false,
      isSent: true,
    );
  }

  SupportMessage copyWith({
    int? id,
    int? userId,
    String? message,
    String? attachmentUrl,
    String? attachmentName,
    String? createdAt,
    bool? isMine,
    bool? isPending,
    bool? isFailed,
    bool? isSent,
    String? tempId,
  }) {
    return SupportMessage(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      message: message ?? this.message,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      createdAt: createdAt ?? this.createdAt,
      isMine: isMine ?? this.isMine,
      isPending: isPending ?? this.isPending,
      isFailed: isFailed ?? this.isFailed,
      isSent: isSent ?? this.isSent,
      tempId: tempId ?? this.tempId,
    );
  }

  bool get isFile => attachmentUrl != null && 
                     attachmentName != null && 
                     attachmentUrl!.isNotEmpty && 
                     attachmentName!.isNotEmpty;
                     
  bool get isImage => isFile && RegExp(
    r'\.(jpg|jpeg|png|gif|webp|heic|heif|bmp)$', 
    caseSensitive: false
  ).hasMatch(attachmentName!);
  
  String get displayUrl {
    if (attachmentUrl == null || attachmentUrl!.isEmpty) return '';
    
    if (tempId != null && 
        !attachmentUrl!.startsWith('http') &&
        !attachmentUrl!.startsWith('/uploads')) {
      return attachmentUrl!;
    }
    
    if (attachmentUrl!.startsWith('http')) {
      return attachmentUrl!;
    }
    
    String fileParam = attachmentUrl!;
    if (fileParam.startsWith('/')) {
      fileParam = fileParam.substring(1);
    }
    if (fileParam.startsWith('uploads/support/')) {
      fileParam = fileParam.substring('uploads/support/'.length);
    }
    
    return 'https://xn--80abvyjk6cts.xn--p1ai/api/support/file?file=${Uri.encodeComponent(fileParam)}';
  }
}