// lib/models/support_ticket.dart
class SupportTicket {
  final int id;
  final String subject;
  final String status;
  final int unread;
  final String createdAt;
  final String? updatedAt;

  SupportTicket({
    required this.id,
    required this.subject,
    required this.status,
    required this.unread,
    required this.createdAt,
    this.updatedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] ?? 0,
      subject: json['subject'] ?? 'Без темы',
      status: json['status'] ?? 'open',
      unread: json['unread'] ?? 0,
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'],
    );
  }

  String get statusText {
    switch (status) {
      case 'open':
        return 'В работе';
      case 'waiting_reply':
        return 'Ждёт ответа';
      case 'closed':
        return 'Закрыт';
      default:
        return status;
    }
  }

  bool get isClosed => status == 'closed';
}