// lib/screens/main_shell.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
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
import '../widgets/bottom_nav.dart';
import '../widgets/mobile_menu.dart';
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

  late final PageController _pageController;

  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  final Key _homeKey = const ValueKey('home_tab');
  final Key _cartKey = const ValueKey('cart_tab');
  final Key _profileKey = const ValueKey('profile_tab');

  void _onAvailabilityChanged(bool isAvailable, bool isBlocking) {
    if (!mounted) return;
    if (isAvailable) {
      _fullReload();
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

    _instance = this;

    _pageController = PageController(initialPage: _currentIndex);

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
    _pageController.dispose();
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

    if (_pageController.hasClients) {
      _pageController.jumpToPage(index);
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
        context.read<MenuProvider>().loadMenu();
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
        if (menu.isLoading) {
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
            menu.loadMenu();
          });
        }
        return MobileMenu(menuData: menu.data!, onNotificationsTap: () {
          menu.onOpenNotifications?.call();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      extendBody: true,

      body: PageView.builder(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        onPageChanged: (index) {
          _onTabChanged(index);
        },
        itemBuilder: (context, index) {
          return Navigator(
            key: _navigatorKeys[index],
            onGenerateRoute: (settings) {
              return MaterialPageRoute(builder: (_) => _buildPage(index));
            },
          );
        },
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