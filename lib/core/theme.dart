import 'package:flutter/material.dart';

/// Uygulamanın TEK renk ve tema kaynağı. Tema seçici yok: tek, sade, koyu
/// bir görünüm. Renkleri değiştirmek için yalnızca bu dosyayı düzenleyin.
class AppColors {
  AppColors._();

  static const Color bg = Color(0xFF07090D);
  static const Color surface = Color(0xFF0F131A);
  static const Color surfaceHigh = Color(0xFF161B24);
  static const Color outline = Color(0xFF232A36);

  static const Color text = Color(0xFFF1F4F8);
  static const Color muted = Color(0xFF8A94A6);

  static const Color primary = Color(0xFF2DE2C0);
  static const Color secondary = Color(0xFF4D8BFF);

  static const Color good = Color(0xFF2DE2C0);
  static const Color warn = Color(0xFFFFB84D);
  static const Color danger = Color(0xFFFF6B6B);

  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  /// Yüzdeye göre "ne kadar iyi" rengi (yüksek = iyi).
  static Color forHealth(num score) {
    if (score >= 75) return good;
    if (score >= 45) return warn;
    return danger;
  }

  /// Doluluk oranına göre renk (yüksek = kötü): RAM / depolama için.
  static Color forUsage(double ratio) {
    if (ratio >= 0.9) return danger;
    if (ratio >= 0.75) return warn;
    return primary;
  }
}

extension ColorOpacityX on Color {
  /// `withOpacity` Flutter sürümleri arasında kullanımdan kalktığı için
  /// sürümden bağımsız çalışan küçük bir yardımcı.
  Color faded(double opacity) => withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.danger,
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      dividerColor: AppColors.outline,
      splashFactory: InkRipple.splashFactory,
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.bg : AppColors.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.surfaceHigh,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.outline,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.faded(0.16),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.muted,
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.outline,
        thumbColor: AppColors.primary,
        overlayColor: AppColors.primary.faded(0.12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.outline,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: const TextStyle(color: AppColors.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
