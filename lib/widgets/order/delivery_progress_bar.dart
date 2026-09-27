// lib/widgets/order/delivery_progress_bar.dart
import 'package:flutter/material.dart';

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
    final deliveryInfo = _buildDeliveryInfo();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Статус доставки',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF8F8F9A), letterSpacing: 0.5),
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
                                    ? const Color(0xFF4CAF50)
                                    : isCurrent
                                        ? const Color(0xFFDD1847)
                                        : const Color(0xFFE8E8E8),
                                boxShadow: isCurrent
                                    ? [BoxShadow(color: const Color(0xFFDD1847).withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 1))]
                                    : null,
                              ),
                              child: Icon(
                                step.icon,
                                size: 16,
                                color: isCompleted || isCurrent ? Colors.white : const Color(0xFFBBBBBB),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              step.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                color: isCompleted
                                    ? const Color(0xFF4CAF50)
                                    : isCurrent
                                        ? const Color(0xFF1A1A1A)
                                        : const Color(0xFFBBBBBB),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Container(
                            width: 16,
                            height: 2,
                            color: isCompleted ? const Color(0xFF4CAF50) : const Color(0xFFE8E8E8),
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
            const SizedBox(height: 12),
            deliveryInfo,
          ],
          // Ориентировочная дата
          if (showEstimated) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4CAF50).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ориентировочная дата доставки: $estimatedDeliveryDate',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF16A34A),
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

  Widget? _buildDeliveryInfo() {
    // Для курьера показываем временной интервал, если он есть
    if (deliveryMethod == 'courier' && deliveryTime != null && deliveryTime!.isNotEmpty) {
      final formatted = deliveryTime!.replaceAll('-', ' до ');
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFDF2F5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDD1847).withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Color(0xFFDD1847)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Доставим с $formatted',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFDD1847),
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