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
import '../../../core/app_colors.dart';

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
  double _maxBonusConverted = 0;

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

    context.read<CheckoutProvider>().setBonusAmount(
      value ? _maxBonusConverted : 0,
    );
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
        _maxBonusConverted = (data['max_spend'] as num?)?.toDouble() ?? 0.0;
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

    final ratio = _maxBonusRub > 0 ? _bonusToSpend / _maxBonusRub : 0.0;
    final convertedAmount = ratio * _maxBonusConverted;
    context.read<CheckoutProvider>().setBonusAmount(
      _useBonus ? convertedAmount : 0.0,
    );
  }

  void _editBonus() {
    final controller = TextEditingController(text: _bonusToSpend.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // drag handle
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
                  const SizedBox(height: 16),
                  // Заголовок
                  Text(
                    'Списать бонусы',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Builder(
                    builder: (ctx) {
                      final cur = context.watch<CurrencyProvider>();
                      final isRub = cur.currency == 'RUB';
                      final rate = isRub
                          ? 1.0
                          : (1.0 / (cur.rate == 0 ? 1 : cur.rate));
                      final availableConv = (_bonusAvailable * rate);
                      final maxConv = (_maxBonusRub * rate);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isRub)
                            Text(
                              'Доступно: $_bonusAvailable бонусов',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: context.colors.textMuted,
                              ),
                            )
                          else
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        'Доступно: $_bonusAvailable бонусов (≈ ${availableConv.toStringAsFixed(2)} ',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: context.colors.textMuted,
                                    ),
                                  ),
                                  TextSpan(
                                    text: cur.symbol,
                                    style: TextStyle(
                                      fontFamily: cur.fontFamily,
                                      fontSize: cur.symbolFontSize,
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.textMuted,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ')',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: context.colors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 2),
                          if (isRub)
                            Text(
                              '1 бонус = 1 ₽ · не более $_maxBonusRub',
                              style: TextStyle(
                                fontSize: 13,
                                color: context.colors.textMuted,
                              ),
                            )
                          else
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text:
                                        '1 бонус ≈ ${rate.toStringAsFixed(3)} ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.colors.textMuted,
                                    ),
                                  ),
                                  TextSpan(
                                    text: cur.symbol,
                                    style: TextStyle(
                                      fontFamily: cur.fontFamily,
                                      fontSize: cur.symbolFontSize,
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.textMuted,
                                    ),
                                  ),
                                  TextSpan(
                                    text:
                                        ' · не более ${maxConv.toStringAsFixed(2)} ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: context.colors.textMuted,
                                    ),
                                  ),
                                  TextSpan(
                                    text: cur.symbol,
                                    style: TextStyle(
                                      fontFamily: cur.fontFamily,
                                      fontSize: cur.symbolFontSize,
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Поле (Apple-style)
                  Container(
                    decoration: BoxDecoration(
                      color: context.colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                      decoration: InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[400],
                        ),
                        suffix: Builder(
                          builder: (ctx) {
                            final cur = context.watch<CurrencyProvider>();
                            return Text(
                              cur.symbol,
                              style: TextStyle(
                                fontFamily: cur.fontFamily,
                                fontSize: cur.symbolFontSize,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textMuted,
                              ),
                            );
                          },
                        ),
                        filled: false,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Быстрые кнопки
                  Row(
                    children: [
                      _quickChip(ctx, controller, 'Все', _bonusAvailable),
                      const SizedBox(width: 8),
                      _quickChip(
                        ctx,
                        controller,
                        '50%',
                        (_bonusAvailable / 2).floor(),
                      ),
                      const SizedBox(width: 8),
                      _quickChip(ctx, controller, 'Макс', _maxBonusRub),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Списать
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        _onBonusChanged(controller.text);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.brand,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Списать',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Отмена
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      'Отмена',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _quickChip(
    BuildContext ctx,
    TextEditingController controller,
    String label,
    int amount,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () => controller.text = amount.toString(),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(color: context.colors.brand),
        ),
      );
    }

    if (_bonusAvailable <= 0) return SizedBox();

    return Container(
      color: context.colors.surface,
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.surfaceAlt),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _useBonus ? _editBonus : null,
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Списать бонусы · ',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textPrimary,
                                  ),
                                ),
                                TextSpan(
                                  text: '$_bonusToSpend бонусов',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.brand,
                                    decoration: TextDecoration.underline,
                                    decorationColor: context.colors.brand,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '1 бонус = 1 ₽',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.colors.textMuted,
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
                      activeThumbColor: context.colors.brand,
                      activeTrackColor: context.colors.brand.withValues(
                        alpha: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_showLimitNotice)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border(
                    top: BorderSide(color: context.colors.surfaceAlt),
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(14),
                  ),
                ),
                child: Column(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Можно списать не более ',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          TextSpan(
                            text: '$_maxBonusRub',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: context.colors.brand,
                            ),
                          ),
                          TextSpan(
                            text: ' бонусов',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '30% от суммы заказа',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textMuted,
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
