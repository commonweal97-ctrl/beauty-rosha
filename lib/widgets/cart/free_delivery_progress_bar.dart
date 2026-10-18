// lib/widgets/cart/free_delivery_progress_bar.dart
// Двухэтапный прогресс-бар доставки:
//   1) До порога Ozon (2000 ₽) — синяя шкала.
//   2) После Ozon — красная шкала до порога других ТК (5000 ₽).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../providers/cart_provider.dart';
import '../../providers/city_provider.dart';
import '../../providers/currency_provider.dart';

class FreeDeliveryProgressBar extends StatelessWidget {
  const FreeDeliveryProgressBar({super.key});

  static const Color _ozonColor = Color(0xFF005BFF);

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final city = context.watch<CityProvider>();
    final currency = context.watch<CurrencyProvider>();

    final total = cart.finalTotal;
    // Если Ozon недоступен (город в skip_regions) — ozonThreshold = 0
    // из API. Тогда используем только otherThreshold (обычный порог).
    final rawOzon = city.ozonThreshold;
    final otherThreshold = city.otherThreshold;
    final ozonThreshold = rawOzon > 0 ? rawOzon : otherThreshold;

    // Если пороги не заданы — не показываем
    if (ozonThreshold <= 0 || total <= 0) {
      return const SizedBox.shrink();
    }

    // Если пороги совпадают — рисуем одну шкалу (как раньше)
    final sameThreshold = ozonThreshold == otherThreshold;

    // === СТАДИЯ 1: до Ozon ===
    if (total < ozonThreshold) {
      return _buildBar(
        context,
        currency,
        progress: total / ozonThreshold,
        fillColor: _ozonColor,
        text: _buildText(
          context,
          currency,
          remaining: (ozonThreshold - total).toInt(),
          // Если sameThreshold — Ozon недоступен (Брянск и т.п.),
          // пишем без провайдера («до бесплатной доставки»).
          provider: sameThreshold ? '' : 'Ozon',
          done: false,
        ),
      );
    }

    // === СТАДИЯ 2: Ozon уже открыт, добираем до остальных ===
    if (!sameThreshold && total < otherThreshold) {
      // Первая полоска — 100% (Ozon открыт).
      // Вторая — прогресс от ozonThreshold до otherThreshold.
      final progress2 = (total - ozonThreshold) /
          (otherThreshold - ozonThreshold).clamp(1, double.infinity);

      return _buildBar(
        context,
        currency,
        progress: 1.0, // синяя полностью
        fillColor: _ozonColor,
        overlay: _OverlayBar(
          progress: progress2.clamp(0.0, 1.0),
          color: context.colors.brand,
        ),
        text: _buildText(
          context,
          currency,
          remaining: (otherThreshold - total).toInt(),
          provider: 'СДЭК, Яндекс, Почты',
          done: false,
          ozonOpened: true,
        ),
      );
    }

    // === ВСЁ ОТКРЫТО ===
    return _buildBar(
      context,
      currency,
      progress: 1.0,
      fillColor: context.colors.success,
      text: _buildText(
        context,
        currency,
        remaining: 0,
        provider: '',
        done: true,
        allOpened: !sameThreshold,
      ),
    );
  }

  // ============ ТЕКСТ ============
  Widget _buildText(
    BuildContext context,
    CurrencyProvider currency, {
    required int remaining,
    required String provider,
    required bool done,
    bool ozonOpened = false,
    bool allOpened = false,
  }) {
    if (done) {
      final txt = allOpened
          ? 'Бесплатная доставка у всех служб'
          : 'Доставка будет бесплатной';
      return Text(
        txt,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.colors.success,
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: context.colors.textMuted,
          height: 1.3,
        ),
        children: [
          if (ozonOpened) ...[
            const TextSpan(text: 'Ozon — бесплатно. Осталось '),
          ] else ...[
            const TextSpan(text: 'Осталось '),
          ],
          TextSpan(
            text: '$remaining ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
            ),
          ),
          TextSpan(
            text: currency.symbol,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
              fontFamily: currency.fontFamily,
            ),
          ),
          const TextSpan(text: ' до бесплатной доставки'),
          if (provider.isNotEmpty) ...[
            const TextSpan(text: ' '),
            TextSpan(
              text: provider,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============ БАР ============
  Widget _buildBar(
    BuildContext context,
    CurrencyProvider currency, {
    required double progress,
    required Color fillColor,
    required Widget text,
    _OverlayBar? overlay,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          text,
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                LinearProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  minHeight: 3,
                  backgroundColor: context.colors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(fillColor),
                ),
                if (overlay != null)
                  LinearProgressIndicator(
                    value: overlay.progress,
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(overlay.color),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayBar {
  final double progress;
  final Color color;
  const _OverlayBar({required this.progress, required this.color});
}
