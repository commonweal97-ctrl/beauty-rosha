// lib/screens/main_shell.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../services/image_memory_cache.dart';
import '../services/mobile_menu_service.dart';
import '../services/cdn_service.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../core/app_logger.dart';
import '../core/navigation.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/catalog_provider.dart';
import '../providers/menu_provider.dart';
import '../providers/profile_refresh_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/rateable_provider.dart';
import '../providers/recommendation_provider.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/deep_link_handler.dart';
import '../services/deep_link_service.dart';
import '../services/push_permission_service.dart';
import '../services/push_service.dart';
import '../services/app_review_service.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/mobile_menu.dart';
import '../widgets/common/cat_city_hint.dart';
import '../widgets/app_header.dart';
import '../widgets/network_error_banner.dart';
import '../widgets/push_permission_dialog.dart';
import 'cart/cart_screen.dart';
import 'catalog/home_screen.dart';
import 'notifications/notifications_screen.dart';
import 'profile/profile_screen.dart';
import 'update/update_required_screen.dart';
import '../../core/app_colors.dart';

/// Маркер для экранов, которые должны открываться НАД BottomNav
/// (полноэкранно, как ProductDetail, Checkout и т.п.).
///
/// Использование:
/// ```dart
/// MainShell.push(context, MyScreen(), fullscreen: true);
/// ```
class FullscreenRoute extends MaterialPageRoute {
  FullscreenRoute({required super.builder})
      : super(fullscreenDialog: true);
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// 🔥 Глобальный notifier активной вкладки.
  /// Изменение value → MainShell переключает PageView.
  static final ValueNotifier<int> tabNotifier = ValueNotifier<int>(0);

  /// 🔥 Публичное API навигации — работает из любого места приложения.
  ///
  /// По умолчанию экран открывается **в текущей вкладке** (BottomNav виден) —
  /// как в Ozon/WB. Если `fullscreen: true` — экран откроется **над всем
  /// приложением** (BottomNav скрыт, как ProductDetail).
  static Future<T?> push<T>(
    BuildContext context,
    Widget page, {
    bool fullscreen = false,
  }) {
    // Полноэкранный режим — пушим в корневой Navigator.
    if (fullscreen) {
      final rootNav = appNavigatorKey.currentState;
      if (rootNav != null) {
        return rootNav.push<T>(
          MaterialPageRoute(builder: (_) => page),
        );
      }
    }

    // Обычный режим — пушим в навигатор текущей вкладки.
    final state = _MainShellState._instance;
    if (state != null) {
      final nav = state._navigatorKeys[state._currentIndex].currentState;
      if (nav != null) {
        return nav.push<T>(MaterialPageRoute(builder: (_) => page));
      }
    }

    // Fallback — если MainShell ещё не готов.
    final rootNav = appNavigatorKey.currentState;
    if (rootNav != null) {
      return rootNav.push<T>(MaterialPageRoute(builder: (_) => page));
    }

    return Future<T?>.value(null);
  }

  /// Alias для [push] — оставлен для совместимости со старым кодом.
  static Future<T?> pushWithResult<T>(
    BuildContext context,
    Widget page, {
    bool fullscreen = false,
  }) {
    return push<T>(context, page, fullscreen: fullscreen);
  }

  /// Открыть экран и **очистить весь стек** (например, после logout — LoginScreen).
  static Future<T?> pushAndRemoveUntil<T>(
    BuildContext context,
    Widget page, {
    bool fullscreen = false,
    bool keepRoot = false,
  }) {
    final route = MaterialPageRoute<T>(builder: (_) => page);
    // keepRoot=true — оставить главный экран (MainShell) под LoginScreen,
    // чтобы «назад» не давал чёрный экран.
    final predicate = keepRoot
        ? (Route<dynamic> r) => r.isFirst
        : (Route<dynamic> r) => false;
    final rootNav = appNavigatorKey.currentState;
    if (rootNav != null) {
      return rootNav.pushAndRemoveUntil<T>(route, predicate);
    }
    return Navigator.of(context).pushAndRemoveUntil<T>(route, predicate);
  }

