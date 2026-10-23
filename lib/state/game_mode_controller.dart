import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/apps_service.dart';
import '../services/settings_service.dart';
import '../utils/game_mode.dart';
import '../utils/game_probe.dart';
import '../utils/game_watchdog.dart';
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

/// "Oyun Modu": 9Kings gibi ağır oyunlar için GPU yükünü azaltır, ekranı
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

  final ControlController control;
  final SettingsService _store;
  final Future<void> Function(String package) _launcher;
  final Future<void> Function(Duration) _delay;

  GameModeConfig _config = const GameModeConfig();
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

  GameModeConfig get config => _config;

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
    return s == null ? null : diagnose(s, _config.targetFps);
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
      _config = GameModeConfig.decode(await _store.readString(_configKey, fallback: ''));
      _session = GameSession.decode(await _store.readString(_sessionKey, fallback: ''));
    } catch (_) {
      // Okunamazsa varsayılanlarla devam.
    }
    notifyListeners();
  }

  Future<void> updateConfig(GameModeConfig next) async {
    final packageChanged = next.package != _config.package;
    _config = next;
    if (packageChanged) _installed = null;
    notifyListeners();
    try {
      await _store.writeString(_configKey, next.encode());
    } catch (_) {}
  }

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
    if (!control.ready || !isSafePackage(_config.package)) return;
    final out = await _read('pm path ${_config.package}');
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
  Future<GameRunResult> start({bool launch = true}) async {
    if (!control.ready) {
      return const GameRunResult([], note: 'Önce tam kontrolü etkinleştirin.');
    }
    if (_busy) return const GameRunResult([], note: 'Başka bir işlem sürüyor.');
    final cfg = _config;
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

      // 2) Uygula.
      final steps = buildApplySteps(
        cfg,
        physicalSize: snap.physicalSize,
        physicalDensity: snap.physicalDensity,
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
      if (cfg.autoRevert) {
        results.add(await _startWatchdog(snap.session));
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
  Future<GameStepResult> _startWatchdog(GameSession session) async {
    const label = 'Oyun kapanınca otomatik geri al';
    final script = buildWatchdogScript(session);
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

  Future<({GameSession session, PixelSize? physicalSize, int? physicalDensity})> _snapshot(
    GameModeConfig cfg,
  ) async {
    final settings = <String, String?>{};
    final keys = <SettingKey>[
      ...kRefreshKeys,
      if (cfg.animationsOff) ...kAnimationKeys,
      if (cfg.dnd) kZenKey,
    ];
    for (final key in keys) {
      settings[key.id] = normalizeSettingValue(await _read(key.readCommand));
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
        startedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
      physicalSize: physical,
      physicalDensity: density,
    );
  }
}
