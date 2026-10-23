/// Oyun Modu için saf (platform bağımsız, birim testli) mantık: çıktı
/// ayrıştırıcıları, komut üreticileri ve "geri alma" anlık görüntüsü.
///
/// DÜRÜST SINIR: Dışarıdan bir oyunun kare hızı ARTIRILAMAZ. Yapılabilen,
/// oyunun GPU yükünü azaltmak (çözünürlük), ekranı sabit hıza kilitlemek ve
/// üst sınır koymaktır. Oyun işlemci (CPU) kaynaklı yavaşlıyorsa kazanç
/// sınırlı olur; ısınma/pil tüketimi ise çözünürlük düşüşüyle azalır.
library;

import 'dart:convert';

import 'shell_utils.dart';

/// 9Kings (Playdigious) paket adı.
const String kNineKingsPackage = 'com.playdigious.ninekings';

final RegExp _pkgPattern = RegExp(r'^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$');
final RegExp _safeValue = RegExp(r'^[A-Za-z0-9._-]+$');
final RegExp _sizePattern = RegExp(r'^(\d{3,5})x(\d{3,5})$');

bool isSafePackage(String value) => _pkgPattern.hasMatch(value);

/// Piksel boyutu (`1220x2712`).
class PixelSize {
  const PixelSize(this.width, this.height);
  final int width;
  final int height;

  @override
  String toString() => '${width}x$height';

  @override
  bool operator ==(Object other) =>
      other is PixelSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  static PixelSize? tryParse(String value) {
    final m = _sizePattern.firstMatch(value.trim());
    if (m == null) return null;
    return PixelSize(int.parse(m.group(1)!), int.parse(m.group(2)!));
  }
}

/// `wm size` çıktısı.
class WmSize {
  const WmSize({required this.physical, this.override});
  final PixelSize physical;
  final PixelSize? override;
}

/// `wm density` çıktısı.
class WmDensity {
  const WmDensity({required this.physical, this.override});
  final int physical;
  final int? override;
}

/// ```
/// Physical size: 1220x2712
/// Override size: 813x1808
/// ```
WmSize? parseWmSize(String output) {
  PixelSize? physical;
  PixelSize? override;
  for (final line in outputLines(output)) {
    final m = RegExp(r'^(Physical|Override) size:\s*(\d+x\d+)', caseSensitive: false)
        .firstMatch(line);
    if (m == null) continue;
    final size = PixelSize.tryParse(m.group(2)!);
    if (m.group(1)!.toLowerCase() == 'physical') {
      physical = size;
    } else {
      override = size;
    }
  }
  if (physical == null) return null;
  return WmSize(physical: physical, override: override);
}

/// ```
/// Physical density: 440
/// Override density: 293
/// ```
WmDensity? parseWmDensity(String output) {
  int? physical;
  int? override;
  for (final line in outputLines(output)) {
    final m = RegExp(r'^(Physical|Override) density:\s*(\d+)', caseSensitive: false)
        .firstMatch(line);
    if (m == null) continue;
    final v = int.parse(m.group(2)!);
    if (m.group(1)!.toLowerCase() == 'physical') {
      physical = v;
    } else {
      override = v;
    }
  }
  if (physical == null) return null;
  return WmDensity(physical: physical, override: override);
}

/// `dumpsys display` satırlarından etkin ekran yenileme hızını (Hz) çıkarır.
/// Bulunamazsa `null` (biçim üreticiye göre değişir; uydurma yapılmaz).
double? parseActiveRefreshRate(String output) {
  final m = RegExp(r'(?:fps|refreshRate)=([0-9]+(?:\.[0-9]+)?)').firstMatch(output);
  if (m == null) return null;
  final v = double.tryParse(m.group(1)!);
  if (v == null || v < 20 || v > 500) return null;
  return v;
}

int _even(double v) {
  final r = v.round();
  return r.isEven ? r : r + 1;
}