  /// Переключить вкладку и сбросить её стек до корня.
  static void popToRootAndSwitchTab(BuildContext context, int tabIndex) {
    final state = _MainShellState._instance;
    if (state != null) {
      final nav = state._navigatorKeys[state._currentIndex].currentState;
      try {
        nav?.popUntil((route) => route.isFirst);
      } catch (_) {}
    }

    // Переключаем вкладку через notifier.
    tabNotifier.value = tabIndex;
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {

  static const _logTag = 'MainShell';

  /// 🔥 Ссылка на текущий инстанс MainShell — используется в статических
  /// методах для пуша в навигатор активной вкладки.
  static _MainShellState? _instance;

  int _currentIndex = 0;
  bool _isInitialAuth = true;


  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  bool _initialLoadDone = false;
  final Set<int> _visitedTabs = {0};

  final Key _homeKey = const ValueKey('home_tab');
  final Key _cartKey = const ValueKey('cart_tab');
  final Key _profileKey = const ValueKey('profile_tab');

  void _onAvailabilityChanged(bool isAvailable, bool isBlocking) {
    if (!mounted) return;
    if (isAvailable) {
      // Не делаем full reload при первом старте (иначе дубль с _loadAllData)
      if (_initialLoadDone) _fullReload();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        NetworkErrorBanner.show(
          context,
          isBlocking: isBlocking,
          onRetry: () => _fullReload(),
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _precacheMenuIcons();

    _instance = this;


    WidgetsBinding.instance.addObserver(this);

    ApiService.addAvailabilityListener(_onAvailabilityChanged);

    // Подписка на глобальный tabNotifier — переключение вкладок
    // из DeepLinkHandler / push-уведомлений.
    MainShell.tabNotifier.addListener(_onExternalTabChange);

    // Слушатель push-уведомлений — отдаёт ссылку в DeepLinkHandler.
    PushService.onNotificationTap = _handleIncomingLink;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Устанавливаем слушателя deep links — доставит всё,
      // что накопилось в очереди (cold start).
      DeepLinkService.instance.setListener((uri) {
  _handleIncomingLink(uri.toString());
});

      // Проигрываем отложенные ссылки из DeepLinkHandler.
      DeepLinkHandler.flushDeferred();

      _initApp();
      ConnectivityService().init(context);
      PushService.processPendingLink(context);

      // Проверка оценки приложения (через 3–7 дней после заказа).
      _maybeRequestReview();
    });
  }

  /// Проверка — пора ли запросить оценку приложения.
  /// Показываем пре-попап: «Нравится / Не нравится».
  Future<void> _maybeRequestReview() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    debugPrint('[AppReview] order_placed_at = ${prefs.getString("app_review_order_placed_at")}');
    debugPrint('[AppReview] last_shown = ${prefs.getString("app_review_last_shown")}');
    debugPrint('[AppReview] completed = ${prefs.getBool("app_review_completed")}');
    final shouldShow = await AppReviewService.shouldShowNow();
    debugPrint('[AppReview] shouldShow = $shouldShow');
    if (!shouldShow || !mounted) return;

    // Небольшая задержка, чтобы UI прогрузился
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) => _ReviewPromptSheet(),
    );

