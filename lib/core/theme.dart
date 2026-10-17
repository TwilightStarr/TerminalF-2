import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Bir tema paleti: arka plan, yüzey, metin ve vurgu renklerinin tamamı.
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.outline,
    required this.text,
    required this.muted,
    required this.primary,
    required this.secondary,
    required this.good,
    required this.warn,
    required this.danger,
    required this.logoFrameA,
    required this.logoFrameB,
    required this.logoA,
    required this.logoB,
  });

  final String id;
  final String name;
  final Brightness brightness;

  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color outline;
  final Color text;
  final Color muted;
  final Color primary;
  final Color secondary;
  final Color good;
  final Color warn;
  final Color danger;

  /// Logonun zemini (uygulama ikonu gibi her zaman koyu) ve "Tema rengi"
  /// seçiliyken kullanılan logo renkleri.
  final Color logoFrameA;
  final Color logoFrameB;
  final Color logoA;
  final Color logoB;

  bool get isDark => brightness == Brightness.dark;
}

/// Hazır temalar. Varsayılan: [monoDark] (siyah-beyaz).
class AppPalettes {
  AppPalettes._();

  static const String defaultId = 'mono_dark';

  static const AppPalette monoDark = AppPalette(
    id: 'mono_dark',
    name: 'Siyah & Beyaz',
    brightness: Brightness.dark,
    bg: Color(0xFF000000),
    surface: Color(0xFF0D0D0D),
    surfaceHigh: Color(0xFF181818),
    outline: Color(0xFF2A2A2A),
    text: Color(0xFFFAFAFA),
    muted: Color(0xFF8E8E8E),
    primary: Color(0xFFFFFFFF),
    secondary: Color(0xFFB4B4B4),
    good: Color(0xFFFFFFFF),
    warn: Color(0xFFFFB84D),
    danger: Color(0xFFFF6B6B),
    logoFrameA: Color(0xFF000000),
    logoFrameB: Color(0xFF1B1B1B),
    logoA: Color(0xFFFFFFFF),
    logoB: Color(0xFFBDBDBD),
  );