/// Fiziksel boyutu [scale] (0.4–1.0) ile küçültür; en-boy oranı korunur,
/// iki kenar da çift sayıdır.
PixelSize scaledSize(PixelSize physical, double scale) {
  final s = scale.clamp(0.4, 1.0);
  return PixelSize(_even(physical.width * s), _even(physical.height * s));
}

/// Yoğunluğu aynı oranda küçültür; böylece arayüz öğeleri (dp) aynı boyutta
/// kalır, yalnızca işlenen piksel sayısı azalır.
int scaledDensity(int physicalDensity, double scale) {
  final s = scale.clamp(0.4, 1.0);
  return (physicalDensity * s).round().clamp(120, physicalDensity);
}

/// Oyun-başına çözünürlük (GameManager) yöntemi mi, tüm ekran (`wm size`) mi?
enum ResolutionMethod { perGame, wholeScreen }

/// Kullanıcının seçtiği oyun modu ayarları.
class GameModeConfig {
  const GameModeConfig({
    this.package = kNineKingsPackage,
    this.targetFps = 90,
    this.scale = 0.6,
    this.method = ResolutionMethod.perGame,
    this.lockRefreshRate = true,
    this.killBackground = true,
    this.autoRevert = true,
    this.animationsOff = false,
    this.dnd = false,
  });

  final String package;

  /// 30, 60 ya da 90.
  final int targetFps;

  /// 1.0 = çözünürlüğe dokunma; 0.5–0.9 = düşür.
  final double scale;
  final ResolutionMethod method;

  /// Ekran yenileme hızını [targetFps]'e kilitle (yalnızca 60/90'da).
  final bool lockRefreshRate;
  final bool killBackground;

  /// Oyun kapanınca cihazda çalışan bir izleyici her şeyi kendiliğinden geri
  /// alır ve oturum boyunca FPS/ısı örnekleri kaydeder (uygulama kapalı olsa da).
  final bool autoRevert;

  /// Oyun boyunca sistem animasyonlarını kapatır (SurfaceFlinger yükü azalır).
  final bool animationsOff;

  /// Oyun boyunca bildirimleri sustur (Rahatsız Etme: yalnızca öncelikliler).
  final bool dnd;

  bool get reducesResolution => scale < 0.999;

  /// Ekran kilidi Hz değeri; 30 hedefinde kilitlenmez.
  int? get lockHz => (lockRefreshRate && targetFps >= 60) ? targetFps : null;

  GameModeConfig copyWith({
    String? package,
    int? targetFps,
    double? scale,
    ResolutionMethod? method,
    bool? lockRefreshRate,
    bool? killBackground,
    bool? autoRevert,
    bool? animationsOff,
    bool? dnd,
  }) {
    return GameModeConfig(
      package: package ?? this.package,
      targetFps: targetFps ?? this.targetFps,
      scale: scale ?? this.scale,
      method: method ?? this.method,
      lockRefreshRate: lockRefreshRate ?? this.lockRefreshRate,
      killBackground: killBackground ?? this.killBackground,
      autoRevert: autoRevert ?? this.autoRevert,
      animationsOff: animationsOff ?? this.animationsOff,
      dnd: dnd ?? this.dnd,
    );
  }

  Map<String, dynamic> toJson() => {
        'package': package,
        'targetFps': targetFps,
        'scale': scale,
        'method': method.name,
        'lockRefreshRate': lockRefreshRate,
        'killBackground': killBackground,
        'autoRevert': autoRevert,
        'animationsOff': animationsOff,
        'dnd': dnd,
      };

