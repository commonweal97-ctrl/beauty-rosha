import 'package:flutter/material.dart';

/// Показывает красивый попап при проблемах с сетью (РКН, VPN и т.д.)
class NetworkErrorBanner {
  static bool _isShowing = false;

  /// Показывает баннер с предложением включить VPN
  static void show(
    BuildContext context, {
    bool isBlocking = false,
    VoidCallback? onRetry,
  }) {
    if (_isShowing) return;
    _isShowing = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      useRootNavigator: true,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Иконка
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFDD1847).withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBlocking ? Icons.shield_outlined : Icons.wifi_off_rounded,
                  size: 36,
                  color: const Color(0xFFDD1847),
                ),
              ),
              const SizedBox(height: 16),

              // Заголовок
              const Text(
                'Проблемы с доступом\nк сервису',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                  height: 1.3,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 12),

              // Подзаголовок - улучшенная читаемость
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Это может быть связано с блокировкой сети.\n'
                  'Попробуйте выключить или включить VPN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF555555),
                    height: 1.6,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Кнопка "Обновить"
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _isShowing = false;
                    if (onRetry != null) {
                      onRetry();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDD1847),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Обновить',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _isShowing = false;
    });
  }
}