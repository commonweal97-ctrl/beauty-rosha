import 'package:flutter/material.dart';

/// Единая палитра приложения.
/// Использование: context.colors.brand
class AppColors extends ThemeExtension<AppColors> {
  // Бренд
  final Color brand;
  final Color brandLight;
  final Color brandDark;

  // Текст
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;

  // Фон
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;

  // Статусы
  final Color success;
  final Color error;
  final Color warning;

  const AppColors({
    required this.brand,
    required this.brandLight,
    required this.brandDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.success,
    required this.error,
    required this.warning,
  });

  static const light = AppColors(
    brand: Color(0xFFDD1847),
    brandLight: Color(0xFFFDF2F5),
    brandDark: Color(0xFFB01038),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF666666),
    textMuted: Color(0xFF999999),
    textDisabled: Color(0xFFCCCCCC),
    background: Color(0xFFF5F5F5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF8F9FA),
    border: Color(0xFFE0E0E0),
    success: Color(0xFF4CAF50),
    error: Color(0xFFFF2E6E),
    warning: Color(0xFFFF9800),
  );

  static const dark = AppColors(
    brand: Color(0xFFDD1847),
    brandLight: Color(0xFF3A1A22),
    brandDark: Color(0xFFFF4D77),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFB0B0B0),
    textMuted: Color(0xFF808080),
    textDisabled: Color(0xFF555555),
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    surfaceAlt: Color(0xFF2A2A2A),
    border: Color(0xFF333333),
    success: Color(0xFF66BB6A),
    error: Color(0xFFFF5252),
    warning: Color(0xFFFFB74D),
  );

  @override
  AppColors copyWith({
    Color? brand,
    Color? brandLight,
    Color? brandDark,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textDisabled,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? success,
    Color? error,
    Color? warning,
  }) {
    return AppColors(
      brand: brand ?? this.brand,
      brandLight: brandLight ?? this.brandLight,
      brandDark: brandDark ?? this.brandDark,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textDisabled: textDisabled ?? this.textDisabled,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      success: success ?? this.success,
      error: error ?? this.error,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      brand: Color.lerp(brand, other.brand, t)!,
      brandLight: Color.lerp(brandLight, other.brandLight, t)!,
      brandDark: Color.lerp(brandDark, other.brandDark, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDisabled: Color.lerp(textDisabled, other.textDisabled, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      success: Color.lerp(success, other.success, t)!,
      error: Color.lerp(error, other.error, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

/// Удобный доступ: context.colors.brand
extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