    if (result == true) {
      // «Нравится» → системный диалог App Store / Google Play
      await AppReviewService.showSystemReview();
      await AppReviewService.markAsCompleted();
    } else if (result == false) {
      // «Не нравится» → форма обратной связи
      await AppReviewService.openFeedback();
      await AppReviewService.markFeedbackShown();
    }
    // Если null (закрыл без выбора) — не отмечаем
  }

  /// Подсветка блока города при первом заходе на «Главную».
  /// Без флага — показываем каждый раз (для теста).
  void _maybeShowCityHint({int attempt = 0}) async {
    if (_currentIndex != 0) return;
    if (attempt > 10) return;

    // Проверяем флаг — кошка уже показана?
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(CatCityHint.prefsKey) == true) return;

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      final rect = AppHeader.cityRect;
      if (rect == null || rect == Rect.zero || rect.width == 0 || rect.height == 0) {
        _maybeShowCityHint(attempt: attempt + 1);
        return;
      }
      CatCityHint.maybeShow(context, cityRect: rect);
    });
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    WidgetsBinding.instance.removeObserver(this);
    MainShell.tabNotifier.removeListener(_onExternalTabChange);
    try {
      context.read<AuthProvider>().removeListener(_onAuthChanged);
    } catch (_) {}
    DeepLinkService.instance.clearListener();
    ConnectivityService().dispose();
    ApiService.removeAvailabilityListener(_onAvailabilityChanged);
    ApiService.stopHealthCheck();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPushPermissionAfterSettings();
      _syncCartOnResume();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        PushService.processPendingLink(context);
      });
    }
  }

  /// Единая точка приёма ссылок — от push или от deep links.
  void _handleIncomingLink(String link) {
    if (!mounted || link.isEmpty) return;

    if (link.startsWith('/')) {
      link = 'https://xn--80abvyjk6cts.xn--p1ai$link';
    }

    if (link.startsWith('beautyrosha://')) {
      link = link.replaceFirst(
        'beautyrosha://',
        'https://xn--80abvyjk6cts.xn--p1ai/',
      );
    }

    final uri = Uri.tryParse(link);
    if (uri == null) {
      AppLogger.warning(_logTag, 'Failed to parse link: $link');
      return;
    }

    DeepLinkHandler.handleUri(uri);
  }

  /// Реакция на внешнее переключение вкладок.
  void _onExternalTabChange() {
    if (!mounted) return;
    final newIndex = MainShell.tabNotifier.value;
    if (newIndex == _currentIndex) return;
    _onTabChanged(newIndex);
  }

  Future<void> _syncCartOnResume() async {
    try {
      final cart = context.read<CartProvider>();
      await cart.syncFromServer();
    } catch (e) {
      AppLogger.warning(_logTag, 'syncCartOnResume failed', e);
    }
  }

  Future<void> _checkPushPermissionAfterSettings() async {
    try {
      final status = await PushPermissionService.getAuthorizationStatus();

      if (status == PushPermissionStatus.authorized ||
          status == PushPermissionStatus.provisional) {
        await PushPermissionService.setPermissionGranted(true);
      }
    } catch (e) {
      AppLogger.warning(_logTag, 'checkPushPermission failed', e);
    }
  }

  Future<void> _initApp() async {
    final menu = context.read<MenuProvider>();
    menu.onOpenCart = () => _onTabChanged(2);
    menu.onOpenProfile = () => _onTabChanged(3);
    menu.onGoHome = () => _onTabChanged(0);
    menu.onOpenNotifications = () {
      if (mounted) _openNotificationsWithCallback();
    };

    final authProvider = context.read<AuthProvider>();
    authProvider.addListener(_onAuthChanged);
    context.read<CartProvider>().listenToAuth(authProvider);

    try {
      final isAvailable = ApiService.isAvailable;

      if (!mounted) return;

      if (!isAvailable) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          NetworkErrorBanner.show(
            context,
            isBlocking: true,
            onRetry: () => _fullReload(),
          );
        });
        setState(() => _isInitialAuth = false);
        return;
      }

      // Параллельная инициализация — все операции одновременно
      await Future.wait([
        _safeRun(() => ApiService.loadCookies(), tag: 'loadCookies'),
        _safeRun(() => context.read<AuthProvider>().checkAuth(),
            tag: 'checkAuth'),
        _safeRun(() => context.read<CartProvider>().loadCartCount(),
            tag: 'loadCartCount'),
      ]);

      if (!mounted) return;

      // Recommendations грузим в фоне — не блокирует первый экран
      unawaited(_loadAllData());

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _checkAndShowPushDialog();

        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _checkAppVersion();
        });
      });
    } catch (e, st) {
      AppLogger.error(_logTag, '_initApp error', e, st);

      if (!mounted) return;

      final isBlocking = ApiService.isBlockingError(e);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        NetworkErrorBanner.show(
          context,
          isBlocking: isBlocking,
          onRetry: () => _fullReload(),
        );
      });

      _safeRun(() => context.read<AuthProvider>().checkAuth());
      _safeRun(() => context.read<CartProvider>().loadCartCount());

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _checkAndShowPushDialog();
      });
    }
  }

  Future<void> _safeRun(Future<void> Function() task, {String? tag}) async {
    try {
      await task();
    } catch (e) {
      AppLogger.warning(_logTag, tag ?? 'safeRun failed', e);
    }
  }

  Future<void> _loadAllData() async {
    // Ждём 500ms, чтобы первый кадр отрисовался без нагрузки сети
    await Future.delayed(const Duration(milliseconds: 500));
    await _safeRun(
      () => context.read<HomeRecommendationProvider>().loadRecommendations(),
      tag: 'loadRecommendations',
    );
    _initialLoadDone = true;
  }

  Future<void> _fullReload() async {
    if (!mounted) return;
    setState(() => _isInitialAuth = true);

    ApiService.clearCache();

    await Future.wait([
      _safeRun(() => context.read<AuthProvider>().checkAuth(),
          tag: 'reload:checkAuth'),
      _safeRun(() => context.read<CartProvider>().loadFullCart(),
          tag: 'reload:loadFullCart'),
      _safeRun(() => context.read<MenuProvider>().loadMenu(),
          tag: 'reload:loadMenu'),
      _safeRun(() => context.read<HomeRecommendationProvider>().refresh(),
          tag: 'reload:refreshRecommendations'),
    ]);

    if (!mounted) return;
    setState(() => _isInitialAuth = false);
  }

  Future<void> _checkAppVersion() async {
    final result =
        await ApiService.get('/api/app/version', forceRefresh: true);

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'app/version failed: ${result.errorOrNull?.message}',
      );
      return;
    }

    final response = result.valueOrNull;
    if (response == null || response['success'] != true) return;

    final data = (response['data'] as Map<String, dynamic>?) ?? {};
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    final minVersion = await _getMinVersionForPlatform(data);

    if (minVersion == null) return;
    if (!_isUpdateRequired(currentVersion, minVersion)) return;

    if (!mounted) return;
    await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'UpdateRequired',
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) {
        return const UpdateRequiredScreen();
      },
    );
  }

  Future<String?> _getMinVersionForPlatform(Map<String, dynamic> data) async {
    if (Platform.isIOS) {
      return data['min_version_ios'] as String? ??
          data['min_version'] as String?;
    }

    if (Platform.isAndroid) {
      final isRuStore = await _isRuStoreInstall();
      if (isRuStore) {
        return data['min_version_rustore'] as String? ??
            data['min_version_android'] as String? ??
            data['min_version'] as String?;
      }
      return data['min_version_android'] as String? ??
          data['min_version'] as String?;
    }

    return data['min_version'] as String?;
  }

  Future<bool> _isRuStoreInstall() async {
    try {
      const channel = MethodChannel('beautyrosha/installer');
      final installer =
          await channel.invokeMethod<String>('getInstallerPackage');
      if (installer == null || installer.isEmpty) return false;
      return installer.toLowerCase().contains('rustore') ||
          installer.toLowerCase().contains('ru.store');
    } catch (_) {
      return false;
    }
  }

  bool _isUpdateRequired(String current, String minimum) {
    try {
      final currentParts = current
          .split('+')
          .first
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      final minParts = minimum
          .split('+')
          .first
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();

      for (int i = 0; i < 3; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final m = i < minParts.length ? minParts[i] : 0;
        if (c < m) return true;
        if (c > m) return false;
      }
    } catch (_) {}
    return false;
  }

  Future<void> _checkAndShowPushDialog() async {
    try {
      final shouldShow = await PushPermissionService.shouldShowDialog();

      if (shouldShow && mounted) {
        await Future.delayed(const Duration(milliseconds: 800));

        if (!mounted) return;

        final result = await showGeneralDialog<PushDialogResult>(
          context: context,
          barrierDismissible: false,
          barrierLabel: 'PushPermissionDialog',
          barrierColor: Colors.transparent,
          transitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) {
            return const PushPermissionDialog();
          },
        );

        if (result == PushDialogResult.enable && mounted) {
          await PushPermissionService.openAppSettings();
        }
      }
    } catch (e) {
      AppLogger.warning(_logTag, 'checkAndShowPushDialog failed', e);
    }
  }

  Future<void> _openNotificationsWithCallback() async {
    await _navigatorKeys[_currentIndex].currentState?.push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (mounted) {
      context.read<NotificationProvider>().loadUnreadCount();
    }
  }

  void _onAuthChanged() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoading && auth.isLoggedIn) {
      _reloadProfileData();
      if (!_isInitialAuth) {
        _onTabChanged(3);
      }
      _isInitialAuth = false;
    }
  }

  Future<void> _reloadProfileData() async {
    await Future.wait([
      _safeRun(() => context.read<RateableProvider>().loadRateable(),
          tag: 'reloadProfile:rateable'),
    ]);
  }

  void _onTabChanged(int index) {
    _visitedTabs.add(index);
    if (!mounted) return;

    final menu = context.read<MenuProvider>();
    final catalog = context.read<CatalogProvider>();

    if (index == _currentIndex && index != 1) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      // Повторный тап на «Профиль» — тоже refresh
      if (index == 3) {
        context.read<ProfileRefreshProvider>().requestRefresh();
      }
    }


    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
      if (MainShell.tabNotifier.value != index) {
        MainShell.tabNotifier.value = index;
      }
    }

    switch (index) {
      case 0:
        menu.close();
        if (catalog.categoryId != null || catalog.brand != null) {
          catalog.resetFilters();
        }
        break;
      case 1:
        // 🔥 Загружаем меню только если данных нет (или устарело)
        if (menu.data == null) {
          menu.loadMenu();
        }
        break;
      case 2:
        menu.close();
        final cart = context.read<CartProvider>();
        if (!cart.isFullyLoaded && cart.items.isNotEmpty) {
          cart.loadFullCart();
        }
        break;
      case 3:
        menu.close();
        // Профиль: запрашиваем перезагрузку статистики
        // (для активации карты / pull-to-refresh / возврата на вкладку)
        context.read<ProfileRefreshProvider>().requestRefresh();
        break;
    }
  }

  Widget _buildTabPage(int index) {
    switch (index) {
      case 0:
        return HomeScreen(key: _homeKey);
      case 1:
        return _buildMenuTab();
      case 2:
        return CartScreen(key: _cartKey);
      case 3:
        return ProfileScreen(key: _profileKey);
      default:
        return const HomeScreen();
    }
  }

  Widget _buildMenuTab() {
    return Consumer<MenuProvider>(
      builder: (context, menu, _) {
        if (menu.isLoading || !menu.isMenuReady) {
          return Container(
              color: context.colors.surface,
              child: Center(
                  child: CircularProgressIndicator(
                      color: context.colors.brand)));
        }
        if (menu.data == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            menu.loadMenu();
          });
          return Container(
              color: context.colors.surface,
              child: Center(
                  child: Text('Меню недоступно',
                      style: TextStyle(color: context.colors.textMuted))));
        }
        if (menu.data!.banners.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            menu.loadBanners(); // 🔥 только баннеры (без isLoading)
          });
        }
        return MobileMenu(
          menuData: menu.data!,
          isIconsPreloading: menu.isIconsPreloading,
          onNotificationsTap: () {
            menu.onOpenNotifications?.call();
          },
        );
      },
    );
  }

  /// 🔥 Предзагрузка иконок категорий и баннеров (при старте приложения)
  void _precacheMenuIcons() {
    Future.delayed(const Duration(milliseconds: 100), () async {
      if (!mounted) return;
      try {
        final menu = context.read<MenuProvider>();
        final categories = menu.data?.categories ?? [];
        final cacheManager = DefaultCacheManager();

        // 🔥 1. Загружаем иконки (диск + RAM + ImageCache)
        final iconFutures = <Future<void>>[];
        for (final cat in categories) {
          final url = cat.iconUrl ?? cat.imageUrl ?? '';
          if (url.isEmpty) continue;
          final fullUrl = CdnService.imageUrl(url);
          iconFutures.add(() async {
            try {
              final file = await cacheManager.getSingleFile(fullUrl);
              final bytes = await file.readAsBytes();
              ImageMemoryCache().put(fullUrl, bytes);
              if (mounted) await precacheImage(NetworkImage(fullUrl), context);
            } catch (_) {}
          }());
        }
        await Future.wait(iconFutures);

        // 🔥 2. Загружаем баннеры (диск + RAM + ImageCache)
        final bannersData = await MobileMenuService.getMenuData();
        final banners = bannersData.banners;
        final bannerFutures = <Future<void>>[];
        for (final banner in banners) {
          final url = banner.imageUrl;
          if (url.isEmpty) continue;
          final fullUrl = CdnService.imageUrl(url);
          bannerFutures.add(() async {
            try {
              final file = await cacheManager.getSingleFile(fullUrl);
              final bytes = await file.readAsBytes();
              ImageMemoryCache().put(fullUrl, bytes);
              if (mounted) await precacheImage(NetworkImage(fullUrl), context);
            } catch (_) {}
          }());
        }
        await Future.wait(bannerFutures);
        
        // 🔥 Обновляем баннеры в MenuProvider (чтобы loadBanners не вызывался)
        menu.setBanners(banners);

        // 🔥 3. Меню готово
        menu.setMenuReady(true);
      } catch (e) {
        // ignore: empty_catches
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    if (_currentIndex == 0) _maybeShowCityHint();
    return Scaffold(
      extendBody: true,

      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(4, (index) {
          // Lazy: создаём Navigator только если таб был посещён (или текущий)
          if (!_visitedTabs.contains(index) && index != _currentIndex) {
            return const SizedBox.shrink();
          }
          return Navigator(
            key: _navigatorKeys[index],
            onGenerateRoute: (settings) {
              return MaterialPageRoute(builder: (_) => _buildPage(index));
            },
          );
        }),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: BottomNav(
            currentIndex: _currentIndex,
            onTap: _onTabChanged,
            cartCount: cart.totalCount),
      ),
    );
  }

  Widget _buildPage(int index) {
    return _buildTabPage(index);
  }
}


class _ReviewPromptSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Эмодзи-звёзды
              const Text(
                '★★★★★',
                style: TextStyle(
                  fontSize: 36,
                  color: Color(0xFFFFB800),
                  letterSpacing: 4,
                  height: 1,
                ),
              ),
              const SizedBox(height: 20),
              // Заголовок
              const Text(
                'Оцените Б•Рощу',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1C1E),
                  letterSpacing: -0.6,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              // Подзаголовок
              const Text(
                'Это займёт 10 секунд и поможет нам стать лучше',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF8E8E93),
                  height: 1.4,
                  letterSpacing: -0.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Кнопка «Оценить»
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1C1E),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Оценить',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Кнопка «Не сейчас»
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 0),
                ),
                child: const Text(
                  'Не сейчас',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