  static const AppPalette monoLight = AppPalette(
    id: 'mono_light',
    name: 'Beyaz & Siyah',
    brightness: Brightness.light,
    bg: Color(0xFFF6F6F6),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEEEEEE),
    outline: Color(0xFFDEDEDE),
    text: Color(0xFF0A0A0A),
    muted: Color(0xFF6B6B6B),
    primary: Color(0xFF0A0A0A),
    secondary: Color(0xFF4A4A4A),
    good: Color(0xFF0A0A0A),
    warn: Color(0xFFC77700),
    danger: Color(0xFFD62F2F),
    logoFrameA: Color(0xFF0A0A0A),
    logoFrameB: Color(0xFF222222),
    logoA: Color(0xFFFFFFFF),
    logoB: Color(0xFFC8C8C8),
  );

  /// Önceki (ilk sürüm) turkuaz-mavi görünüm.
  static const AppPalette neon = AppPalette(
    id: 'neon',
    name: 'Neon Turkuaz',
    brightness: Brightness.dark,
    bg: Color(0xFF07090D),
    surface: Color(0xFF0F131A),
    surfaceHigh: Color(0xFF161B24),
    outline: Color(0xFF232A36),
    text: Color(0xFFF1F4F8),
    muted: Color(0xFF8A94A6),
    primary: Color(0xFF2DE2C0),
    secondary: Color(0xFF4D8BFF),
    good: Color(0xFF2DE2C0),
    warn: Color(0xFFFFB84D),
    danger: Color(0xFFFF6B6B),
    logoFrameA: Color(0xFF0A0E14),
    logoFrameB: Color(0xFF151E2C),
    logoA: Color(0xFF2DE2C0),
    logoB: Color(0xFF4D8BFF),
  );

  static const AppPalette ocean = AppPalette(
    id: 'ocean',
    name: 'Okyanus',
    brightness: Brightness.dark,
    bg: Color(0xFF060A12),
    surface: Color(0xFF0D131F),
    surfaceHigh: Color(0xFF141C2C),
    outline: Color(0xFF212C42),
    text: Color(0xFFF0F5FF),
    muted: Color(0xFF8593AD),
    primary: Color(0xFF5AA9FF),
    secondary: Color(0xFF7C6CFF),
    good: Color(0xFF4ADE9B),
    warn: Color(0xFFFFB84D),
    danger: Color(0xFFFF6B6B),
    logoFrameA: Color(0xFF070C16),
    logoFrameB: Color(0xFF111B30),
    logoA: Color(0xFF5AA9FF),
    logoB: Color(0xFF7C6CFF),
  );

  static const AppPalette sunset = AppPalette(
    id: 'sunset',
    name: 'Gün Batımı',
    brightness: Brightness.dark,
    bg: Color(0xFF0C0807),
    surface: Color(0xFF16100E),
    surfaceHigh: Color(0xFF211815),
    outline: Color(0xFF362823),
    text: Color(0xFFFFF4EE),
    muted: Color(0xFFA8918A),
    primary: Color(0xFFFF8A4D),
    secondary: Color(0xFFFF4D8D),
    good: Color(0xFF6EE7A0),
    warn: Color(0xFFFFC84D),
    danger: Color(0xFFFF5C5C),
    logoFrameA: Color(0xFF110B09),
    logoFrameB: Color(0xFF241713),
    logoA: Color(0xFFFF8A4D),
    logoB: Color(0xFFFF4D8D),
  );

  static const AppPalette forest = AppPalette(
    id: 'forest',
    name: 'Orman',
    brightness: Brightness.dark,
    bg: Color(0xFF060A08),
    surface: Color(0xFF0E1511),
    surfaceHigh: Color(0xFF151F19),
    outline: Color(0xFF23332A),
    text: Color(0xFFF1F8F3),
    muted: Color(0xFF86998C),
    primary: Color(0xFF4ADE80),
    secondary: Color(0xFF22D3EE),
    good: Color(0xFF4ADE80),
    warn: Color(0xFFFFB84D),
    danger: Color(0xFFFF6B6B),
    logoFrameA: Color(0xFF08100B),
    logoFrameB: Color(0xFF12211A),
    logoA: Color(0xFF4ADE80),
    logoB: Color(0xFF22D3EE),
  );

  static const AppPalette violet = AppPalette(
    id: 'violet',
    name: 'Mor',
    brightness: Brightness.dark,
    bg: Color(0xFF09070F),
    surface: Color(0xFF110E1B),
    surfaceHigh: Color(0xFF191426),
    outline: Color(0xFF2B2440),
    text: Color(0xFFF6F2FF),
    muted: Color(0xFF9188AD),
    primary: Color(0xFFA78BFA),
    secondary: Color(0xFFF472B6),
    good: Color(0xFF4ADE9B),
    warn: Color(0xFFFFB84D),
    danger: Color(0xFFFF6B6B),
    logoFrameA: Color(0xFF0C0914),
    logoFrameB: Color(0xFF1A1428),
    logoA: Color(0xFFA78BFA),
    logoB: Color(0xFFF472B6),
  );

  static const List<AppPalette> all = [
    monoDark,
    monoLight,
    neon,
    ocean,
    sunset,
    forest,
    violet,
  ];

  static AppPalette byId(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return monoDark;
  }
}

/// Ana ekrandaki (ve karşılama / cihaz sayfasındaki) logonun rengi.
/// `auto` tema renklerini izler; diğerleri kullanıcının seçtiği sabit renktir.
class LogoStyle {
  const LogoStyle(this.id, this.name, this.colors);

  final String id;
  final String name;

  /// Boş = tema renkleri; tek renk = düz; iki renk = gradyan.
  final List<Color> colors;

  static const String autoId = 'auto';
  static const String customId = 'custom';

  static const LogoStyle auto = LogoStyle(autoId, 'Tema rengi', []);

