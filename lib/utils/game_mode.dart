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

/// Yapılandırma için yer tutucu paket adı (oyun seçilmediyse). Arayüz,
/// kullanıcı bir oyun eklemeden bu paketi göstermez ya da başlatmaz.
const String kDefaultGamePackage = 'com.playdigious.ninekings';

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

/// Android GameManager güç profili. `battery` en serin, `performance` en sıcak
/// profildir; birçok cihazda `performance` işlemci/GPU hızını yükseltir.
enum GamePower { battery, standard, performance }

extension GamePowerInfo on GamePower {
  /// `cmd game` komutuna verilen değer.
  String get arg => name;

  String get label {
    switch (this) {
      case GamePower.battery:
        return 'Serin (pil)';
      case GamePower.standard:
        return 'Standart';
      case GamePower.performance:
        return 'Performans';
    }
  }

  String get hint {
    switch (this) {
      case GamePower.battery:
        return 'Sistem oyunu enerji tasarruflu çalıştırır; ısınma en az.';
      case GamePower.standard:
        return 'Üreticinin varsayılan oyun davranışı.';
      case GamePower.performance:
        return 'İşlemci/GPU daha çok çalışır; daha akıcı ama belirgin daha sıcak.';
    }
  }
}

/// Pil sıcaklığı koruması için seçilebilir eşikler (°C). 0 = kapalı.
const List<int> kGuardTempChoices = [0, 38, 40, 42, 44];

