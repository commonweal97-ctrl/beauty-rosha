// lib/main.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/app_logger.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/recommendation_provider.dart';
import 'providers/city_provider.dart';
import 'providers/wishlist_provider.dart';
import 'providers/waitlist_provider.dart';
import 'providers/favorite_brands_provider.dart';
import 'providers/banner_provider.dart';
import 'providers/menu_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/checkout_provider.dart';
import 'providers/user_provider.dart';
import 'providers/order_refresh_provider.dart';
import 'providers/rateable_provider.dart';
import 'providers/bonus_provider.dart';
import 'providers/theme_provider.dart';
import 'services/api_service.dart';
import 'services/cdn_service.dart';
import 'services/deep_link_handler.dart';
import 'services/deep_link_service.dart';
import 'services/image_error_handler.dart';
import 'services/push_service.dart';
import 'services/smart_image_loader.dart';
import 'screens/main_shell.dart';
import 'core/app_theme.dart';

const _logTag = 'main';

/// Глобальный ключ навигатора.
/// Используется для deep links, push-уведомлений и любых переходов
/// вне widget tree.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appStartTime = DateTime.now();
  AppLogger.info(_logTag, 'Старт приложения');

  ImageErrorHandler.init();

  // Firebase — параллельно, не блокируем старт
  unawaited(() async {
    try {
      await Firebase.initializeApp();
      AppLogger.info(
        _logTag,
        'Firebase инициализирован '
        '(${DateTime.now().difference(appStartTime).inMilliseconds} мс)',
      );
    } catch (e) {
      AppLogger.warning(_logTag, 'Firebase init failed', e);
    }
  }());

  // НЕ блокируем старт приложения из-за FCM — токен получим в фоне.
  // На Android при недоступном FIS getToken() может висеть 10+ секунд.
  unawaited(() async {
    try {
      final fcmToken = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 5));
      AppLogger.info(_logTag, 'FCM token: $fcmToken');
    } catch (e) {
      AppLogger.warning(_logTag, 'getToken failed', e);
    }
  }());

  SmartImageLoader();

  if (!kDebugMode) {
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await ApiService.init();
  CdnService.init();

  // Deep links — параллельно (не блокируем UI)
  unawaited(DeepLinkService.instance.init());

  // Push сервис — параллельно (может висеть на Android 13+)
  unawaited(PushService().init());

  // Не блокируем UI на appInit. Запускаем его в фоне, а runApp
  // вызываем сразу. UI сам дозапросит данные, если init не успел.
  final initCompleter = Completer<Map<String, dynamic>?>();

  unawaited(() async {
    try {
      final result = await ApiService.appInit();
      Map<String, dynamic>? data;
      result
          .onSuccess((response) {
            data = response;
            AppLogger.info(
              _logTag,
              'appInit завершён '
              '(${DateTime.now().difference(appStartTime).inMilliseconds} мс)',
            );
          })
          .onFailure((error) {
            AppLogger.warning(_logTag, 'appInit failed: ${error.message}');
          });
      if (!initCompleter.isCompleted) initCompleter.complete(data);
    } catch (e, st) {
      AppLogger.error(_logTag, 'appInit crashed', e, st);
      if (!initCompleter.isCompleted) initCompleter.complete(null);
    }
  }());

  // Ждём appInit максимум 1 секунду — иначе стартуем с дефолтами.
  // Данные дозагрузятся параллельно (banners, recommendations).
  Map<String, dynamic>? initPayload;
  try {
    initPayload =
        await initCompleter.future.timeout(const Duration(seconds: 1));
  } catch (_) {
    AppLogger.warning(_logTag, 'appInit timeout (1s), стартуем с дефолтами');
    initPayload = null;
  }

  final currencyProvider = CurrencyProvider();

  if (initPayload != null &&
      initPayload['success'] == true &&
      initPayload['data'] is Map) {
    final data = initPayload['data'] as Map<String, dynamic>;
    currencyProvider.setFromInit(data['currency'] ?? 'RUB');
    unawaited(currencyProvider.init());
  } else {
    unawaited(currencyProvider.init());
  }

  AppLogger.info(
    _logTag,
    'Готово к запуску '
    '(${DateTime.now().difference(appStartTime).inMilliseconds} мс)',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => CatalogProvider()),
        ChangeNotifierProvider.value(value: currencyProvider),
        ChangeNotifierProvider(create: (_) => HomeRecommendationProvider()),
        ChangeNotifierProvider(create: (_) => ProfileRecommendationProvider()),
        ChangeNotifierProvider(create: (_) => CartRecommendationProvider()),
        ChangeNotifierProvider(create: (_) => BonusProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = CityProvider();
            if (initPayload != null &&
                initPayload['success'] == true &&
                initPayload['data'] is Map) {
              final data = initPayload['data'] as Map<String, dynamic>;
              provider.setFromInit(
                data['city'] ?? 'Брянск',
                data['country'] ?? 'Россия',
              );
            }
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = WishlistProvider();
            if (initPayload != null &&
                initPayload['success'] == true &&
                initPayload['data'] is Map) {
              final data = initPayload['data'] as Map<String, dynamic>;
              if (data['wishlist_count'] != null) {
                provider.setInitialCount(data['wishlist_count'] as int);
              }
            }
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = WaitlistProvider();
            if (initPayload != null &&
                initPayload['success'] == true &&
                initPayload['data'] is Map) {
              final data = initPayload['data'] as Map<String, dynamic>;
              if (data['waitlist_count'] != null) {
                provider.setInitialCount(data['waitlist_count'] as int);
              }
            }
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = FavoriteBrandsProvider();
            if (initPayload != null &&
                initPayload['success'] == true &&
                initPayload['data'] is Map) {
              final data = initPayload['data'] as Map<String, dynamic>;
              if (data['favorite_brands_count'] != null) {
                provider.setInitialCount(
                  data['favorite_brands_count'] as int,
                );
              }
            }
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = BannerProvider();
            if (initPayload != null &&
                initPayload['success'] == true &&
                initPayload['data'] is Map) {
              final data = initPayload['data'] as Map<String, dynamic>;
              if (data['banners'] is List &&
                  (data['banners'] as List).isNotEmpty) {
                provider.setFromInit(
                  List<Map<String, dynamic>>.from(data['banners']),
                );
              }
            }
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = MenuProvider();
            if (initPayload != null &&
                initPayload['success'] == true &&
                initPayload['data'] is Map) {
              final data = initPayload['data'] as Map<String, dynamic>;
              if (data['menu'] is List && (data['menu'] as List).isNotEmpty) {
                provider.setFromInit(
                  List<Map<String, dynamic>>.from(data['menu']),
                );
              }
            }
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = NotificationProvider();
            if (initPayload != null &&
                initPayload['success'] == true &&
                initPayload['data'] is Map) {
              final data = initPayload['data'] as Map<String, dynamic>;
              if (data['unread_notifications'] != null) {
                provider.setUnreadCount(
                  data['unread_notifications'] as int,
                );
              }
            }
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => CheckoutProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => OrderRefreshProvider()),
        ChangeNotifierProvider(create: (_) => RateableProvider()),
      ],
      child: const BeautyRoshaApp(),
    ),
  );

  FirebaseAnalytics.instance.logAppOpen();
}

