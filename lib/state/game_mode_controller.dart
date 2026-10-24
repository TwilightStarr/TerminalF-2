import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/apps_service.dart';
import '../services/settings_service.dart';
import '../utils/game_mode.dart';
import '../utils/game_probe.dart';
import '../utils/game_watchdog.dart';
import '../utils/game_suggest.dart';
import 'control_controller.dart';

/// Tek bir adımın sonucu.
class GameStepResult {
  const GameStepResult({
    required this.label,
    required this.ok,
    required this.optional,
    this.detail = '',
  });

  final String label;
  final bool ok;
  final bool optional;
  final String detail;
}

/// Oyun modunu açma/kapama işleminin toplu sonucu.
class GameRunResult {
  const GameRunResult(this.steps, {this.note});

  final List<GameStepResult> steps;
  final String? note;

  /// Zorunlu adımların hepsi başarılı mı? (Opsiyonel adımlar sayılmaz.)
  bool get ok => steps.every((s) => s.ok || s.optional) && note == null;

  int get applied => steps.where((s) => s.ok).length;
  List<GameStepResult> get optionalFailed =>
      steps.where((s) => !s.ok && s.optional).toList();
  List<GameStepResult> get requiredFailed =>
      steps.where((s) => !s.ok && !s.optional).toList();

  String get summary {
    if (note != null) return note!;
    final parts = <String>['${steps.where((s) => s.ok).length}/${steps.length} adım uygulandı'];
    if (optionalFailed.isNotEmpty) {
      parts.add('${optionalFailed.length} adım bu cihazda desteklenmedi');
    }
    if (requiredFailed.isNotEmpty) parts.add('${requiredFailed.length} adım başarısız');
    return parts.join(' · ');
  }
}

/// Oyun Modu'na eklenmiş bir oyun (her oyunun kendi ayarı vardır).
class SavedGame {
  const SavedGame(this.package, this.name);
  final String package;
  final String name;
}

/// "Oyun Modu": ağır oyunlar için GPU yükünü azaltır, ekranı
/// sabit hıza kilitler, kare üst sınırı koyar ve OYUN BİTİNCE her şeyi
/// ESKİ HALİNE döndürür.
///
/// Güvenlik: değişiklik yapılmadan ÖNCE eski değerler diske yazılır; uygulama
/// kapansa ya da çökse bile "Geri Al" doğru değerlere döner.
class GameModeController extends ChangeNotifier {
  GameModeController({
    required this.control,
    SettingsService? store,
    Future<void> Function(String package)? launcher,
    Future<void> Function(Duration)? delay,
  })  : _store = store ?? SettingsService(),
        _launcher = launcher ?? AppsService().launch,
        _delay = delay ?? Future<void>.delayed;

  static const String _configKey = 'game_config';
  static const String _sessionKey = 'game_session';
  static const String _profilesKey = 'game_profiles';
  static const String _lastRunKey = 'game_last_run';

  final ControlController control;
  final SettingsService _store;
  final Future<void> Function(String package) _launcher;
  final Future<void> Function(Duration) _delay;

  /// Paket adı -> o oyunun ayarı. Sıra, ekleme sırasıdır.
  final Map<String, GameModeConfig> _profiles = {};
  final Map<String, String> _names = {};
  String? _selected;
  String? _lastPackage;
  int? _lastTargetFps;
  GameSession? _session;
  bool _busy = false;
  bool _disposed = false;
  double? _displayHz;
  bool? _installed;
  GameRunResult? _lastResult;
  bool? _watchdogAlive;
  SessionStats? _stats;
  String? _foreground;
  String? _syncNote;

  /// Seçili oyunun ayarı. Hiç oyun seçilmediyse varsayılan yapılandırma.
  GameModeConfig get config {
    final s = _selected;
    return (s == null ? null : _profiles[s]) ?? const GameModeConfig();
  }

  /// Eklenmiş oyunlar (ekleme sırasıyla).
  List<SavedGame> get games => [
        for (final e in _profiles.entries) SavedGame(e.key, _names[e.key] ?? e.key),
      ];

  /// Oyun Modu için bir oyun seçili mi?
  bool get hasGame => _selected != null && _profiles.containsKey(_selected);

  String? get selectedPackage => _selected;

  /// Seçili oyunun görünen adı.
  String get selectedName => _names[_selected] ?? _selected ?? '';

