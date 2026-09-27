// lib/screens/checkout/widgets/bonus_block.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../../core/app_logger.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/checkout_provider.dart';
import '../../../providers/currency_provider.dart';
import '../../../services/api_service.dart';

class BonusBlock extends StatefulWidget {
  const BonusBlock({super.key});

  @override
  State<BonusBlock> createState() => _BonusBlockState();
}

class _BonusBlockState extends State<BonusBlock> {
  static const _logTag = 'BonusBlock';

  bool _useBonus = false;
  int _bonusAvailable = 0;
  int _bonusToSpend = 0;
  bool _loading = true;
  bool _showLimitNotice = false;
  int _maxBonusRub = 0;
  int _maxBonusConverted = 0;

  @override
  void initState() {
    super.initState();
    _loadBonusData();
  }

  Future<void> _loadBonusData() async {
    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      AppLogger.info(_logTag, 'not logged in, skip bonus load');
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    AppLogger.info(_logTag, 'loading bonus...');
    final result = await ApiService.get('/api/bonus/balance');

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'load bonus failed: ${result.errorOrNull?.message}',
      );
    } else {
      final data = result.valueOrNull?['data'];
      if (data is Map) {
        _bonusAvailable = (data['points'] as num?)?.toInt() ?? 0;
        _bonusToSpend = _bonusAvailable;
        AppLogger.info(_logTag, 'bonus available: $_bonusAvailable');
        await _calculateMaxBonus();
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _toggleBonus(bool value) {
    setState(() {
      _useBonus = value;
      _showLimitNotice = false;

      if (value) {
        _bonusToSpend = _maxBonusRub;
        if (_bonusToSpend > _maxBonusRub) {
          _bonusToSpend = _maxBonusRub;
          _showLimitNotice = true;
        }
      } else {
        _bonusToSpend = _bonusAvailable;
      }
    });

    context
        .read<CheckoutProvider>()
        .setBonusAmount(value ? _maxBonusConverted : 0);
  }

  Future<void> _calculateMaxBonus() async {
    final cartTotal = context.read<CartProvider>().finalTotal;
    final currency = context.read<CurrencyProvider>().currency;

    final result = await ApiService.get(
      '/api/bonus/check?order_amount=$cartTotal&currency=$currency',
      forceRefresh: true,
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'calculateMaxBonus failed: ${result.errorOrNull?.message}',
      );
      _maxBonusRub = 0;
      _maxBonusConverted = 0;
    } else {
      final data = result.valueOrNull?['data'];
      if (data is Map) {
        _maxBonusRub = (data['max_spend_rub'] as num?)?.toInt() ?? 0;
        _maxBonusConverted =
            (data['max_spend'] as num?)?.toInt() ?? 0;
        if (_maxBonusRub > _bonusAvailable) {
          _maxBonusRub = _bonusAvailable;
        }
        AppLogger.info(
          _logTag,
          'server max bonus = $_maxBonusRub RUB '
              '(display), $_maxBonusConverted ${data['currency']}',
        );
      } else {
        _maxBonusRub = 0;
        _maxBonusConverted = 0;
      }
    }

    if (!mounted) return;
    setState(() {});
  }

  void _onBonusChanged(String value) {
    final amount = int.tryParse(value) ?? 0;
    setState(() {
      _showLimitNotice = false;

      if (amount > _bonusAvailable) {
        _bonusToSpend = _bonusAvailable;
      } else if (amount > _maxBonusRub) {
        _bonusToSpend = _maxBonusRub;
        _showLimitNotice = true;
      } else {
        _bonusToSpend = amount;
      }
    });

    final ratio =
        _maxBonusRub > 0 ? _bonusToSpend / _maxBonusRub : 0.0;
    final convertedAmount = (ratio * _maxBonusConverted).round();
    context
        .read<CheckoutProvider>()
        .setBonusAmount(_useBonus ? convertedAmount : 0);
  }

  void _editBonus() {
    final controller =
        TextEditingController(text: _bonusToSpend.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Списать бонусы',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Доступно: $_bonusAvailable бонусов',
              style: const TextStyle(color: Color(0xFF8F8F9A)),
            ),
            const SizedBox(height: 4),
            const Text(
              '1 бонус = 1 ₽',
              style: TextStyle(fontSize: 12, color: Color(0xFF999999)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Введите сумму',
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Color(0xFF999999)),
            ),
          ),
          TextButton(
            onPressed: () {
              _onBonusChanged(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text(
              'Применить',
              style: TextStyle(
                color: Color(0xFFDD1847),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFDD1847)),
        ),
      );
    }

    if (_bonusAvailable <= 0) return const SizedBox();

    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Transform.rotate(
                    angle: -0.15,
                    child: SvgPicture.asset(
                      'assets/icons/bonus-logo.svg',
                      width: 20,
                      height: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _useBonus ? _editBonus : null,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text: 'Списать бонусы · ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                TextSpan(
                                  text: '$_bonusToSpend бонусов',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFDD1847),
                                    decoration: TextDecoration.underline,
                                    decorationColor: Color(0xFFDD1847),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '1 бонус = 1 ₽',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 26,
                    child: Switch(
                      value: _useBonus,
                      onChanged: _toggleBonus,
                      activeThumbColor: const Color(0xFFDD1847),
                      activeTrackColor: const Color(0xFFFCCCD5),
                    ),
                  ),
                ],
              ),
            ),
            if (_showLimitNotice)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Color(0xFFF0F0F0)),
                  ),
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(14)),
                ),
                child: Column(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Можно списать не более ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF333333),
                            ),
                          ),
                          TextSpan(
                            text: '$_maxBonusRub',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDD1847),
                            ),
                          ),
                          const TextSpan(
                            text: ' бонусов',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF333333),
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '30% от суммы заказа',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF888888),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}