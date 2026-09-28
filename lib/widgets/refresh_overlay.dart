// lib/widgets/refresh_overlay.dart
import 'package:flutter/material.dart';

/// Переиспользуемый оверлей-прелоадер для pull-to-refresh
/// Показывается поверх контента при обновлении данных
class RefreshOverlay extends StatelessWidget {
  /// Флаг видимости оверлея
  final bool visible;
  
  /// Текст под прелоадером
  final String message;
  
  /// Цвет прелоадера
  final Color? color;
  
  /// Прозрачность фона (0.0 - 1.0)
  final double backgroundOpacity;
  
  /// Задержка анимации появления/исчезновения
  final Duration animationDuration;
  
  /// Показывать ли контейнер с тенью
  final bool showContainer;
  
  /// Размер прелоадера
  final double loaderSize;
  
  /// Радиус контейнера
  final double containerRadius;
  
  /// Дополнительные стили для текста
  final TextStyle? messageStyle;

  const RefreshOverlay({
    super.key,
    required this.visible,
    this.message = 'Обновляем данные...',
    this.color,
    this.backgroundOpacity = 0.8,
    this.animationDuration = const Duration(milliseconds: 300),
    this.showContainer = true,
    this.loaderSize = 64,
    this.containerRadius = 20,
    this.messageStyle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: visible ? 1.0 : 0.0,
      duration: animationDuration,
      curve: Curves.easeInOut,
      child: IgnorePointer(
        ignoring: !visible,
        child: Container(
          color: Colors.white.withValues(alpha: backgroundOpacity),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showContainer)
                  Container(
                    width: loaderSize,
                    height: loaderSize,
                    padding: EdgeInsets.all(loaderSize * 0.25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(containerRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CircularProgressIndicator(
                      color: color,
                      strokeWidth: 3,
                    ),
                  )
                else
                  SizedBox(
                    width: loaderSize * 0.6,
                    height: loaderSize * 0.6,
                    child: CircularProgressIndicator(
                      color: color,
                      strokeWidth: 3,
                    ),
                  ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: messageStyle ?? TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}