  static const List<LogoStyle> presets = [
    auto,
    LogoStyle('white', 'Beyaz', [Color(0xFFFFFFFF)]),
    LogoStyle('silver', 'Gümüş', [Color(0xFFBDBDBD)]),
    LogoStyle('teal', 'Turkuaz', [Color(0xFF2DE2C0)]),
    LogoStyle('blue', 'Mavi', [Color(0xFF4D8BFF)]),
    LogoStyle('violet', 'Mor', [Color(0xFFA78BFA)]),
    LogoStyle('pink', 'Pembe', [Color(0xFFF472B6)]),
    LogoStyle('red', 'Kırmızı', [Color(0xFFFF5C5C)]),
    LogoStyle('orange', 'Turuncu', [Color(0xFFFF8A4D)]),
    LogoStyle('yellow', 'Sarı', [Color(0xFFFFD84D)]),
    LogoStyle('green', 'Yeşil', [Color(0xFF4ADE80)]),
    LogoStyle('g_ocean', 'Okyanus', [Color(0xFF2DE2C0), Color(0xFF4D8BFF)]),
    LogoStyle('g_sunset', 'Gün Batımı', [Color(0xFFFF8A4D), Color(0xFFFF4D8D)]),
    LogoStyle('g_aurora', 'Aurora', [Color(0xFF4ADE80), Color(0xFFA78BFA)]),
  ];

  static LogoStyle byId(String? id) {
    for (final s in presets) {
      if (s.id == id) return s;
    }
    return auto;
  }
}

/// Uygulamanın renk kaynağı. Değerler seçili temaya göre değişir; renkleri
/// her zaman `AppColors.xxx` ile okuyun (sabit/const olarak saklamayın).
/// Tema/logo değişimi [apply] ile yapılır (bkz. `AppSettings`).
class AppColors {
  AppColors._();

  static AppPalette _palette = AppPalettes.monoDark;
  static LogoStyle _logo = LogoStyle.auto;
  static Color _customLogo = const Color(0xFFFFFFFF);

  static AppPalette get palette => _palette;
  static LogoStyle get logoStyle => _logo;

  static void apply({
    required AppPalette palette,
    required LogoStyle logo,
    Color? customLogo,
  }) {
    _palette = palette;
    _logo = logo;
    if (customLogo != null) _customLogo = customLogo;
  }

  static Color get bg => _palette.bg;
  static Color get surface => _palette.surface;
  static Color get surfaceHigh => _palette.surfaceHigh;
  static Color get outline => _palette.outline;

  static Color get text => _palette.text;
  static Color get muted => _palette.muted;

  static Color get primary => _palette.primary;
  static Color get secondary => _palette.secondary;

  static Color get good => _palette.good;
  static Color get warn => _palette.warn;
  static Color get danger => _palette.danger;

  static LinearGradient get brand => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primary, secondary],
      );

  /// Logo çiziminde kullanılan renkler (tek renkse iki kez döner).
  static List<Color> get logoColors {
    if (_logo.id == LogoStyle.customId) return [_customLogo, _customLogo];
    final c = _logo.colors;
    if (c.isEmpty) return [_palette.logoA, _palette.logoB];
    if (c.length == 1) return [c[0], c[0]];
    return c;
  }

  static Color get logoFrameA => _palette.logoFrameA;
  static Color get logoFrameB => _palette.logoFrameB;

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

  /// Seçili palete göre güncel tema.
  static ThemeData get current {
    final p = AppColors.palette;
    final base = ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      scaffoldBackgroundColor: AppColors.bg,
      canvasColor: AppColors.bg,
      colorScheme: (p.isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
        surface: AppColors.surface,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.danger,
        surfaceTint: Colors.transparent,
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
        surfaceTintColor: Colors.transparent,
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
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.outline,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: TextStyle(color: AppColors.text),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  /// Durum çubuğu ve gezinme çubuğu renklerini temaya uydurur.
  static void applySystemChrome() {
    final dark = AppColors.palette.isDark;
    final icons = dark ? Brightness.light : Brightness.dark;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: icons,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: icons,
      ),
    );
  }
}