class BeautyRoshaApp extends StatefulWidget {
  const BeautyRoshaApp({super.key});

  @override
  State<BeautyRoshaApp> createState() => _BeautyRoshaAppState();
}

class _BeautyRoshaAppState extends State<BeautyRoshaApp> {
  @override
  void initState() {
    super.initState();
    _markAppInstalled();
  }

  Future<void> _markAppInstalled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyMarked = prefs.getBool('app_installed_marked') ?? false;
      if (alreadyMarked) return;

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final authProvider = context.read<AuthProvider>();
      if (!authProvider.isLoggedIn) return;

      final result =
          await ApiService.post('/api/user/mark-app-installed', {});

      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'mark-app-installed failed: ${result.errorOrNull?.message}',
        );
        return;
      }

      await prefs.setBool('app_installed_marked', true);
    } catch (e, st) {
      AppLogger.error(_logTag, 'markAppInstalled failed', e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Б-Роща',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      
      // Глобальный system overlay — статус-бар и нижняя навигация
      // меняют цвет в зависимости от темы
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
            statusBarBrightness:
                isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          ),
          child: child!,
        );
      },

      // Flutter-движок iOS/Android может передать URL напрямую в
      // навигатор (например, `beautyrosha://product/foo` превращается
      // в `RouteSettings("/foo")`). Перехватываем и отдаём в
      // DeepLinkHandler, чтобы избежать "Could not find a generator".
      onGenerateRoute: _handleEngineRoute,

      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: context.watch<ThemeProvider>().mode,
      home: const MainShell(),
    );
  }

  /// Перехватывает URL-ы, которые Flutter-движок передаёт напрямую.
  /// Например, `beautyrosha://product/foo` приходит как `RouteSettings("/foo")`
  /// без префикса `product`. Восстанавливаем правильный URL и передаём
  /// в DeepLinkHandler. Возвращаем заглушку, чтобы Flutter не падал с
  /// "Could not find a generator for route".
  static Route<dynamic>? _handleEngineRoute(RouteSettings settings) {
    final name = settings.name ?? '';
    if (name.isEmpty || name == '/') return null;

    final isKnownPrefix = name.startsWith('/product/') ||
        name.startsWith('/catalog') ||
        name.startsWith('/cart') ||
        name.startsWith('/profile') ||
        name.startsWith('/search');

    final normalized = isKnownPrefix
        ? 'https://xn--80abvyjk6cts.xn--p1ai$name'
        : 'https://xn--80abvyjk6cts.xn--p1ai/product$name';

    final uri = Uri.parse(normalized);

    Future.microtask(() => DeepLinkHandler.handleUri(uri));

    return MaterialPageRoute(
      builder: (_) => const SizedBox.shrink(),
    );
  }
}