  factory GameModeConfig.fromJson(Map<String, dynamic> json) {
    final pkg = json['package'] as String? ?? kNineKingsPackage;
    final fps = (json['targetFps'] as num?)?.toInt() ?? 90;
    final scale = (json['scale'] as num?)?.toDouble() ?? 0.6;
    final method = json['method'] == ResolutionMethod.wholeScreen.name
        ? ResolutionMethod.wholeScreen
        : ResolutionMethod.perGame;
    return GameModeConfig(
      package: isSafePackage(pkg) ? pkg : kNineKingsPackage,
      targetFps: const [30, 60, 90].contains(fps) ? fps : 90,
      scale: scale.clamp(0.4, 1.0),
      method: method,
      lockRefreshRate: json['lockRefreshRate'] as bool? ?? true,
      killBackground: json['killBackground'] as bool? ?? true,
      autoRevert: json['autoRevert'] as bool? ?? true,
      animationsOff: json['animationsOff'] as bool? ?? false,
      dnd: json['dnd'] as bool? ?? false,
    );
  }

  static GameModeConfig decode(String raw) {
    if (raw.isEmpty) return const GameModeConfig();
    try {
      return GameModeConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const GameModeConfig();
    }
  }

  String encode() => jsonEncode(toJson());
}

/// Hazır ayar kümesi (tek dokunuşla seçilir).
class GamePreset {
  const GamePreset({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.targetFps,
    required this.scale,
    required this.animationsOff,
    required this.dnd,
  });

  final String id;
  final String title;
  final String subtitle;
  final int targetFps;
  final double scale;
  final bool animationsOff;
  final bool dnd;

  /// Paket, yöntem ve arka plan seçimini koruyup yalnızca ön ayarın
  /// değerlerini uygular.
  GameModeConfig applyTo(GameModeConfig base) => base.copyWith(
        targetFps: targetFps,
        scale: scale,
        lockRefreshRate: targetFps >= 60,
        animationsOff: animationsOff,
        dnd: dnd,
      );

  /// [config] bu ön ayarla birebir aynı mı?
  bool matches(GameModeConfig config) =>
      config.targetFps == targetFps &&
      (config.scale - scale).abs() < 0.001 &&
      config.animationsOff == animationsOff &&
      config.dnd == dnd;
}

/// 9Kings gibi CPU'yu yoğun kullanan oyunlar için üç hazır ayar.
const List<GamePreset> kGamePresets = [
  GamePreset(
    id: 'cool',
    title: 'Serin ve uzun pil',
    subtitle: '30 FPS · %50 çözünürlük · animasyonlar kapalı · bildirimler sessiz',
    targetFps: 30,
    scale: 0.5,
    animationsOff: true,
    dnd: true,
  ),
  GamePreset(
    id: 'balanced',
    title: 'Dengeli',
    subtitle: '60 FPS · %60 çözünürlük · animasyonlar kapalı',
    targetFps: 60,
    scale: 0.6,
    animationsOff: true,
    dnd: false,
  ),
  GamePreset(
    id: 'max',
    title: 'En yüksek akıcılık',
    subtitle: '90 FPS · %75 çözünürlük',
    targetFps: 90,
    scale: 0.75,
    animationsOff: false,
    dnd: false,
  ),
];

/// Animasyon ölçekleri (oyun boyunca 0'a çekilir).
const List<SettingKey> kAnimationKeys = [
  SettingKey('global', 'window_animation_scale'),
  SettingKey('global', 'transition_animation_scale'),
  SettingKey('global', 'animator_duration_scale'),
];

/// Rahatsız Etme modu (0 = kapalı, 1 = yalnızca öncelikli).
const SettingKey kZenKey = SettingKey('global', 'zen_mode');

/// Çalıştırılacak tek bir adım.
class GameStep {
  const GameStep(this.label, this.command, {this.optional = false});
  final String label;
  final String command;

  /// `true` ise başarısızlık oyun modunu bozmaz (örn. üretici desteklemiyor).
  final bool optional;
}

/// Değiştirilen bir sistem ayarı (geri almak için önceki değeri saklanır).
class SettingKey {
  const SettingKey(this.namespace, this.key);
  final String namespace; // system | secure | global
  final String key;

