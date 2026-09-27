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
import 'services/api_service.dart';
import 'services/cdn_service.dart';
import 'services/deep_link_handler.dart';
import 'services/deep_link_service.dart';
import 'services/image_error_handler.dart';
import 'services/push_service.dart';
import 'services/smart_image_loader.dart';
import 'screens/main_shell.dart';

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

  await Firebase.initializeApp();
  AppLogger.info(
    _logTag,
    'Firebase инициализирован '
    '(${DateTime.now().difference(appStartTime).inMilliseconds} мс)',
  );

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

  // Deep links должны быть подписаны до runApp — чтобы не потерять
  // cold start ссылку.
  await DeepLinkService.instance.init();

  // Push сервис идемпотентен: повторный init() — no-op.
  await PushService().init();

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

  // Ждём appInit максимум 5 секунд — иначе стартуем с дефолтами.
  Map<String, dynamic>? initPayload;
  try {
    initPayload =
        await initCompleter.future.timeout(const Duration(seconds: 5));
  } catch (_) {
    AppLogger.warning(_logTag, 'appInit timeout (5s), стартуем с дефолтами');
    initPayload = null;
  }

  final currencyProvider = CurrencyProvider();

  if (initPayload != null &&
      initPayload['success'] == true &&
      initPayload['data'] is Map) {
    final data = initPayload['data'] as Map<String, dynamic>;
    currencyProvider.setFromInit(data['currency'] ?? 'RUB');
    await currencyProvider.init();
  } else {
    await currencyProvider.init();
  }

  AppLogger.info(
    _logTag,
    'Готово к запуску '
    '(${DateTime.now().difference(appStartTime).inMilliseconds} мс)',
  );

  runApp(
    MultiProvider(
      providers: [
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

      // Flutter-движок iOS/Android может передать URL напрямую в
      // навигатор (например, `beautyrosha://product/foo` превращается
      // в `RouteSettings("/foo")`). Перехватываем и отдаём в
      // DeepLinkHandler, чтобы избежать "Could not find a generator".
      onGenerateRoute: _handleEngineRoute,

      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        fontFamilyFallback: const ['.SF UI Display', 'Roboto'],
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.3),
          displaySmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.45),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3),
          labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.2),
          labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.1),
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFDD1847),
          primary: const Color(0xFFDD1847),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFDD1847),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDD1847),
            foregroundColor: Colors.white,
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8F9FA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            borderSide: const BorderSide(color: Color(0xFFDD1847), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1),
          ),
          hintStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFFDD1847),
          unselectedItemColor: Color(0xFF999999),
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: const Color(0xFFDD1847),
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFFECECF0), thickness: 1),
      ),
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