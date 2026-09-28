// lib/widgets/order/delivery_progress_bar.dart
import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class DeliveryProgressBar extends StatelessWidget {
  final String status;
  final String deliveryMethod;
  final String createdAt;
  final String? shippingAt;
  final String? waitingAt;
  final String? completedAt;
  final String? estimatedDeliveryDate;
  final String? deliveryTime;
  final String? pointAddress;

  const DeliveryProgressBar({
    super.key,
    required this.status,
    required this.deliveryMethod,
    required this.createdAt,
    this.shippingAt,
    this.waitingAt,
    this.completedAt,
    this.estimatedDeliveryDate,
    this.deliveryTime,
    this.pointAddress,
  });

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    final currentIndex = _getCurrentIndex();

    final showEstimated = !['ready_pickup', 'completed'].contains(status)
        && estimatedDeliveryDate != null
        && estimatedDeliveryDate!.isNotEmpty;

    // Информация о доставке под шкалой
    final deliveryInfo = _buildDeliveryInfo(context);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(12, 16, 12, 16),
      color: context.colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Статус доставки',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textMuted, letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 56,
            child: Row(
              children: List.generate(steps.length, (index) {
                final step = steps[index];
                final isCompleted = index < currentIndex;
                final isCurrent = index == currentIndex;
                final isLast = index == steps.length - 1;

                return Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCompleted
                                    ? context.colors.success
                                    : isCurrent
                                        ? context.colors.brand
                                        : context.colors.border,
                                boxShadow: isCurrent
                                    ? [BoxShadow(color: context.colors.brand.withValues(alpha: 0.3), blurRadius: 4, offset: Offset(0, 1))]
                                    : null,
                              ),
                              child: Icon(
                                step.icon,
                                size: 16,
                                color: isCompleted || isCurrent ? Colors.white : context.colors.textDisabled,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              step.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                color: isCompleted
                                    ? context.colors.success
                                    : isCurrent
                                        ? context.colors.textPrimary
                                        : context.colors.textDisabled,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Padding(
                          padding: EdgeInsets.only(bottom: 18),
                          child: Container(
                            width: 16,
                            height: 2,
                            color: isCompleted ? context.colors.success : context.colors.border,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
          // Информация о доставке (время/адрес)
          if (deliveryInfo != null) ...[
            SizedBox(height: 12),
            deliveryInfo,
          ],
          // Ориентировочная дата
          if (showEstimated) ...[
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.colors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.success.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: context.colors.success),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ориентировочная дата доставки: $estimatedDeliveryDate',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<_StepData> _buildSteps() {
    switch (deliveryMethod) {
      case 'courier':
        return [
          _StepData('Создан', Icons.receipt_long_outlined, createdAt),
          _StepData('Обработка', Icons.inventory_2_outlined, null),
          _StepData('Курьер в пути', Icons.delivery_dining_outlined, shippingAt),
          _StepData('Получен', Icons.check_circle_outline, completedAt),
        ];
      case 'pickup-store':
        return [
          _StepData('Создан', Icons.receipt_long_outlined, createdAt),
          _StepData('Обработка', Icons.inventory_2_outlined, null),
          _StepData('Готов к выдаче', Icons.storefront_outlined, waitingAt),
          _StepData('Получен', Icons.check_circle_outline, completedAt),
        ];
      default: // pickup-point
        return [
          _StepData('Создан', Icons.receipt_long_outlined, createdAt),
          _StepData('Обработка', Icons.inventory_2_outlined, null),
          _StepData('В пути', Icons.local_shipping_outlined, shippingAt),
          _StepData('В ПВЗ', Icons.store_outlined, waitingAt),
          _StepData('Получен', Icons.check_circle_outline, completedAt),
        ];
    }
  }

  Widget? _buildDeliveryInfo(BuildContext context) {
    // Для курьера показываем временной интервал, если он есть
    if (deliveryMethod == 'courier' && deliveryTime != null && deliveryTime!.isNotEmpty) {
      final formatted = deliveryTime!.replaceAll('-', ' до ');
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.colors.brandLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.brand.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, size: 16, color: context.colors.brand),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Доставим с $formatted',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.brand,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Для pickup-store и pickup-point не показываем адрес здесь, он уже есть в блоке над шкалой
    // if (deliveryMethod == 'pickup-store' && pointAddress != null && pointAddress!.isNotEmpty) { ... } // убрано

    return null;
  }

  int _getCurrentIndex() {
    final maxIndex = _buildSteps().length - 1;
    switch (status) {
      case 'pending':
      case 'awaiting_payment':
        return 0;
      case 'processing':
        return 1;
      case 'shipping':
        return deliveryMethod == 'courier' ? 2 : (deliveryMethod == 'pickup-store' ? 1 : 2);
      case 'ready_pickup':
  return deliveryMethod == 'pickup-store' ? 2 : 3;
      case 'completed':
        return maxIndex;
      default:
        return 0;
    }
  }
}

class _StepData {
  final String label;
  final IconData icon;
  final String? date;

  _StepData(this.label, this.icon, this.date);
}