  /// Açık oturum seçili oyuna mı ait?
  bool get activeForSelected => _session != null && _session!.package == config.package;

  /// Son oturum ölçümüne göre bir sonraki oturum için ayar önerisi (yalnızca
  /// son oturum seçili oyunun oturumuysa).
  ScaleSuggestion? get suggestion =>
      _lastPackage == config.package ? suggestSettings(_stats, config) : null;

  /// Oyun modu şu an açık mı (geri alınacak bir şey var mı)?
  bool get active => _session != null;
  GameSession? get session => _session;
  bool get busy => _busy;

  /// Okunabildiyse etkin ekran yenileme hızı.
  double? get displayHz => _displayHz;

  /// `null` = henüz denetlenmedi.
  bool? get installed => _installed;
  GameRunResult? get lastResult => _lastResult;

  /// Cihazdaki izleyici (otomatik geri alma + ölçüm) çalışıyor mu?
  /// `null` = henüz denetlenmedi.
  bool? get watchdogAlive => _watchdogAlive;

  /// İzleyicinin kaydettiği son oturumun özeti (yoksa `null`).
  SessionStats? get stats => _stats;

  /// Son oturumun olası darboğaz teşhisi.
  Diagnosis? get diagnosis {
    final s = _stats;
    return s == null ? null : diagnose(s, _lastTargetFps ?? config.targetFps);
  }

  /// `dumpsys window` ile okunabilen ön plan paketi; `null` = okunamadı
  /// (ön plan algılama bu cihazda çalışmıyor demektir).
  String? get foregroundPackage => _foreground;