  String get id => '$namespace:$key';
  String get readCommand => 'settings get $namespace $key';
}

/// Ekranı sabit hıza kilitlemek için yazılan ayarlar (AOSP + Xiaomi).
const List<SettingKey> kRefreshKeys = [
  SettingKey('system', 'peak_refresh_rate'),
  SettingKey('system', 'min_refresh_rate'),
  SettingKey('system', 'user_refresh_rate'),
  SettingKey('secure', 'miui_refresh_rate'),
];

/// `settings get` çıktısı "null" ise ayar daha önce yoktu.
String? normalizeSettingValue(String output) {
  final v = output.trim();
  if (v.isEmpty || v == 'null') return null;
  return _safeValue.hasMatch(v) ? v : null;
}

/// Oyun modu açılmadan ÖNCEKİ cihaz durumu. Disk'e yazılır; uygulama
/// kapansa bile "Geri Al" doğru değerlere döner.
class GameSession {
  const GameSession({
    required this.package,
    required this.settings,
    required this.touchedGameManager,
    this.sizeOverride,
    this.densityOverride,
    this.changedScreen = false,
    required this.startedAtMs,
  });

  final String package;

  /// `namespace:key` -> önceki değer (`null` = ayar yoktu).
  final Map<String, String?> settings;
  final bool touchedGameManager;

  /// Önceki `wm size` override'ı (`null` = yoktu).
  final String? sizeOverride;
  final String? densityOverride;

  /// Bu oturum `wm size/density` değiştirdi mi?
  final bool changedScreen;
  final int startedAtMs;

  Map<String, dynamic> toJson() => {
        'package': package,
        'settings': settings,
        'touchedGameManager': touchedGameManager,
        'sizeOverride': sizeOverride,
        'densityOverride': densityOverride,
        'changedScreen': changedScreen,
        'startedAtMs': startedAtMs,
      };

