import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

/// Единая тема приложения: светлая + тёмная.
class AppTheme {
  // ============================================================
  // СВЕТЛАЯ ТЕМА
  // ============================================================
  static ThemeData get light {
    const c = AppColors.light;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Inter',
      fontFamilyFallback: const ['.SF UI Display', 'Roboto'],

      // Палитра
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.brand,
        brightness: Brightness.light,
        primary: c.brand,
        surface: c.surface,
        error: c.error,
      ),

      // Расширения
      extensions: const [c],

      // Фон
      scaffoldBackgroundColor: c.background,

      // Текст
      textTheme: const TextTheme(
        displayLarge: AppTypography.h0,
        displayMedium: AppTypography.h1,
        displaySmall: AppTypography.h2,
        headlineLarge: AppTypography.h1,
        headlineMedium: AppTypography.h2,
        headlineSmall: AppTypography.h3,
        titleLarge: AppTypography.h3,
        titleMedium: AppTypography.h4,
        titleSmall: AppTypography.h4,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.buttonMedium,
        labelMedium: AppTypography.caption,
        labelSmall: AppTypography.label,
      ).apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: AppTypography.h3.copyWith(color: c.textPrimary),
        iconTheme: IconThemeData(color: c.textPrimary),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,      // Android: тёмные иконки
          statusBarBrightness: Brightness.light,         // iOS: чёрные иконки
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),

      // Кнопки
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.textDisabled,
          disabledForegroundColor: Colors.white,
          textStyle: AppTypography.buttonLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.brand,
          textStyle: AppTypography.buttonMedium,
          side: BorderSide(color: c.brand, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brand,
          textStyle: AppTypography.buttonMedium,
        ),
      ),

      // Карточки
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Поля ввода
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTypography.input.copyWith(color: c.textMuted),
        labelStyle: AppTypography.caption.copyWith(color: c.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.error),
        ),
      ),

      // Разделители
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),

      // Нижняя навигация
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: c.brand,
        unselectedItemColor: c.textMuted,
        selectedLabelStyle: AppTypography.label.copyWith(color: c.brand),
        unselectedLabelStyle: AppTypography.label.copyWith(color: c.textMuted),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.textPrimary,
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: c.surface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // Диалоги
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: AppTypography.h3.copyWith(color: c.textPrimary),
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: c.textSecondary),
      ),

      // Иконки
      iconTheme: IconThemeData(color: c.textPrimary, size: 24),
    );
  }

  // ============================================================
  // ТЁМНАЯ ТЕМА
  // ============================================================
  static ThemeData get dark {
    const c = AppColors.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Inter',
      fontFamilyFallback: const ['.SF UI Display', 'Roboto'],

      colorScheme: ColorScheme.fromSeed(
        seedColor: c.brand,
        brightness: Brightness.dark,
        primary: c.brand,
        surface: c.surface,
        error: c.error,
      ),

      extensions: const [c],

      scaffoldBackgroundColor: c.background,

      textTheme: const TextTheme(
        displayLarge: AppTypography.h0,
        displayMedium: AppTypography.h1,
        displaySmall: AppTypography.h2,
        headlineLarge: AppTypography.h1,
        headlineMedium: AppTypography.h2,
        headlineSmall: AppTypography.h3,
        titleLarge: AppTypography.h3,
        titleMedium: AppTypography.h4,
        titleSmall: AppTypography.h4,
        bodyLarge: AppTypography.bodyLarge,
        bodyMedium: AppTypography.bodyMedium,
        bodySmall: AppTypography.bodySmall,
        labelLarge: AppTypography.buttonMedium,
        labelMedium: AppTypography.caption,
        labelSmall: AppTypography.label,
      ).apply(
        bodyColor: c.textPrimary,
        displayColor: c.textPrimary,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: AppTypography.h3.copyWith(color: c.textPrimary),
        iconTheme: IconThemeData(color: c.textPrimary),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,     // Android: светлые иконки
          statusBarBrightness: Brightness.dark,          // iOS: белые иконки
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: c.textDisabled,
          disabledForegroundColor: Colors.white,
          textStyle: AppTypography.buttonLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.brand,
          textStyle: AppTypography.buttonMedium,
          side: BorderSide(color: c.brand, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.brand,
          textStyle: AppTypography.buttonMedium,
        ),
      ),

      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTypography.input.copyWith(color: c.textMuted),
        labelStyle: AppTypography.caption.copyWith(color: c.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.error),
        ),
      ),

      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.surface,
        selectedItemColor: c.brand,
        unselectedItemColor: c.textMuted,
        selectedLabelStyle: AppTypography.label.copyWith(color: c.brand),
        unselectedLabelStyle: AppTypography.label.copyWith(color: c.textMuted),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceAlt,
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: c.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: AppTypography.h3.copyWith(color: c.textPrimary),
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: c.textSecondary),
      ),

      iconTheme: IconThemeData(color: c.textPrimary, size: 24),
    );
  }
}
