// lib/widgets/app_header.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/bonus_provider.dart';
import '../providers/city_provider.dart';
import '../providers/notification_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/catalog/search_screen.dart';
import '../screens/main_shell.dart';
import '../screens/notifications/notifications_screen.dart';
import '../services/api_service.dart';
import 'bonus_history_popup.dart';
import 'city_picker.dart';
import '../core/app_colors.dart';

class AppHeader extends StatefulWidget {
  final double scrollOffset;

  const AppHeader({super.key, this.scrollOffset = 0});

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> with TickerProviderStateMixin {
  bool _isInitialized = false;
  bool? _lastAuthState;

  // Анимация бонусов
  AnimationController? _bonusAnimController;
  Animation<double>? _bonusAnimation;
  int _displayBonus = 0;
  bool _bonusAnimationStarted = false;

  @override
  void initState() {
    super.initState();

    _bonusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _bonusAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _bonusAnimController!,
        curve: Curves.easeOutCubic,
      ),
    );

    _loadUnreadCount();
    _loadBonusBalance();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) {
      _loadUnreadCount();
    }

    final auth = context.read<AuthProvider>();
    if (_lastAuthState != null && _lastAuthState != auth.isLoggedIn) {
      _bonusAnimationStarted = false;
      _loadBonusBalance();
    }
    _lastAuthState = auth.isLoggedIn;
  }

  Future<void> _loadUnreadCount() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;

    await context.read<NotificationProvider>().loadUnreadCount();
    _isInitialized = true;
  }

  Future<void> _loadBonusBalance() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;

    await ApiService.loadCookies();
    if (!mounted) return;

    await context.read<BonusProvider>().loadBalance();
    if (!mounted) return;

    if (!_bonusAnimationStarted) {
      _bonusAnimationStarted = true;
      _displayBonus = 0;

      final targetBalance = context.read<BonusProvider>().balance;

      _bonusAnimController!.forward(from: 0);

      _bonusAnimation!.addListener(() {
        if (mounted) {
          setState(() {
            _displayBonus =
                (targetBalance * _bonusAnimation!.value).round();
          });
        }
      });
    }
  }

  double get _progress => (widget.scrollOffset / 100).clamp(0.0, 1.0);

  void _openCityPicker() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => CityPicker(
        onSelect: (city, country) {
          context.read<CityProvider>().setCity(city, country);
        },
      ),
    );
  }

  void _openBonusHistory() {
    BonusHistoryPopup.show(context);
  }

  void _openSearch() {
    MainShell.push(context, const SearchScreen());
  }

  Future<void> _openNotifications() async {
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      MainShell.push(context, const LoginScreen());
      return;
    }

    final navigator = Navigator.of(context, rootNavigator: true);

    await navigator.push(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => const NotificationsScreen(),
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (_, animation, _, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          final offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        settings: const RouteSettings(name: '/notifications'),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  void dispose() {
    _bonusAnimController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    final city = context.watch<CityProvider>().city;
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            p > 0.5 ? Brightness.dark : Brightness.light,
        statusBarBrightness:
            p > 0.5 ? Brightness.light : Brightness.dark,
      ),
      child: ClipRRect(
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(
                    context.colors.error,
                    Colors.white.withValues(alpha: 0.85),
                    p,
                  )!,
                  Color.lerp(
                    context.colors.brand,
                    Colors.white.withValues(alpha: 0.85),
                    p,
                  )!,
                  Color.lerp(
                    context.colors.brandDark,
                    Colors.white.withValues(alpha: 0.85),
                    p,
                  )!,
                ],
              ),
              border: Border.all(
                color: Color.lerp(
                  context.colors.brand.withValues(alpha: 0.4),
                  Colors.white.withValues(alpha: 0.8),
                  p,
                )!,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(
                    context.colors.brand.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.08),
                    p,
                  )!,
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              top: true,
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    height: p < 0.5 ? 32 : 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: p < 0.5 ? 1.0 - p * 2 : 0.0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _openCityPicker,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    city,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color.lerp(
                                        Colors.white,
                                        context.colors.textPrimary,
                                        p,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Color.lerp(
                                      Colors.white70,
                                      context.colors.textSecondary,
                                      p,
                                    ),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            if (isLoggedIn)
                              Consumer<BonusProvider>(
                                builder: (context, bonusProvider, _) {
                                  return GestureDetector(
                                    onTap: bonusProvider.isLoaded
                                        ? _openBonusHistory
                                        : null,
                                    child: Container(
                                      height: 32,
                                      width: 75,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.08,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: bonusProvider.isLoaded
                                            ? Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  Transform.rotate(
                                                    angle: -0.15,
                                                    child: SvgPicture.asset(
                                                      'assets/icons/bonus-logo.svg',
                                                      width: 16,
                                                      height: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 5),
                                                  Flexible(
                                                    child: Text(
                                                      '$_displayBonus',
                                                      style:
                                                          const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Color(
                                                          0xFFDD1847,
                                                        ),
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .visible,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: const Color(
                                                          0xFFDD1847)
                                                      .withValues(alpha: 0.5),
                                                ),
                                              ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            const SizedBox(width: 6),
                            Consumer<NotificationProvider>(
                              builder: (context, notif, child) {
                                final unreadCount = notif.unreadCount;
                                return GestureDetector(
                                  onTap: _openNotifications,
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: unreadCount > 0
                                          ? Color.lerp(
                                              Colors.white
                                                  .withValues(alpha: 0.25),
                                              context.colors.brand
                                                  .withValues(alpha: 0.1),
                                              p,
                                            )
                                          : Colors.transparent,
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.center,
                                      children: [
                                        SvgPicture.asset(
                                          'assets/icons/kolokol.svg',
                                          width: 22,
                                          height: 22,
                                          colorFilter: ColorFilter.mode(
                                            Color.lerp(
                                              Colors.white,
                                              context.colors.textPrimary,
                                              p,
                                            )!,
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                        if (unreadCount > 0)
                                          Positioned(
                                            top: -8,
                                            right: -4,
                                            child: Container(
                                              width: 16,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                color:
                                                    Color(0xFFFF3B30),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Color.lerp(
                                                    context.colors.brand,
                                                    Colors.white,
                                                    p,
                                                  )!,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  unreadCount > 99
                                                      ? '99'
                                                      : '$unreadCount',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                    child: GestureDetector(
                      onTap: _openSearch,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Color.lerp(
                            Colors.white,
                            Colors.white.withValues(alpha: 0.9),
                            p,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Color.lerp(
                              Colors.white.withValues(alpha: 0.5),
                              const Color(0xFFEEEEEE),
                              p,
                            )!,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: 16),
                            SvgPicture.asset(
                              'assets/icons/search.svg',
                              width: 28,
                              height: 28,
                              colorFilter: ColorFilter.mode(
                                Color.lerp(
                                  context.colors.brand,
                                  context.colors.error,
                                  p,
                                )!,
                                BlendMode.srcIn,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Поиск товаров',
                              style: TextStyle(
                                color: Color.lerp(
                                  Color(0xFFFFB3C1),
                                  context.colors.brand,
                                  p,
                                ),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}