  factory GameSession.fromJson(Map<String, dynamic> json) {
    final raw = (json['settings'] as Map?) ?? const {};
    return GameSession(
      package: json['package'] as String,
      settings: {for (final e in raw.entries) '${e.key}': e.value as String?},
      touchedGameManager: json['touchedGameManager'] as bool? ?? false,
      sizeOverride: json['sizeOverride'] as String?,
      densityOverride: json['densityOverride'] as String?,
      changedScreen: json['changedScreen'] as bool? ?? false,
      startedAtMs: (json['startedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  static GameSession? decode(String raw) {
    if (raw.isEmpty) return null;
    try {
      final s = GameSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      return isSafePackage(s.package) ? s : null;
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(toJson());
}

/// GameManager `--downscale` için izin verilen değerlere yuvarlar.
String downscaleArg(double scale) {
  if (scale >= 0.999) return 'disable';
  final stepped = (scale.clamp(0.3, 0.9) * 20).round() / 20; // 0.05 adım
  final text = stepped.toStringAsFixed(2);
  return text.endsWith('0') ? text.substring(0, text.length - 1) : text;
}

/// Oyun modunu AÇAN adımlar. [physicalSize]/[physicalDensity] yalnızca
/// [ResolutionMethod.wholeScreen] için gerekir.
List<GameStep> buildApplySteps(
  GameModeConfig config, {
  PixelSize? physicalSize,
  int? physicalDensity,
}) {
  final pkg = config.package;
  if (!isSafePackage(pkg)) return const [];
  final steps = <GameStep>[];

  if (config.killBackground) {
    steps.add(const GameStep('Arka plan temizliği', 'am kill-all', optional: true));
  }

  // Oyun-başına (Android GameManager) üst sınır + çözünürlük.
  final perGameScale = config.method == ResolutionMethod.perGame && config.reducesResolution;
  steps.add(GameStep(
    'Oyun profili (${config.targetFps} FPS sınırı'
    '${perGameScale ? ', %${(config.scale * 100).round()} çözünürlük' : ''})',
    'cmd game set --mode performance --fps ${config.targetFps}'
        '${perGameScale ? ' --downscale ${downscaleArg(config.scale)}' : ''} $pkg',
    optional: true,
  ));
  steps.add(GameStep('Performans modu', 'cmd game mode performance $pkg', optional: true));

  final hz = config.lockHz;
  if (hz != null) {
    final v = '$hz.0';
    steps.add(GameStep(
      'Ekranı $hz Hz\'e kilitle',
      'settings put system peak_refresh_rate $v; '
          'settings put system min_refresh_rate $v; '
          'settings put system user_refresh_rate $hz; '
          'settings put secure miui_refresh_rate $hz',
    ));
  }

  if (config.animationsOff) {
    steps.add(GameStep(
      'Sistem animasyonlarını kapat',
      [for (final k in kAnimationKeys) 'settings put ${k.namespace} ${k.key} 0'].join('; '),
      optional: true,
    ));
  }
  if (config.dnd) {
    steps.add(GameStep(
      'Bildirimleri sustur (Rahatsız Etme)',
      'settings put ${kZenKey.namespace} ${kZenKey.key} 1',
      optional: true,
    ));
  }

  if (config.method == ResolutionMethod.wholeScreen &&
      config.reducesResolution &&
      physicalSize != null &&
      physicalDensity != null) {
    final size = scaledSize(physicalSize, config.scale);
    final density = scaledDensity(physicalDensity, config.scale);
    steps.add(GameStep(
      'Ekran çözünürlüğü $size',
      'wm size $size; wm density $density',
    ));
  }
  return steps;
}

/// [keys] içinden oturumda kayıtlı olanların eski değerini yazan komutlar
/// (eski değer yoksa `settings delete`). Güvensiz değerler komuta girmez.
List<String> _restoreCommands(GameSession session, List<SettingKey> keys) {
  final cmds = <String>[];
  for (final key in keys) {
    if (!session.settings.containsKey(key.id)) continue;
    final old = session.settings[key.id];
    if (old != null && _safeValue.hasMatch(old)) {
      cmds.add('settings put ${key.namespace} ${key.key} $old');
    } else {
      cmds.add('settings delete ${key.namespace} ${key.key}');
    }
  }
  return cmds;
}

/// Oturum anlık görüntüsünden, her şeyi ESKİ HALİNE getiren adımlar.
List<GameStep> buildRevertSteps(GameSession session) {
  final steps = <GameStep>[];

  if (session.changedScreen) {
    final size = session.sizeOverride;
    final density = session.densityOverride;
    final sizeCmd = (size != null && PixelSize.tryParse(size) != null)
        ? 'wm size $size'
        : 'wm size reset';
    final densityCmd = (density != null && RegExp(r'^\d{2,4}$').hasMatch(density))
        ? 'wm density $density'
        : 'wm density reset';
    steps.add(GameStep('Ekran çözünürlüğünü geri al', '$sizeCmd; $densityCmd'));
  }

  final refresh = _restoreCommands(session, kRefreshKeys);
  if (refresh.isNotEmpty) {
    steps.add(GameStep('Ekran yenileme ayarlarını geri al', refresh.join('; ')));
  }
  final anim = _restoreCommands(session, kAnimationKeys);
  if (anim.isNotEmpty) {
    steps.add(GameStep('Animasyon ayarlarını geri al', anim.join('; ')));
  }
  final zen = _restoreCommands(session, const [kZenKey]);
  if (zen.isNotEmpty) {
    steps.add(GameStep('Rahatsız Etme ayarını geri al', zen.join('; ')));
  }

  if (session.touchedGameManager && isSafePackage(session.package)) {
    steps.add(GameStep(
      'Oyun profilini sıfırla',
      'cmd game reset ${session.package}; cmd game mode standard ${session.package}',
      optional: true,
    ));
  }
  return steps;
}
