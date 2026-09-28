// lib/screens/profile/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_colors.dart';
import '../../core/app_logger.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/recommendation_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/common/index.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import 'notifications_screen.dart';
import 'security_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _logTag = 'SettingsScreen';

  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadUserData();
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
    });
  }

  Future<void> _setCurrency(String currency) async {
    await context.read<CurrencyProvider>().setCurrency(currency);
    if (!mounted) return;
    context.read<CatalogProvider>().refreshProducts();
    context.read<CartProvider>().loadFullCart();
    context.read<HomeRecommendationProvider>().refresh();
  }

  Future<void> _toggleVibration(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibration_enabled', value);
    if (!mounted) return;
    setState(() => _vibrationEnabled = value);
  }

  String _currencySymbol(String code) {
    switch (code) {
      case 'RUB':
        return '₽';
      case 'BYN':
        return '\u{E901}';
      case 'KZT':
        return '₸';
      default:
        return code;
    }
  }

  bool _isCustomFont(String code) => code == 'BYN';

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        filled: true,
        fillColor: context.colors.surfaceAlt,
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
          borderSide: BorderSide(
            color: context.colors.brand,
            width: 1.5,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      );

  void _showEmailDialog() {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    String? error;
    bool codeSent = false;
    bool isVerifying = false;
    final currentEmail = context.read<UserProvider>().email;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Изменение email',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Текущий: $currentEmail',
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              SizedBox(height: 24),
              if (!codeSent) ...[
                Text(
                  'Введите новый email',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textSecondary,
                  ),
                ),
                SizedBox(height: 8),
              ],
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !codeSent,
                style: TextStyle(fontSize: 16),
                decoration: _inputDecoration('new@email.ru'),
              ),
              if (codeSent) ...[
                SizedBox(height: 20),
                Text(
                  'Введите код подтверждения',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  style: const TextStyle(fontSize: 16, letterSpacing: 4),
                  textAlign: TextAlign.center,
                  decoration: _inputDecoration('000000')
                      .copyWith(counterText: ''),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Color(0xFF856404),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Код отправлен на указанный email',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF856404),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final newEmail = emailController.text.trim();
                          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(newEmail)) {
                            setSheetState(
                              () => error = 'Введите корректный email',
                            );
                            return;
                          }
                          if (newEmail == currentEmail) {
                            setSheetState(
                              () => error = 'Это ваш текущий email',
                            );
                            return;
                          }
                          setSheetState(() {
                            isVerifying = true;
                            error = null;
                          });

                          try {
                            if (!codeSent) {
                              final result = await ApiService.post(
                                '/api/user/change-email',
                                {'email': newEmail},
                              );

                              if (result.isFailure) {
                                AppLogger.warning(
                                  _logTag,
                                  'change-email (send code) failed: '
                                      '${result.errorOrNull?.message}',
                                );
                                setSheetState(() {
                                  error = result.errorOrNull?.userMessage ??
                                      'Ошибка. Попробуйте позже';
                                  isVerifying = false;
                                });
                                return;
                              }

                              setSheetState(() {
                                codeSent = true;
                                isVerifying = false;
                              });
                            } else {
                              final code = codeController.text.trim();
                              if (code.length != 6) {
                                setSheetState(() {
                                  error = 'Введите 6-значный код';
                                  isVerifying = false;
                                });
                                return;
                              }
                              final result = await ApiService.post(
                                '/api/user/change-email',
                                {'email': newEmail, 'code': code},
                              );

                              if (result.isFailure) {
                                AppLogger.warning(
                                  _logTag,
                                  'change-email (verify) failed: '
                                      '${result.errorOrNull?.message}',
                                );
                                setSheetState(() {
                                  error = result.errorOrNull?.userMessage ??
                                      'Неверный код';
                                  isVerifying = false;
                                });
                                return;
                              }

                              if (mounted) {
                                context
                                    .read<UserProvider>()
                                    .updateEmail(newEmail);
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                            }
                          } catch (e, st) {
                            AppLogger.error(
                              _logTag,
                              'change-email unexpected error',
                              e,
                              st,
                            );
                            setSheetState(() {
                              error = 'Ошибка соединения';
                              isVerifying = false;
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isVerifying
                        ? '...'
                        : codeSent
                            ? 'Подтвердить'
                            : 'Отправить код',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

    Future<void> _clearCache() async {
    if (!mounted) return;

    final navigator = Navigator.of(context, rootNavigator: true);
    final messenger = ScaffoldMessenger.of(context);
    final authProvider = context.read<AuthProvider>();

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => Center(
        child: CircularProgressIndicator(color: context.colors.brand),
      ),
    );

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove('cached_orders_data');
      await prefs.remove('cached_orders_timestamp');
      await prefs.remove('cached_cart_count');
      await prefs.remove('cached_qr_card');

      if (!authProvider.isLoggedIn) {
        await prefs.remove('guest_cart_items');
      }

      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Кэш успешно очищен'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: context.colors.success,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e, st) {
      AppLogger.error(_logTag, 'clearCache failed', e, st);
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Не удалось очистить кэш'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Очистка кэша',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Будут удалены сохранённые данные заказов, корзины и изображений. Это может ускорить работу приложения.',
          style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: TextStyle(color: context.colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _clearCache();
            },
            child: Text(
              'Очистить',
              style: TextStyle(
                color: context.colors.brand,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final authUser = context.watch<AuthProvider>().user;
    final currencyProvider = context.watch<CurrencyProvider>();
    final initials = (authUser.name ?? 'К').substring(0, 1).toUpperCase();
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: topPadding + 48),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      top: 24,
                      bottom: bottomPadding + 32,
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          child: AppCard.large(
                            child: Column(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: context.colors.brandLight,
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: Center(
                                    child: Text(
                                      initials,
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        color: context.colors.brand,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  authUser.name ?? 'Пользователь',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.phone_android_outlined,
                                        size: 20,
                                        color: context.colors.textMuted,
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: userProvider.isLoading
                                            ? _buildShimmer()
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  Text(
                                                    userProvider
                                                            .phone.isNotEmpty
                                                        ? userProvider.phone
                                                        : 'Не указан',
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      color: context.colors.textPrimary,
                                                    ),
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    'Смена через поддержку',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: context.colors.textMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 8),
                                GestureDetector(
                                  onTap: _showEmailDialog,
                                  child: Container(
                                    width: double.infinity,
                                    padding:
                                        EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.colors.surfaceAlt,
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.email_outlined,
                                          size: 20,
                                          color: context.colors.textMuted,
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: userProvider.isLoading
                                              ? _buildShimmer()
                                              : Text(
                                                  userProvider
                                                          .email.isNotEmpty
                                                      ? userProvider.email
                                                      : 'Не указан',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: context.colors.textPrimary,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                        ),
                                        SizedBox(width: 8),
                                        Icon(
                                          Icons.chevron_right,
                                          size: 18,
                                          color: context.colors.textDisabled,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: _showClearCacheDialog,
                              icon: Icon(
                                Icons.cleaning_services_outlined,
                                size: 20,
                              ),
                              label: Text(
                                'Очистить кэш',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.colors.brand,
                                side: BorderSide(
                                  color: context.colors.brand,
                                  width: 1.5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                backgroundColor: context.colors.surface,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          child: AppCard.flat(
                            child: AppListTile(
                              title: 'Уведомления',
                              subtitle:
                                  'Выберите, какие хотите получать',
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const NotificationsScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          child: AppCard.flat(
                            child: Column(
                              children: [
                                AppListTile(
                                  title: 'Валюта',
                                  subtitle: 'Выберите валюту',
                                  trailing: Text(
                                    _currencySymbol(
                                      currencyProvider.currency,
                                    ),
                                    style: TextStyle(
                                      fontSize: _isCustomFont(
                                        currencyProvider.currency,
                                      )
                                          ? 22
                                          : 16,
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.brand,
                                      fontFamily: _isCustomFont(
                                        currencyProvider.currency,
                                      )
                                          ? 'NBRB'
                                          : null,
                                    ),
                                  ),
                                  onTap: () => _showCurrencyPicker(),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: AppCard.flat(
                            child: AppListTile(
                              title: 'Тема оформления',
                              subtitle: 'Системная, светлая или тёмная',
                              trailing: SegmentedButton<ThemeMode>(
                                segments: const [
                                  ButtonSegment(
                                    value: ThemeMode.system,
                                    icon: Icon(Icons.brightness_auto, size: 16),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.light,
                                    icon: Icon(Icons.light_mode, size: 16),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.dark,
                                    icon: Icon(Icons.dark_mode, size: 16),
                                  ),
                                ],
                                selected: {
                                  context.watch<ThemeProvider>().mode,
                                },
                                onSelectionChanged: (modes) {
                                  context
                                      .read<ThemeProvider>()
                                      .setMode(modes.first);
                                },
                                showSelectedIcon: false,
                                style: const ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          child: AppCard.flat(
                            child: AppListTile(
                              title: 'Безопасность',
                              subtitle:
                                  'Управление входом, пин-код, пароль',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SecurityScreen(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          child: AppCard.flat(
                            child: Column(
                              children: [
                                AppListTile(
                                  title: 'Вибрация',
                                  subtitle:
                                      'Телефон будет реагировать вибрацией на важные события',
                                  trailing: Switch(
                                    value: _vibrationEnabled,
                                    onChanged: _toggleVibration,
                                    activeThumbColor:
                                        context.colors.brand,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () async {
                                await context
                                    .read<AuthProvider>()
                                    .logout();
                                if (context.mounted) {
                                  Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          LoginScreen(),
                                    ),
                                    (route) => false,
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.colors.brand,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Выйти из профиля',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: TextButton(
                              onPressed: _showDeleteConfirmation,
                              style: TextButton.styleFrom(
                                foregroundColor: context.colors.textMuted,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Удалить профиль',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: Container(
                padding: EdgeInsets.only(top: topPadding, bottom: 4),
                color: context.colors.surface,
                child: Row(
                  children: [
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: context.colors.brand,
                        size: 22,
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Настройки',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return Container(
      height: 14,
      width: 150,
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  void _showCurrencyPicker() {
    final currencyProvider = context.read<CurrencyProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Выберите валюту',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _CurrencyOption(
              currency: 'RUB',
              symbol: '₽',
              label: 'Российский рубль',
              isSelected: currencyProvider.currency == 'RUB',
              onTap: () {
                _setCurrency('RUB');
                Navigator.pop(ctx);
              },
            ),
            _CurrencyOption(
              currency: 'BYN',
              symbol: '\u{E901}',
              label: 'Белорусский рубль',
              isSelected: currencyProvider.currency == 'BYN',
              useCustomFont: true,
              onTap: () {
                _setCurrency('BYN');
                Navigator.pop(ctx);
              },
            ),
            _CurrencyOption(
              currency: 'KZT',
              symbol: '₸',
              label: 'Казахстанский тенге',
              isSelected: currencyProvider.currency == 'KZT',
              onTap: () {
                _setCurrency('KZT');
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Удаление профиля',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить профиль? Это действие нельзя отменить.',
          style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: TextStyle(color: context.colors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: Text(
              'Удалить',
              style: TextStyle(
                color: context.colors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyOption extends StatelessWidget {
  final String currency, symbol, label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool useCustomFont;

  const _CurrencyOption({
    required this.currency,
    required this.symbol,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.useCustomFont = false,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? context.colors.brandLight
                : context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? Border.all(
                    color: context.colors.brand.withValues(alpha: 0.3),
                  )
                : null,
          ),
          child: Row(
            children: [
              Text(
                symbol,
                style: TextStyle(
                  fontSize: useCustomFont ? 22 : 20,
                  fontWeight: FontWeight.w700,
                  fontFamily: useCustomFont ? 'NBRB' : null,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: context.colors.brand,
                  size: 22,
                )
              else
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.colors.textDisabled,
                      width: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}