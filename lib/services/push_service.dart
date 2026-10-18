// lib/services/push_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:provider/provider.dart';

import '../core/app_logger.dart';
import '../core/navigation.dart';
import '../providers/support_badge_provider.dart';
import 'api_service.dart';
import 'deep_link_handler.dart';

class PushService {
  static const _logTag = 'PushService';

  static final PushService _instance = PushService._();
  factory PushService() => _instance;
  PushService._();

  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  static bool _initialized = false;

  String? get fcmToken => _fcmToken;

  /// Колбэк, который вызывается, когда пользователь тапнул по push.
  /// Устанавливается из `MainShell` → `_handleIncomingLink`.
  static void Function(String link)? onNotificationTap;

  /// Ссылка из push, ожидающая обработки (cold start / early hot start).
  static String? _pendingLink;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    _messaging = FirebaseMessaging.instance;

    await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    _messaging!.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      _saveTokenToServer(newToken);
    });

    try {
      _fcmToken = await _messaging!.getToken();
      if (_fcmToken != null) _saveTokenToServer(_fcmToken!);
    } catch (e) {
      AppLogger.warning(_logTag, 'getToken failed', e);
    }

    await _initLocalNotifications();
    _setupMessageHandlers();
  }

  Future<void> syncToken() async {
    if (_fcmToken != null) {
      await _saveTokenToServer(_fcmToken!);
    }
  }

  Future<String> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'ios_unknown';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      }

      return 'unknown';
    } catch (e) {
      AppLogger.warning(_logTag, 'getDeviceId failed', e);
      return 'unknown';
    }
  }

  Future<void> _saveTokenToServer(String token) async {
    try {
      final deviceId = await _getDeviceId();

      final result = await ApiService.post('/api/user/save-push-token', {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'device_id': deviceId,
      });

      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'save-push-token failed: ${result.errorOrNull?.message}',
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
    } catch (e) {
      AppLogger.warning(_logTag, 'saveTokenToServer failed', e);
    }
  }

  Future<void> _initLocalNotifications() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          'beauty_rosha_channel_v2',
          'Бьюти Роща',
          description: 'Уведомления о заказах, акциях и новинках',
          importance: Importance.high,
        ),
      );
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
  }

  void _onNotificationResponse(NotificationResponse response) {
    _handlePayload(response.payload);
  }

  void _setupMessageHandlers() {
    FirebaseMessaging.onMessage.listen((message) {
      _maybeUpdateSupportBadge(message);
      _showLocalNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _maybeUpdateSupportBadge(message);
      final link = message.data['link'] as String?;
      if (link != null && link.isNotEmpty) {
        _dispatch(link);
      }
    });

    _messaging!.getInitialMessage().then((message) {
      if (message != null) {
        _maybeUpdateSupportBadge(message);
        final link = message.data['link'] as String?;
        if (link != null && link.isNotEmpty) {
          _dispatch(link);
        }
      }
    });
  }

  /// Обновляет бейдж поддержки, если пуш относится к поддержке.
  /// Работает как через Provider (глобальный appNavigatorKey), так и без
  /// контекста (если приложение ещё не готово — ничего не делаем).
  void _maybeUpdateSupportBadge(RemoteMessage message) {
    try {
      final data = message.data;
      debugPrint('[SupportBadge] onMessage data=$data');
      final type = data['type'];
      if (type != 'support') {
        debugPrint('[SupportBadge] skip: type=$type');
        return;
      }

      final ctx = appNavigatorKey.currentContext;
      debugPrint('[SupportBadge] ctx=${ctx == null ? "NULL" : "OK"}');
      if (ctx == null) return;

      final int? count = int.tryParse('${data['count'] ?? ''}');
      debugPrint('[SupportBadge] increment count=$count');
      Provider.of<SupportBadgeProvider>(ctx, listen: false)
          .increment(count: count);
    } catch (e) {
      debugPrint('[SupportBadge] ERROR: $e');
      AppLogger.warning(_logTag, 'support badge update failed: $e');
    }
  }

  /// Единая точка доставки ссылки из push.
  /// Если слушатель (MainShell) уже установлен — отдаём сразу,
  /// иначе сохраняем в `_pendingLink` и обработаем позже
  /// через `processPendingLink`.
  void _dispatch(String link) {
    if (onNotificationTap != null) {
      onNotificationTap!(link);
    } else {
      _pendingLink = link;
    }
  }

  /// Вызывается из `MainShell` в postFrameCallback — отдаёт отложенную
  /// ссылку, если она накопилась до готовности UI.
  static void processPendingLink(BuildContext context) {
    final link = _pendingLink;
    if (link == null) return;

    _pendingLink = null;

    if (onNotificationTap != null) {
      onNotificationTap!(link);
      return;
    }

    // Fallback — если по какой-то причине слушатель ещё не установлен,
    // отдаём напрямую в DeepLinkHandler.
    final uri = Uri.tryParse(link);
    if (uri != null) {
      DeepLinkHandler.handleUri(uri);
    }
  }

  void _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final link = message.data['link'] as String?;

    final androidDetails = AndroidNotificationDetails(
      'beauty_rosha_channel_v2',
      'Бьюти Роща',
      channelDescription: 'Уведомления о заказах, акциях и новинках',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_notification',
      color: const Color(0xFFDD1847),
      colorized: true,
    );

    final payloadMap = <String, dynamic>{
      'link': link ?? '',
      ...message.data,
    };

    await _localNotifications.show(
      id: message.messageId.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(payloadMap),
    );

    if (link != null && link.isNotEmpty) {
      Future.delayed(const Duration(seconds: 1), () {
        _dispatch(link);
      });
    }
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;

    String? link;

    try {
      final data = jsonDecode(payload);

      if (data is Map<String, dynamic>) {
        link = data['link'] as String?;

        if (link == null || link.isEmpty) {
          link = data['data']?['link'] as String?;
        }
      }
    } catch (_) {
      if (payload.startsWith('/') || payload.startsWith('http')) {
        link = payload;
      }
    }

    if (link != null && link.isNotEmpty) {
      _dispatch(link);
    }
  }

  Future<void> deleteToken() async {
    try {
      await _messaging?.deleteToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('fcm_token');
      _fcmToken = null;
    } catch (e) {
      AppLogger.warning(_logTag, 'deleteToken failed', e);
    }
  }
}