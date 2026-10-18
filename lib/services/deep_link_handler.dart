// lib/services/deep_link_handler.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_logger.dart';
import '../core/navigation.dart';
import '../models/support_ticket.dart';
import '../providers/catalog_provider.dart';
import '../screens/catalog/catalog_screen.dart';
import '../screens/main_shell.dart';
import '../screens/product/product_detail_screen.dart';
import '../screens/profile/order_detail_screen.dart';
import '../screens/profile/reviews_screen.dart';
import '../screens/profile/support_chat_screen.dart';
import '../screens/profile/support_screen.dart';

class DeepLinkHandler {
  static const _logTag = 'DeepLinkHandler';

  /// Очередь ссылок, ожидающих обработки (навигатор ещё не готов).
  static final List<Uri> _deferred = [];

  /// 🔥 Дедупликация. iOS и Flutter могут передать одну и ту же
  /// ссылку дважды подряд (app_links + onGenerateRoute).
  static String? _lastUri;
  static DateTime? _lastUriAt;
  static const _dedupWindow = Duration(milliseconds: 1000);

  /// Точка входа. Может вызываться из любого места —
  /// из `DeepLinkService`, `PushService`, MainShell, `onGenerateRoute`.
  ///
  /// Контекст не требуется: работаем через глобальный `appNavigatorKey`.
  /// Если MainShell ещё не готов — ставим в очередь (см. `flushDeferred`).
  static void handleUri(Uri uri) {
    // 🔥 Дедупликация.
    final now = DateTime.now();
    final uriStr = uri.toString();
    if (_lastUri == uriStr &&
        _lastUriAt != null &&
        now.difference(_lastUriAt!) < _dedupWindow) {
      AppLogger.info(_logTag, 'duplicate link ignored: $uri');
      return;
    }
    _lastUri = uriStr;
    _lastUriAt = now;

    AppLogger.info(_logTag, 'handleUri: $uri');

    final navState = appNavigatorKey.currentState;
    if (navState == null) {
      _deferred.add(uri);
      AppLogger.warning(
        _logTag,
        'Navigator not ready, deferring: $uri (queue=${_deferred.length})',
      );
      return;
    }

    _route(uri, navState);
  }

  /// Вызывать, когда MainShell готов принимать навигацию.
  /// Проигрывает все отложенные ссылки.
  static void flushDeferred() {
    if (_deferred.isEmpty) return;

    final navState = appNavigatorKey.currentState;
    if (navState == null) return;

    final queue = List<Uri>.from(_deferred);
    _deferred.clear();

    AppLogger.info(_logTag, 'flushing ${queue.length} deferred link(s)');

    for (final uri in queue) {
      _route(uri, navState);
    }
  }

  // ============================================================
  //  Роутинг
  // ============================================================

  static void _route(Uri uri, NavigatorState navState) {
    final path = uri.path;
    final queryParams = uri.queryParameters;

    // Нормализуем кастомную схему beautyrosha://
    // beautyrosha://product/foo → https://xn--80abvyjk6cts.xn--p1ai/product/foo
    if (uri.scheme == 'beautyrosha') {
      final newPath =
          uri.host.isEmpty ? uri.path : '/${uri.host}${uri.path}';
      final rebuilt = Uri(
        scheme: 'https',
        host: 'xn--80abvyjk6cts.xn--p1ai',
        path: newPath,
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      AppLogger.info(_logTag, 'normalized beautyrosha:// → $rebuilt');
      _route(rebuilt, navState);
      return;
    }

    if (path.startsWith('/product/')) {
      final slug =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
      if (slug.isEmpty) return;

      _goToTab(navState, 0);
      _push(
        navState,
        ProductDetailScreen(slug: slug),
        delayMs: 300,
      );
      return;
    }

    if (path.startsWith('/catalog')) {
      final categoryId = queryParams['category'] != null
          ? int.tryParse(queryParams['category']!)
          : null;
      final brand = queryParams['brand'];
      final sort = queryParams['sort'];
      final search = queryParams['search'];

      _goToTab(navState, 0);
      _push(
        navState,
        ChangeNotifierProvider(
          create: (_) => CatalogProvider(),
          child: CatalogScreen(
            initialCategoryId: categoryId,
            initialBrand: brand,
            initialSort: sort,
            searchQuery: search,
          ),
        ),
        delayMs: 300,
      );
      return;
    }

    if (path.startsWith('/profile/reviews')) {
      _goToTab(navState, 3);
      _push(navState, const ReviewsScreen(initialTab: 1), delayMs: 300);
      return;
    }

    if (path.startsWith('/profile/support')) {
      _goToTab(navState, 3);
      final ticketIdStr = queryParams['ticket_id'];
      final ticketId =
          ticketIdStr != null ? int.tryParse(ticketIdStr) : null;

      if (ticketId != null && ticketId > 0) {
        _push(
          navState,
          SupportChatScreen(
            ticket: SupportTicket(
              id: ticketId,
              subject: '',
              status: '',
              unread: 0,
              createdAt: '',
            ),
          ),
          delayMs: 300,
        );
      } else {
        _push(navState, const SupportScreen(), delayMs: 300);
      }
      return;
    }

    if (path.startsWith('/profile/order-detail')) {
      _goToTab(navState, 3);
      final orderIdStr = queryParams['id'];
      final orderId =
          orderIdStr != null ? int.tryParse(orderIdStr) : null;
      if (orderId != null && orderId > 0) {
        _push(
          navState,
          OrderDetailScreen(orderId: orderId),
          delayMs: 300,
        );
      }
      return;
    }

    if (path == '/cart' || path.startsWith('/cart')) {
      MainShell.tabNotifier.value = 2;
      _popToRoot(navState);
      return;
    }

    if (path == '/profile' || path.startsWith('/profile')) {
      MainShell.tabNotifier.value = 3;
      _popToRoot(navState);
      return;
    }

    AppLogger.warning(_logTag, 'No route for path: $path');
  }

  // ============================================================
  //  Навигационные хелперы
  // ============================================================

  static void _goToTab(NavigatorState navState, int index) {
    MainShell.tabNotifier.value = index;
    _popToRoot(navState);
  }

  static void _popToRoot(NavigatorState navState) {
    try {
      navState.popUntil((route) => route.isFirst);
    } catch (e) {
      AppLogger.warning(_logTag, 'popUntil failed', e);
    }
  }

  static void _push(
    NavigatorState navState,
    Widget screen, {
    int delayMs = 0,
  }) {
    if (delayMs <= 0) {
      navState.push(MaterialPageRoute(builder: (_) => screen));
      return;
    }
    Future.delayed(Duration(milliseconds: delayMs), () {
      final current = appNavigatorKey.currentState;
      if (current == null) {
        AppLogger.warning(_logTag, 'Navigator gone before push');
        return;
      }
      current.push(MaterialPageRoute(builder: (_) => screen));
    });
  }
}