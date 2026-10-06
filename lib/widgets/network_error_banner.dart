import 'package:flutter/material.dart';
import '../core/app_colors.dart';

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
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Drag handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 24),

              // Иконка
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: context.colors.brand.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isBlocking ? Icons.shield_outlined : Icons.wifi_off_rounded,
                  size: 36,
                  color: context.colors.brand,
                ),
              ),
              SizedBox(height: 16),

              // Заголовок
              Text(
                'Проблемы с доступом\nк сервису',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                  height: 1.3,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 12),

              // Подзаголовок - улучшенная читаемость
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Не удалось подключиться к серверу.\n'
                  'Проверьте подключение к интернету и попробуйте снова',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.colors.textSecondary,
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
                    backgroundColor: context.colors.brand,
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
        ),
        );
      },
    ).whenComplete(() {
      _isShowing = false;
    });
  }
}