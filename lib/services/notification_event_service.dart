// lib/services/notification_event_service.dart

import '../providers/notification_provider.dart';

class NotificationEventService {
  static final NotificationEventService _instance = NotificationEventService._internal();
  factory NotificationEventService() => _instance;
  NotificationEventService._internal();

  void notifyRead({int count = 0}) {
    final bus = NotificationEventBus();
    bus.add(NotificationReadEvent(count: count));
  }

  void dispose() {
    final bus = NotificationEventBus();
    bus.dispose();
  }
}