/// Kullanıcının seçtiği oyun modu ayarları.
class GameModeConfig {
  const GameModeConfig({
    this.package = kDefaultGamePackage,
    this.targetFps = 90,
    this.scale = 0.6,
    this.method = ResolutionMethod.perGame,
    this.lockRefreshRate = true,
    this.killBackground = true,
    this.autoRevert = true,
    this.animationsOff = false,
    this.dnd = false,
    this.dimScreen = false,
    this.cpuCap = false,
    this.powerProfile = GamePower.performance,
    this.batterySaver = false,
    this.guardTempC = 40,
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

  /// Oyun boyunca ekran parlaklığını mevcut değerin %60'ına indirir
  /// (AMOLED'de ısı ve pilin en büyük kalemlerinden biri).
  final bool dimScreen;

  /// En güçlü iki işlemci kümesinin azami hızını %70'e sınırlar (YALNIZCA
  /// root ile; hız dalgalanması ve ısıl kısıtlama azalır).
  final bool cpuCap;

  /// GameManager güç profili (serin/standart/performans).
  final GamePower powerProfile;

  /// Oyun boyunca sistemin Pil Tasarrufu modunu açar (eski değer geri yazılır).
  final bool batterySaver;

  /// Pil sıcaklığı bu değere (°C) ulaşınca izleyici ek önlem alır; 0 = kapalı.
  final int guardTempC;

  bool get reducesResolution => scale < 0.999;

  /// Ekran kilidi Hz değeri; 30 FPS hedefinde 60 Hz'e (30'un katı) kilitlenir.
  int? get lockHz => lockRefreshRate ? (targetFps >= 60 ? targetFps : 60) : null;

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
    bool? dimScreen,
    bool? cpuCap,
    GamePower? powerProfile,
    bool? batterySaver,
    int? guardTempC,
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
      dimScreen: dimScreen ?? this.dimScreen,
      cpuCap: cpuCap ?? this.cpuCap,
      powerProfile: powerProfile ?? this.powerProfile,
      batterySaver: batterySaver ?? this.batterySaver,
      guardTempC: guardTempC ?? this.guardTempC,
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
        'dimScreen': dimScreen,
        'cpuCap': cpuCap,
        'powerProfile': powerProfile.name,
        'batterySaver': batterySaver,
        'guardTempC': guardTempC,
      };

  factory GameModeConfig.fromJson(Map<String, dynamic> json) {
    final pkg = json['package'] as String? ?? kDefaultGamePackage;
    final fps = (json['targetFps'] as num?)?.toInt() ?? 90;
    final scale = (json['scale'] as num?)?.toDouble() ?? 0.6;
    final method = json['method'] == ResolutionMethod.wholeScreen.name
        ? ResolutionMethod.wholeScreen
        : ResolutionMethod.perGame;
    return GameModeConfig(
      package: isSafePackage(pkg) ? pkg : kDefaultGamePackage,
      targetFps: const [30, 60, 90].contains(fps) ? fps : 90,
      scale: scale.clamp(0.4, 1.0),
      method: method,
      lockRefreshRate: json['lockRefreshRate'] as bool? ?? true,
      killBackground: json['killBackground'] as bool? ?? true,
      autoRevert: json['autoRevert'] as bool? ?? true,
      animationsOff: json['animationsOff'] as bool? ?? false,
      dnd: json['dnd'] as bool? ?? false,
      dimScreen: json['dimScreen'] as bool? ?? false,
      cpuCap: json['cpuCap'] as bool? ?? false,
      powerProfile: GamePower.values.firstWhere(
        (g) => g.name == json['powerProfile'],
        orElse: () => GamePower.performance,
      ),
      batterySaver: json['batterySaver'] as bool? ?? false,
      guardTempC: kGuardTempChoices.contains((json['guardTempC'] as num?)?.toInt())
          ? (json['guardTempC'] as num).toInt()
          : 40,
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
    this.dimScreen = false,
    this.cpuCap = false,
    this.powerProfile = GamePower.performance,
    this.batterySaver = false,
    this.guardTempC = 40,
    this.icon = 0,
  });

  final String id;
  final String title;
  final String subtitle;
  final int targetFps;
  final double scale;
  final bool animationsOff;
  final bool dnd;
  final bool dimScreen;
  final bool cpuCap;
  final GamePower powerProfile;
  final bool batterySaver;
  final int guardTempC;

  /// Arayüzün seçtiği simge sırası (saf mantık katmanı Flutter'a bağlı değil).
  final int icon;

  /// Paket, yöntem ve arka plan seçimini koruyup yalnızca ön ayarın
  /// değerlerini uygular.
  GameModeConfig applyTo(GameModeConfig base) => base.copyWith(
        targetFps: targetFps,
        scale: scale,
        lockRefreshRate: true,
        animationsOff: animationsOff,
        dnd: dnd,
        dimScreen: dimScreen,
        cpuCap: cpuCap,
        powerProfile: powerProfile,
        batterySaver: batterySaver,
        guardTempC: guardTempC,
      );

  /// [config] bu ön ayarla birebir aynı mı?
  bool matches(GameModeConfig config) =>
      config.targetFps == targetFps &&
      (config.scale - scale).abs() < 0.001 &&
      config.animationsOff == animationsOff &&
      config.dnd == dnd &&
      config.dimScreen == dimScreen &&
      config.cpuCap == cpuCap &&
      config.powerProfile == powerProfile &&
      config.batterySaver == batterySaver &&
      config.guardTempC == guardTempC;
}

/// Her oyunda kullanılabilen hazır ayarlar (en seriniden en akıcıya).
const List<GamePreset> kGamePresets = [
  GamePreset(
    id: 'ice',
    title: 'Buz',
    subtitle: 'En serin: 30 FPS · %40 çözünürlük · serin güç profili · Pil Tasarrufu · '
        'parlaklık kısık · animasyonlar kapalı · bildirimler sessiz · ısı koruması 38 °C.',
    targetFps: 30,
    scale: 0.4,
    animationsOff: true,
    dnd: true,
    dimScreen: true,
    cpuCap: true,
    powerProfile: GamePower.battery,
    batterySaver: true,
    guardTempC: 38,
    icon: 0,
  ),
  GamePreset(
    id: 'cool',
    title: 'Serin',
    subtitle: '30 FPS · %50 çözünürlük · serin güç profili · parlaklık kısık · animasyonlar kapalı · '
        'bildirimler sessiz · ısı koruması 40 °C. Root varsa işlemci hızı da sınırlanır.',
    targetFps: 30,
    scale: 0.5,
    animationsOff: true,
    dnd: true,
    dimScreen: true,
    cpuCap: true,
    powerProfile: GamePower.battery,
    batterySaver: false,
    guardTempC: 40,
    icon: 1,
  ),
  GamePreset(
    id: 'balanced',
    title: 'Dengeli',
    subtitle: '60 FPS · %60 çözünürlük · standart güç profili · animasyonlar kapalı · '
        'ısı koruması 42 °C. Daha akıcı, daha çok ısınır.',
    targetFps: 60,
    scale: 0.6,
    animationsOff: true,
    dnd: false,
    powerProfile: GamePower.standard,
    guardTempC: 42,
    icon: 2,
  ),
  GamePreset(
    id: 'smooth',
    title: 'Akıcı',
    subtitle: '60 FPS · %75 çözünürlük · performans profili · bildirimler sessiz · '
        'ısı koruması 44 °C. Telefon belirgin ısınır.',
    targetFps: 60,
    scale: 0.75,
    animationsOff: true,
    dnd: true,
    powerProfile: GamePower.performance,
    guardTempC: 44,
    icon: 3,
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

/// Ekran parlaklığı (önce değer, sonra mod geri yazılır).
const List<SettingKey> kBrightnessKeys = [
  SettingKey('system', 'screen_brightness'),
  SettingKey('system', 'screen_brightness_mode'),
];

/// Sistem Pil Tasarrufu (0 = kapalı, 1 = açık).
const SettingKey kLowPowerKey = SettingKey('global', 'low_power');

/// Parlaklık düşürme oranı (mevcut değerin yüzdesi) ve ısı korumasındaki oran.
const double kDimFraction = 0.6;
const double kGuardDimFraction = 0.35;

/// İşlemci hız sınırı oranları (normal / ısı koruması).
const double kCpuCapFraction = 0.7;
const double kGuardCpuFraction = 0.55;

final RegExp _policyName = RegExp(r'^policy\d{1,2}$');
final RegExp _digits = RegExp(r'^\d{4,8}$');

/// Bir işlemci frekans kümesi (`policyN`): şimdiki azami ve donanım azami (kHz).
class CpuPolicy {
  const CpuPolicy(this.name, this.curMax, this.hwMax);
  final String name;
  final int curMax;
  final int hwMax;
}

/// Okuma komutu: her küme için `policyN şimdikiAzami donanımAzami`.
const String kCpuPolicyReadCommand =
    r'for p in /sys/devices/system/cpu/cpufreq/policy*; do '
    r'echo "$(basename $p) $(cat $p/scaling_max_freq) $(cat $p/cpuinfo_max_freq)"; done';

List<CpuPolicy> parseCpuPolicies(String output) {
  final result = <CpuPolicy>[];
  for (final line in outputLines(output)) {
    final p = line.split(RegExp(r'\s+'));
    if (p.length != 3 || !_policyName.hasMatch(p[0])) continue;
    final cur = int.tryParse(p[1]);
    final hw = int.tryParse(p[2]);
    if (cur == null || hw == null || cur <= 0 || hw <= 0) continue;
    result.add(CpuPolicy(p[0], cur, hw));
  }
  return result;
}

/// Donanım hızı en yüksek [count] küme (oyunu yükleyen büyük çekirdekler).
List<CpuPolicy> topPolicies(List<CpuPolicy> all, {int count = 2}) {
  final sorted = [...all]..sort((a, b) => b.hwMax.compareTo(a.hwMax));
  return sorted.take(count).toList();
}

String _cpuWrite(String name, int khz) =>
    'echo $khz > /sys/devices/system/cpu/cpufreq/$name/scaling_max_freq';

/// Kümelerin azami hızını [fraction] oranına çeker.
String cpuCapCommand(List<CpuPolicy> policies, double fraction) {
  return [
    for (final p in policies)
      if (_policyName.hasMatch(p.name)) _cpuWrite(p.name, (p.hwMax * fraction).round()),
  ].join('; ');
}

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
    this.cpuMax = const {},
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

  /// `policyN` -> önceki `scaling_max_freq` (kHz); yalnızca işlemci sınırı
  /// uygulandıysa dolu.
  final Map<String, String> cpuMax;

  final int startedAtMs;

  Map<String, dynamic> toJson() => {
        'package': package,
        'settings': settings,
        'touchedGameManager': touchedGameManager,
        'sizeOverride': sizeOverride,
        'densityOverride': densityOverride,
        'changedScreen': changedScreen,
        'cpuMax': cpuMax,
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
      cpuMax: {
        for (final e in ((json['cpuMax'] as Map?) ?? const {}).entries)
          if (_policyName.hasMatch('${e.key}') && _digits.hasMatch('${e.value}'))
            '${e.key}': '${e.value}',
      },
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
  int? brightness,
  List<CpuPolicy>? cpuPolicies,
}) {
  final pkg = config.package;
  if (!isSafePackage(pkg)) return const [];
  final steps = <GameStep>[];

  if (config.killBackground) {
    steps.add(const GameStep('Arka plan temizliği', 'am kill-all', optional: true));
  }

  // Oyun-başına (Android GameManager) üst sınır + çözünürlük.
  final perGameScale = config.method == ResolutionMethod.perGame && config.reducesResolution;
  final mode = config.powerProfile.arg;
  steps.add(GameStep(
    'Oyun profili (${config.targetFps} FPS sınırı'
    '${perGameScale ? ', %${(config.scale * 100).round()} çözünürlük' : ''})',
    'cmd game set --mode $mode --fps ${config.targetFps}'
        '${perGameScale ? ' --downscale ${downscaleArg(config.scale)}' : ''} $pkg',
    optional: true,
  ));
  steps.add(GameStep(
    'Güç profili: ${config.powerProfile.label}',
    'cmd game mode $mode $pkg',
    optional: true,
  ));

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
  if (config.dimScreen && brightness != null && brightness > 1) {
    final dimmed = (brightness * kDimFraction).round().clamp(1, brightness);
    steps.add(GameStep(
      'Ekran parlaklığını kıs',
      'settings put system screen_brightness_mode 0; settings put system screen_brightness $dimmed',
      optional: true,
    ));
  }
  if (config.cpuCap && cpuPolicies != null && cpuPolicies.isNotEmpty) {
    final cmd = cpuCapCommand(topPolicies(cpuPolicies), kCpuCapFraction);
    if (cmd.isNotEmpty) {
      steps.add(GameStep('İşlemci hızını sınırla (%70)', cmd, optional: true));
    }
  }
  if (config.batterySaver) {
    steps.add(GameStep(
      'Pil Tasarrufu\'nu aç',
      'settings put ${kLowPowerKey.namespace} ${kLowPowerKey.key} 1',
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
  final bright = _restoreCommands(session, kBrightnessKeys);
  if (bright.isNotEmpty) {
    steps.add(GameStep('Ekran parlaklığını geri al', bright.join('; ')));
  }
  final cpu = <String>[
    for (final e in session.cpuMax.entries)
      if (_policyName.hasMatch(e.key) && _digits.hasMatch(e.value))
        _cpuWrite(e.key, int.parse(e.value)),
  ];
  if (cpu.isNotEmpty) {
    steps.add(GameStep('İşlemci sınırını geri al', cpu.join('; '), optional: true));
  }
  final lowPower = _restoreCommands(session, const [kLowPowerKey]);
  if (lowPower.isNotEmpty) {
    steps.add(GameStep('Pil Tasarrufu ayarını geri al', lowPower.join('; '), optional: true));
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

/// Isı koruması: oyun sırasında ısıl durum ya da pil sıcaklığı yükselirse
/// izleyicinin uyguladığı ek önlemler (Pil Tasarrufu, işlemci sınırı %55'e,
/// parlaklık özgün değerin %35'ine).
/// Geri alma, özgün değerleri zaten yazdığı için ayrıca geri alınması gerekmez.
List<String> buildGuardCommands(GameSession session) {
  final cmds = <String>[];
  if (session.cpuMax.isNotEmpty) {
    final policies = <CpuPolicy>[
      for (final e in session.cpuMax.entries)
        if (_policyName.hasMatch(e.key) && _digits.hasMatch(e.value))
          CpuPolicy(e.key, int.parse(e.value), int.parse(e.value)),
    ];
    final cmd = cpuCapCommand(policies, kGuardCpuFraction);
    if (cmd.isNotEmpty) cmds.add(cmd);
  }
  if (session.settings.containsKey(kLowPowerKey.id)) {
    cmds.add('settings put ${kLowPowerKey.namespace} ${kLowPowerKey.key} 1');
  }
  const key = 'system:screen_brightness';
  final orig = int.tryParse(session.settings[key] ?? '');
  if (session.settings.containsKey(key) && orig != null && orig > 1) {
    final v = (orig * kGuardDimFraction).round().clamp(1, orig);
    cmds.add('settings put system screen_brightness_mode 0; settings put system screen_brightness $v');
  }
  return cmds;
}

/// Oyunun çözünürlük kademeleri (net → bulanık).
const List<double> kScaleSteps = [1.0, 0.75, 0.6, 0.5, 0.4];

/// Bir sonraki oturum için ayar önerisi.
class ScaleSuggestion {
  const ScaleSuggestion(this.scale, this.reason, {this.fps});
  final double scale;
  final String reason;

  /// Önerilen kare hızı sınırı (yalnızca değişecekse dolu).
  final int? fps;
}

/// En yakın kademenin sırası.
int scaleIndex(double scale) {
  var best = 0;
  var diff = double.infinity;
  for (var i = 0; i < kScaleSteps.length; i++) {
    final d = (kScaleSteps[i] - scale).abs();
    if (d < diff) {
      diff = d;
      best = i;
    }
  }
  return best;
}
