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

  static const AppPalette crimson = AppPalette(
    id: 'crimson',
    name: 'Kızıl',
    brightness: Brightness.dark,
    bg: Color(0xFF0B0607),
    surface: Color(0xFF150D0E),
    surfaceHigh: Color(0xFF201415),
    outline: Color(0xFF352125),
    text: Color(0xFFFFF2F3),
    muted: Color(0xFFA88B8E),
    primary: Color(0xFFFF4D5E),
    secondary: Color(0xFFFF8A4D),
    good: Color(0xFF4ADE80),
    warn: Color(0xFFFFC84D),
    danger: Color(0xFFFF8A8A),
    logoFrameA: Color(0xFF0F0708),
    logoFrameB: Color(0xFF24100F),
    logoA: Color(0xFFFF4D5E),
    logoB: Color(0xFFFF8A4D),
  );

  static const AppPalette amber = AppPalette(
    id: 'amber',
    name: 'Altın',
    brightness: Brightness.dark,
    bg: Color(0xFF0A0805),
    surface: Color(0xFF141009),
    surfaceHigh: Color(0xFF1E1810),
    outline: Color(0xFF342B1B),
    text: Color(0xFFFFF8EB),
    muted: Color(0xFFA89A7E),
    primary: Color(0xFFFFC84D),
    secondary: Color(0xFFFF9F43),
    good: Color(0xFF6EE7A0),
    warn: Color(0xFFFFB84D),
    danger: Color(0xFFFF6B6B),
    logoFrameA: Color(0xFF100C06),
    logoFrameB: Color(0xFF231A0C),
    logoA: Color(0xFFFFC84D),
    logoB: Color(0xFFFF9F43),
  );

  static const AppPalette ice = AppPalette(
    id: 'ice',
    name: 'Buz',
    brightness: Brightness.dark,
    bg: Color(0xFF050A0D),
    surface: Color(0xFF0C141A),
    surfaceHigh: Color(0xFF131E26),
    outline: Color(0xFF1F3140),
    text: Color(0xFFEFFAFF),
    muted: Color(0xFF84A0AD),
    primary: Color(0xFF5FE3FF),
    secondary: Color(0xFF8AA8FF),
    good: Color(0xFF4ADE9B),
    warn: Color(0xFFFFB84D),
    danger: Color(0xFFFF6B6B),
    logoFrameA: Color(0xFF060D12),
    logoFrameB: Color(0xFF10202C),
    logoA: Color(0xFF5FE3FF),
    logoB: Color(0xFF8AA8FF),
  );

  static const AppPalette rose = AppPalette(
    id: 'rose',
    name: 'Gül',
    brightness: Brightness.dark,
    bg: Color(0xFF0D0709),
    surface: Color(0xFF170E12),
    surfaceHigh: Color(0xFF22151B),
    outline: Color(0xFF3A2330),
    text: Color(0xFFFFF1F6),
    muted: Color(0xFFAD8A9A),
    primary: Color(0xFFFF7AB6),
    secondary: Color(0xFFC084FC),
    good: Color(0xFF4ADE9B),
    warn: Color(0xFFFFB84D),
    danger: Color(0xFFFF6B6B),
    logoFrameA: Color(0xFF11080C),
    logoFrameB: Color(0xFF261320),
    logoA: Color(0xFFFF7AB6),
    logoB: Color(0xFFC084FC),
  );

  static const AppPalette nord = AppPalette(
    id: 'nord',
    name: 'Nord',
    brightness: Brightness.dark,
    bg: Color(0xFF1B1F27),
    surface: Color(0xFF242933),
    surfaceHigh: Color(0xFF2E3440),
    outline: Color(0xFF3B4252),
    text: Color(0xFFECEFF4),
    muted: Color(0xFF8F9BB3),
    primary: Color(0xFF88C0D0),
    secondary: Color(0xFF81A1C1),
    good: Color(0xFFA3BE8C),
    warn: Color(0xFFEBCB8B),
    danger: Color(0xFFBF616A),
    logoFrameA: Color(0xFF1A1E26),
    logoFrameB: Color(0xFF2E3440),
    logoA: Color(0xFF88C0D0),
    logoB: Color(0xFF81A1C1),
  );

  static const AppPalette dracula = AppPalette(
    id: 'dracula',
    name: 'Drakula',
    brightness: Brightness.dark,
    bg: Color(0xFF191A21),
    surface: Color(0xFF21222C),
    surfaceHigh: Color(0xFF282A36),
    outline: Color(0xFF3A3C4E),
    text: Color(0xFFF8F8F2),
    muted: Color(0xFF9AA0C0),
    primary: Color(0xFFBD93F9),
    secondary: Color(0xFFFF79C6),
    good: Color(0xFF50FA7B),
    warn: Color(0xFFF1FA8C),
    danger: Color(0xFFFF5555),
    logoFrameA: Color(0xFF15161C),
    logoFrameB: Color(0xFF282A36),
    logoA: Color(0xFFBD93F9),
    logoB: Color(0xFFFF79C6),
  );

  static const AppPalette matrix = AppPalette(
    id: 'matrix',
    name: 'Matrix',
    brightness: Brightness.dark,
    bg: Color(0xFF000000),
    surface: Color(0xFF060D08),
    surfaceHigh: Color(0xFF0C1710),
    outline: Color(0xFF15301E),
    text: Color(0xFFD6FFE3),
    muted: Color(0xFF6FA582),
    primary: Color(0xFF00FF66),
    secondary: Color(0xFF00C2A8),
    good: Color(0xFF00FF66),
    warn: Color(0xFFFFD84D),
    danger: Color(0xFFFF5C5C),
    logoFrameA: Color(0xFF000000),
    logoFrameB: Color(0xFF07140B),
    logoA: Color(0xFF00FF66),
    logoB: Color(0xFF00C2A8),
  );

  static const AppPalette sky = AppPalette(
    id: 'sky',
    name: 'Gökyüzü',
    brightness: Brightness.light,
    bg: Color(0xFFEEF4FB),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE4ECF7),
    outline: Color(0xFFD3DEEE),
    text: Color(0xFF0B1626),
    muted: Color(0xFF5B6B82),
    primary: Color(0xFF1F6FEB),
    secondary: Color(0xFF7C5CFF),
    good: Color(0xFF138A5B),
    warn: Color(0xFFC77700),
    danger: Color(0xFFD62F2F),
    logoFrameA: Color(0xFF0B1626),
    logoFrameB: Color(0xFF16294A),
    logoA: Color(0xFF5AA9FF),
    logoB: Color(0xFF7C6CFF),
  );

  static const AppPalette mint = AppPalette(
    id: 'mint',
    name: 'Nane',
    brightness: Brightness.light,
    bg: Color(0xFFEEF7F2),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE2F0E8),
    outline: Color(0xFFCFE3D8),
    text: Color(0xFF0B1F16),
    muted: Color(0xFF55705F),
    primary: Color(0xFF138A5B),
    secondary: Color(0xFF0E7490),
    good: Color(0xFF138A5B),
    warn: Color(0xFFC77700),
    danger: Color(0xFFD62F2F),
    logoFrameA: Color(0xFF08140E),
    logoFrameB: Color(0xFF12281C),
    logoA: Color(0xFF4ADE80),
    logoB: Color(0xFF22D3EE),
  );

  static const AppPalette cream = AppPalette(
    id: 'cream',
    name: 'Krem',
    brightness: Brightness.light,
    bg: Color(0xFFF7F2E9),
    surface: Color(0xFFFFFDF8),
    surfaceHigh: Color(0xFFEFE8DA),
    outline: Color(0xFFE0D6C3),
    text: Color(0xFF1F1710),
    muted: Color(0xFF7A6B58),
    primary: Color(0xFFB4540A),
    secondary: Color(0xFF9A3412),
    good: Color(0xFF3F7D20),
    warn: Color(0xFFB7791F),
    danger: Color(0xFFC0392B),
    logoFrameA: Color(0xFF140E08),
    logoFrameB: Color(0xFF2A1B10),
    logoA: Color(0xFFFF9F43),
    logoB: Color(0xFFFF6B3D),
  );

  static const AppPalette lavender = AppPalette(
    id: 'lavender',
    name: 'Lavanta',
    brightness: Brightness.light,
    bg: Color(0xFFF3F0FA),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFE9E4F5),
    outline: Color(0xFFD9D2EC),
    text: Color(0xFF16102A),
    muted: Color(0xFF6B6385),
    primary: Color(0xFF6D4AE0),
    secondary: Color(0xFFD946A8),
    good: Color(0xFF138A5B),
    warn: Color(0xFFC77700),
    danger: Color(0xFFD62F2F),
    logoFrameA: Color(0xFF0E0A1C),
    logoFrameB: Color(0xFF1E1536),
    logoA: Color(0xFFA78BFA),
    logoB: Color(0xFFF472B6),
  );

  static const List<AppPalette> all = [
    monoDark,
    neon,
    ocean,
    sunset,
    forest,
    violet,
    crimson,
    amber,
    ice,
    rose,
    nord,
    dracula,
    matrix,
    monoLight,
    sky,
    mint,
    cream,
    lavender,
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
