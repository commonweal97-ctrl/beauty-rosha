// lib/widgets/qr_popup.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_logger.dart';
import '../providers/auth_provider.dart';
import '../providers/currency_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/checkout/payment_webview_screen.dart';
import '../services/api_service.dart';
import '../services/loyalty_service.dart';
import '../core/app_colors.dart';

class QrPopup extends StatefulWidget {
  const QrPopup({super.key});

  static void show(BuildContext context) {
    final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
    if (!isLoggedIn) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (_) => const QrPopup(),
    );
  }

  @override
  State<QrPopup> createState() => _QrPopupState();
}

class _QrPopupState extends State<QrPopup> {
  static const _logTag = 'QrPopup';

  Map<String, dynamic>? _cardData;
  int _bonusBalance = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final status = await LoyaltyService.getStatus();
      final bonus = await _loadBonusBalance();

      if (!mounted) return;

      setState(() {
        _cardData = status;
        _bonusBalance = bonus;
        _loading = false;
      });

      if (_cardData?['card_number'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_qr_card', _cardData!['card_number']);
      }
    } catch (e, st) {
      AppLogger.error(_logTag, 'loadData failed', e, st);

      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_qr_card');

      if (!mounted) return;
      setState(() {
        if (cached != null) {
          _cardData = {
            'card_number': cached,
            'has_card': true,
            'status': 'active',
          };
        } else {
          _error = e.toString();
        }
        _loading = false;
      });
    }
  }

  Future<int> _loadBonusBalance() async {
    final result = await ApiService.get('/api/bonus/balance');

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadBonusBalance failed: ${result.errorOrNull?.message}',
      );
      return 0;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return 0;

    final balance = data['points'] ?? 0;
    if (balance is int) return balance;
    return int.tryParse(balance.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {},
          child: DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _loading
                          ? Center(
                              child: CircularProgressIndicator(
                                color: context.colors.brand,
                              ),
                            )
                          : _buildContent(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final isGuest = _cardData?['is_guest'] == true;
    final hasCard = _cardData?['has_card'] == true;
    final cardNumber = _cardData?['card_number'];
    final currency = context.watch<CurrencyProvider>();

    if (_error != null) {
      return Center(
        child: Text(
          'Ошибка: $_error',
          style: TextStyle(color: context.colors.textMuted),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Center(
          child: Text(
            'Б·Карта',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(height: 24),
        if (isGuest) ...[
          SizedBox(height: 40),
          Icon(
            Icons.lock_outline,
            size: 64,
            color: context.colors.brand.withValues(alpha: 0.2),
          ),
          SizedBox(height: 16),
          Text(
            'Авторизуйтесь для доступа к Б·Карте',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: context.colors.textSecondary),
          ),
        ] else if (hasCard && cardNumber != null) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE8E8E8)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: cardNumber,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              cardNumber,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 3,
              ),
            ),
          ),
          SizedBox(height: 8),
          Center(
            child: Text(
              'Покажите код на кассе для скидки',
              style: TextStyle(fontSize: 14, color: context.colors.textMuted),
            ),
          ),
          SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: context.colors.brandLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Text(
                  'Бонусный баланс',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '$_bonusBalance',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: context.colors.brand,
                    height: 1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'бонусов',
                  style: TextStyle(fontSize: 14, color: context.colors.textMuted),
                ),
              ],
            ),
          ),
        ] else ...[
          SizedBox(height: 20),
          Icon(
            Icons.credit_card_off,
            size: 64,
            color: context.colors.brand.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'У вас пока нет Б·Карты',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Уникальные цены на все товары',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.colors.textMuted),
          ),
          SizedBox(height: 24),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildConditionRow(
                  '1',
                  'Соберите заказ от ${currency.formatConverted(5000)} ${currency.symbol} — карта активируется автоматически',
                  currency,
                ),
                const SizedBox(height: 12),
                _buildConditionRow(
                  '2',
                  'Или активируйте мгновенно за ${currency.formatConverted(499)} ${currency.symbol}',
                  currency,
                ),
              ],
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _activateCard,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text:
                          'Активировать за ${currency.formatConverted(499)} ',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: currency.symbol,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: currency.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              '*за исключением товаров, на которые уже снижена цена по акции',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB)),
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildConditionRow(String number, String text, dynamic currency) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: context.colors.brand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: context.colors.brand,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
                height: 1.4,
              ),
              children: _parseConditionText(text, currency),
            ),
          ),
        ),
      ],
    );
  }

  List<TextSpan> _parseConditionText(String text, dynamic currency) {
    final spans = <TextSpan>[];
    final parts = text.split(currency.symbol);

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isNotEmpty) {
        spans.add(TextSpan(text: parts[i]));
      }
      if (i < parts.length - 1) {
        spans.add(TextSpan(
          text: currency.symbol,
          style: TextStyle(fontFamily: currency.fontFamily),
        ));
      }
    }

    return spans;
  }

  Future<void> _activateCard() async {
    setState(() => _loading = true);

    final result = await LoyaltyService.activate();

    if (result.isFailure) {
      setState(() {
        _loading = false;
        _error = result.errorOrNull?.userMessage ?? 'Ошибка активации';
      });
      return;
    }

    final data = result.valueOrNull ?? const {};

    if (data['need_payment'] == true) {
      await _createPayment();
      return;
    }

    // Успех — перезагружаем данные
    await _loadData();
  }

  Future<void> _createPayment() async {
    final result = await LoyaltyService.createPayment();

    if (result.isFailure) {
      setState(() {
        _loading = false;
        _error = result.errorOrNull?.userMessage ?? 'Ошибка создания платежа';
      });
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      setState(() {
        _loading = false;
        _error = 'Ошибка создания платежа';
      });
      return;
    }

    final orderId = data['order_id'];
    final amount = data['amount'];
    final paymentMethod = data['payment_method'] ?? 'card';

    // Для invoice (BYN/KZT) — не открываем WebView
    if (paymentMethod == 'invoice') {
      setState(() => _loading = false);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Заявка на активацию Б·Карты принята!\n'
              'Счет будет направлен на вашу почту в течение 24 часов.',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }

    // Для card (RUB) — открываем WebView
    final prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('remember_token') ?? '';

    // Пробуем из cookies
    if (token.isEmpty) {
      token = ApiService.cookies
              ?.split('; ')
              .firstWhere(
                (c) => c.startsWith('remember_token='),
                orElse: () => '',
              )
              .replaceFirst('remember_token=', '') ??
          '';
    }

    // Всегда обновляем через refresh-token
    final refreshResult = await ApiService.post('/api/auth/refresh-token', {});

    if (refreshResult.isSuccess) {
      final refreshData = refreshResult.valueOrNull;
      final newToken = refreshData?['remember_token'] ??
          refreshData?['token'] ??
          refreshData?['data']?['remember_token'] ??
          refreshData?['data']?['token'] ??
          '';

      if (newToken is String && newToken.isNotEmpty) {
        token = newToken;
        await prefs.setString('remember_token', token);
        AppLogger.info(_logTag, 'QR token refreshed');
      }
    } else {
      AppLogger.warning(
        _logTag,
        'QR refresh failed: ${refreshResult.errorOrNull?.message}',
      );
    }

    if (token.isEmpty) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка авторизации. Перезайдите в приложение.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _loading = false);

    if (!mounted) return;

    Navigator.pop(context);

    final url = '${ApiService.baseUrl}/api/payment/pay'
        '?order_id=$orderId'
        '&amount=${(amount as num).toInt()}'
        '&token=$token';

    final paymentResult = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentWebViewScreen(
          paymentUrl: url,
          orderId: orderId,
          authToken: token,
          baseUrl: ApiService.baseUrl,
        ),
      ),
    );

    await _loadData();

    if (paymentResult == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Б·Карта активирована!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}