  /// İzleyicinin kendiliğinden yaptığı bir işlemin kullanıcıya notu.
  String? get syncNote => _syncNote;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    try {
      _session = GameSession.decode(await _store.readString(_sessionKey, fallback: ''));
      _loadProfiles(await _store.readString(_profilesKey, fallback: ''));
      if (_profiles.isEmpty) {
        // Eski sürümde tek bir oyun ayarı vardı; varsa onu ilk oyun yap.
        final legacy = await _store.readString(_configKey, fallback: '');
        if (legacy.isNotEmpty) {
          final cfg = GameModeConfig.decode(legacy);
          _profiles[cfg.package] = cfg;
          _names[cfg.package] = cfg.package;
          _selected = cfg.package;
        }
      }
      final last = (await _store.readString(_lastRunKey, fallback: '')).split(':');
      if (last.length == 2) {
        _lastPackage = isSafePackage(last[0]) ? last[0] : null;
        _lastTargetFps = int.tryParse(last[1]);
      }
    } catch (_) {
      // Okunamazsa varsayılanlarla devam.
    }
    notifyListeners();
  }

  void _loadProfiles(String raw) {
    if (raw.isEmpty) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      for (final item in (json['games'] as List? ?? const [])) {
        final m = item as Map<String, dynamic>;
        final cfg = GameModeConfig.fromJson((m['config'] as Map).cast<String, dynamic>());
        _profiles[cfg.package] = cfg;
        _names[cfg.package] = (m['name'] as String?)?.trim().isNotEmpty == true
            ? m['name'] as String
            : cfg.package;
      }
      final sel = json['selected'] as String?;
      _selected = (sel != null && _profiles.containsKey(sel))
          ? sel
          : (_profiles.isEmpty ? null : _profiles.keys.first);
    } catch (_) {
      _profiles.clear();
      _names.clear();
      _selected = null;
    }
  }

  Future<void> _persistProfiles() async {
    final json = {
      'selected': _selected,
      'games': [
        for (final e in _profiles.entries)
          {'name': _names[e.key] ?? e.key, 'config': e.value.toJson()},
      ],
    };
    try {
      await _store.writeString(_profilesKey, jsonEncode(json));
    } catch (_) {}
  }

  /// Seçili oyunun ayarını günceller. Hiç oyun yoksa, ayardaki paketle bir oyun
  /// oluşturur.
  Future<void> updateConfig(GameModeConfig next) async {
    if (!isSafePackage(next.package)) return;
    final sel = _selected;
    if (sel == null || !_profiles.containsKey(sel)) {
      _profiles[next.package] = next;
      _names.putIfAbsent(next.package, () => next.package);
      _selected = next.package;
      _installed = null;
    } else if (sel == next.package) {
      _profiles[sel] = next;
    } else {
      _installed = null;
      // Paket adı değiştiyse kaydı yeni pakete taşı (sıra korunur).
      final entries = _profiles.entries.toList();
      _profiles.clear();
      for (final e in entries) {
        if (e.key == sel) {
          _profiles[next.package] = next;
        } else {
          _profiles[e.key] = e.value;
        }
      }
      _names[next.package] = _names.remove(sel) ?? next.package;
      _selected = next.package;
    }
    notifyListeners();
    await _persistProfiles();
  }

  /// Hazır ayarı seçili oyuna uygular.
  Future<void> applyPreset(GamePreset preset) => updateConfig(preset.applyTo(config));

  /// Oyun ekler (varsa yalnızca seçer). Yeni oyun, "Serin" hazır ayarıyla başlar.
  Future<bool> addGame(String package, String name) async {
    if (!isSafePackage(package)) return false;
    if (!_profiles.containsKey(package)) {
      final cool = kGamePresets.firstWhere((p) => p.id == 'cool');
      _profiles[package] = cool.applyTo(GameModeConfig(package: package));
      _names[package] = name.trim().isEmpty ? package : name.trim();
    }
    _selected = package;
    _installed = null;
    notifyListeners();
    await _persistProfiles();
    checkInstalled();
    return true;
  }

  Future<void> selectGame(String package) async {
    if (!_profiles.containsKey(package) || _selected == package) return;
    _selected = package;
    _installed = null;
    notifyListeners();
    await _persistProfiles();
    checkInstalled();
  }

  /// Oyunu listeden çıkarır (ayarları silinir; açık oturum varsa dokunulmaz).
  Future<void> removeGame(String package) async {
    if (!_profiles.containsKey(package)) return;
    _profiles.remove(package);
    _names.remove(package);
    if (_selected == package) {
      _selected = _profiles.isEmpty ? null : _profiles.keys.first;
    }
    _installed = null;
    notifyListeners();
    await _persistProfiles();
  }

  /// Önerilen çözünürlüğü (ve varsa kare hızını) seçili oyuna uygular.
  Future<void> applySuggestion() async {
    final sug = suggestion;
    if (sug == null) return;
    await updateConfig(config.copyWith(scale: sug.scale, targetFps: sug.fps));
  }

  /// Tek dokunuş: seçili oyunun ayarlarını uygular ve oyunu açar.
  Future<GameRunResult> startSelected({bool launch = true}) => start(launch: launch);

  Future<String> _read(String command) async {
    try {
      final r = await control.exec(command);
      return r.output;
    } catch (_) {
      return '';
    }
  }

  /// Oyun bu cihazda kurulu mu? (`pm path`)
  Future<void> checkInstalled() async {
    if (!control.ready || !isSafePackage(config.package)) return;
    final out = await _read('pm path ${config.package}');
    _installed = out.contains('package:');
    notifyListeners();
  }

  /// Etkin ekran yenileme hızını okur (okunamazsa `null`).
  Future<void> refreshDisplayHz() async {
    if (!control.ready) return;
    final out = await _read('dumpsys display | grep -m3 mActiveMode');
    _displayHz = parseActiveRefreshRate(out);
    notifyListeners();
  }

  /// Ön plandaki uygulamayı okur (izleyicinin oyunu algılayabildiğini gösterir).
  Future<void> detectForeground() async {
    if (!control.ready) return;
    final out = await _read('dumpsys window | grep -m1 mCurrentFocus');
    _foreground = parseFocusedPackage(out);
    notifyListeners();
  }

  /// İzleyicinin durumunu okur. İzleyici oyun kapanınca ayarları kendisi geri
  /// aldıysa (işaret dosyası `ok`), kayıtlı oturum silinir; geri alma
  /// başarısız olduysa oturum SAKLANIR ve kullanıcıya söylenir.
  Future<void> syncWatchdog() async {
    if (!control.ready) return;
    final status = parseWatchdogStatus(await _read(buildWatchdogStatus()));
    _watchdogAlive = status.alive;
    if (!status.alive && _session != null) {
      if (status.revertedOk) {
        _session = null;
        await _persistSession(null);
        await _read(kWatchdogClearMark);
        _syncNote = 'Oyun kapandığı için ayarlar otomatik geri alındı.';
      } else if (status.revertFailed) {
        _syncNote = 'Otomatik geri alma tamamlanamadı; "Geri Al"a basın.';
      }
    }
    notifyListeners();
  }

  /// İzleyicinin kaydettiği oturum günlüğünü okuyup özetler.
  Future<void> refreshStats() async {
    if (!control.ready) return;
    _stats = parseWatchLog(await _read(kWatchdogReadLog));
    notifyListeners();
  }

  Future<void> _persistSession(GameSession? s) async {
    try {
      await _store.writeString(_sessionKey, s?.encode() ?? '');
    } catch (_) {}
  }

  Future<List<GameStepResult>> _run(List<GameStep> steps) async {
    final results = <GameStepResult>[];
    for (final step in steps) {
      final o = await control.shell(step.label, step.command);
      results.add(GameStepResult(
        label: step.label,
        ok: o.ok,
        optional: step.optional,
        detail: o.message,
      ));
    }
    return results;
  }

  /// Oyun modunu açar; [launch] ise oyunu da başlatır. Önce (varsa) önceki
  /// oturumu geri alır, böylece eski değerler HER ZAMAN gerçek orijinaldir.
  Future<GameRunResult> start({
    bool launch = true,
    GameModeConfig? overrideConfig,
  }) async {
    if (!control.ready) {
      return const GameRunResult([], note: 'Önce tam kontrolü etkinleştirin.');
    }
    if (_busy) return const GameRunResult([], note: 'Başka bir işlem sürüyor.');
    final cfg = overrideConfig ?? config;
    if (!isSafePackage(cfg.package)) {
      return const GameRunResult([], note: 'Geçersiz paket adı.');
    }
    _busy = true;
    notifyListeners();
    try {
      // Eski izleyici ve eski işaret, yeni oturumu yanlışlıkla kapatmasın.
      await _read(buildWatchdogKill());
      await _read(kWatchdogClearMark);
      _syncNote = null;

      if (_session != null) {
        final undo = await _revert();
        if (!undo.ok) {
          return GameRunResult(undo.steps,
              note: 'Önceki oyun modu geri alınamadı; yeniden deneyin.');
        }
      }

      // 1) Eski değerleri oku ve DİSKE yaz (değişiklikten önce).
      final snap = await _snapshot(cfg);
      _session = snap.session;
      await _persistSession(_session);
      _lastPackage = cfg.package;
      _lastTargetFps = cfg.targetFps;
      try {
        await _store.writeString(_lastRunKey, '${cfg.package}:${cfg.targetFps}');
      } catch (_) {}

      // 2) Uygula.
      final steps = buildApplySteps(
        cfg,
        physicalSize: snap.physicalSize,
        physicalDensity: snap.physicalDensity,
        brightness: snap.brightness,
        cpuPolicies: snap.cpuPolicies,
      );
      final results = await _run(steps);
      final extra = <GameStepResult>[];
      if (cfg.method == ResolutionMethod.wholeScreen &&
          cfg.reducesResolution &&
          snap.physicalSize == null) {
        extra.add(const GameStepResult(
          label: 'Ekran çözünürlüğü',
          ok: false,
          optional: false,
          detail: 'Ekran boyutu okunamadı, atlandı.',
        ));
      }
      if (cfg.cpuCap && control.path != AccessPath.root) {
        extra.add(const GameStepResult(
          label: 'İşlemci hızını sınırla',
          ok: false,
          optional: true,
          detail: 'Bu adım root gerektirir; Shizuku ile yapılamaz.',
        ));
      } else if (cfg.cpuCap && snap.cpuPolicies.isEmpty) {
        extra.add(const GameStepResult(
          label: 'İşlemci hızını sınırla',
          ok: false,
          optional: true,
          detail: 'İşlemci frekans bilgisi okunamadı.',
        ));
      }
      if (cfg.dimScreen && snap.brightness == null) {
        extra.add(const GameStepResult(
          label: 'Ekran parlaklığını kıs',
          ok: false,
          optional: true,
          detail: 'Mevcut parlaklık okunamadı.',
        ));
      }
      if (cfg.autoRevert) {
        results.add(await _startWatchdog(snap.session, cfg));
      }
      _lastResult = GameRunResult([...results, ...extra]);

      await refreshDisplayHz();

      // 3) Oyunu aç (çözünürlük değiştiyse ekranın oturmasını bekle).
      if (launch) {
        await _delay(const Duration(milliseconds: 900));
        await _launcher(cfg.package);
      }
      return _lastResult!;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// İzleyiciyi başlatır ve gerçekten çalıştığını doğrular; çalışmıyorsa
  /// adım BAŞARISIZ görünür (başarı uydurulmaz).
  Future<GameStepResult> _startWatchdog(GameSession session, GameModeConfig cfg) async {
    const label = 'Oyun kapanınca otomatik geri al';
    final script = buildWatchdogScript(session, guardTempC: cfg.guardTempC);
    if (script.isEmpty) {
      return const GameStepResult(
        label: label,
        ok: false,
        optional: true,
        detail: 'Geçersiz paket adı.',
      );
    }
    final o = await control.shell(label, buildWatchdogLaunch(script));
    await _delay(const Duration(milliseconds: 600));
    await syncWatchdog();
    if (!o.ok) {
      return GameStepResult(label: label, ok: false, optional: true, detail: o.message);
    }
    if (_watchdogAlive != true) {
      return const GameStepResult(
        label: label,
        ok: false,
        optional: true,
        detail: 'İzleyici başlatılamadı; oyun bitince Geri Al\'a kendiniz basın.',
      );
    }
    return const GameStepResult(label: label, ok: true, optional: true);
  }

  /// Her şeyi eski haline getirir.
  Future<GameRunResult> stop() async {
    if (!control.ready) {
      return const GameRunResult([], note: 'Önce tam kontrolü etkinleştirin.');
    }
    if (_busy) return const GameRunResult([], note: 'Başka bir işlem sürüyor.');
    if (_session == null) return const GameRunResult([], note: 'Geri alınacak bir şey yok.');
    _busy = true;
    notifyListeners();
    try {
      final r = await _revert();
      _lastResult = r;
      await refreshDisplayHz();
      return r;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<GameRunResult> _revert() async {
    final session = _session;
    if (session == null) return const GameRunResult([]);
    // İzleyici, geri alma sırasında araya girmesin.
    await _read(buildWatchdogKill());
    _watchdogAlive = false;
    final results = await _run(buildRevertSteps(session));
    final result = GameRunResult(results);
    // Yalnızca zorunlu adımlar başarılıysa oturumu kapat; aksi halde "Geri Al"
    // tekrar denenebilsin diye anlık görüntü saklanır.
    if (result.requiredFailed.isEmpty) {
      _session = null;
      await _persistSession(null);
      await _read(kWatchdogClearMark);
    }
    return result;
  }

  Future<
      ({
        GameSession session,
        PixelSize? physicalSize,
        int? physicalDensity,
        int? brightness,
        List<CpuPolicy> cpuPolicies,
      })> _snapshot(
    GameModeConfig cfg,
  ) async {
    final settings = <String, String?>{};
    final keys = <SettingKey>[
      ...kRefreshKeys,
      if (cfg.animationsOff) ...kAnimationKeys,
      if (cfg.dnd) kZenKey,
      if (cfg.batterySaver) kLowPowerKey,
      if (cfg.dimScreen) ...kBrightnessKeys,
    ];
    for (final key in keys) {
      settings[key.id] = normalizeSettingValue(await _read(key.readCommand));
    }

    int? brightness;
    if (cfg.dimScreen) {
      brightness = int.tryParse(settings['system:screen_brightness'] ?? '');
    }

    var cpuPolicies = <CpuPolicy>[];
    final cpuMax = <String, String>{};
    if (cfg.cpuCap && control.path == AccessPath.root) {
      cpuPolicies = parseCpuPolicies(await _read(kCpuPolicyReadCommand));
      for (final p in topPolicies(cpuPolicies)) {
        cpuMax[p.name] = '${p.curMax}';
      }
    }

    PixelSize? physical;
    int? density;
    String? sizeOverride;
    String? densityOverride;
    var changedScreen = false;
    if (cfg.method == ResolutionMethod.wholeScreen && cfg.reducesResolution) {
      final ws = parseWmSize(await _read('wm size'));
      final wd = parseWmDensity(await _read('wm density'));
      if (ws != null && wd != null) {
        physical = ws.physical;
        density = wd.physical;
        sizeOverride = ws.override?.toString();
        densityOverride = wd.override?.toString();
        changedScreen = true;
      }
    }

    return (
      session: GameSession(
        package: cfg.package,
        settings: settings,
        touchedGameManager: true,
        sizeOverride: sizeOverride,
        densityOverride: densityOverride,
        changedScreen: changedScreen,
        cpuMax: cpuMax,
        startedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
      physicalSize: physical,
      physicalDensity: density,
      brightness: brightness,
      cpuPolicies: cpuPolicies,
    );
  }
}
