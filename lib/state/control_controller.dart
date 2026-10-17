import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/profile.dart';
import '../models/tweak_model.dart';
import '../services/catalog_service.dart';
import '../services/notification_service.dart';
import '../services/root_service.dart';
import '../services/shizuku_service.dart';
import '../utils/haptics.dart';
import '../utils/shell_utils.dart';
import '../utils/tweak_status.dart';

/// Komutların hangi yetki yolundan çalıştığı.
enum AccessPath { none, root, shizuku }

enum ControlPhase { checking, ready, needsSetup }

/// Yetkili komut çalıştırılamadığında (yol yok / servis yanıt vermiyor).
class ControlUnavailableException implements Exception {
  const ControlUnavailableException(this.message);
  final String message;
  @override
  String toString() => message;
}

class TweakOutcome {
  const TweakOutcome(this.ok, this.message);
  final bool ok;
  final String message;
}

class ProfileResult {
  const ProfileResult({required this.applied, required this.skipped, required this.failed});
  final int applied;
  final int skipped;
  final int failed;

  String get summary {
    final parts = <String>[];
    if (applied > 0) parts.add('$applied uygulandı');
    if (skipped > 0) parts.add('$skipped zaten hazırdı');
    if (failed > 0) parts.add('$failed başarısız');
    return parts.isEmpty ? 'Yapılacak bir şey yok' : parts.join(' · ');
  }
}

final RegExp _packagePattern = RegExp(r'^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+$');

/// Paket adı güvenli mi? Kabuk komutuna yerleştirilmeden önce MUTLAKA
/// doğrulanır (komut enjeksiyonunu önler).
bool isValidPackageName(String value) => _packagePattern.hasMatch(value);

/// "Karmaşık kısmı kendisi halleden" yönetim katmanı.
///
/// - Kök varsa kökü, yoksa Shizuku'yu OTOMATİK seçer; kullanıcı yol seçmez.
/// - Hazır olup olmadığını gerçek bir `id` komutuyla kanıtlar.
/// - Başarısız komut asla "tamamlandı" görünmez.
/// - Tweak'lerin AÇIK/KAPALI durumunu cihazdan okur.
class ControlController extends ChangeNotifier {
  ControlController({RootService? root, ShizukuService? shizuku, CatalogService? catalog})
      : _root = root ?? RootService(),
        _shizuku = shizuku ?? ShizukuService(),
        _catalog = catalog ?? CatalogService();

  final RootService _root;
  final ShizukuService _shizuku;
  final CatalogService _catalog;

  /// Bildirim gönderen katman ve "işlem sonucu bildirimi açık mı?" sorusu
  /// (uygulama tarafından bağlanır; testlerde boş bırakılabilir).
  Notifier? notifier;
  bool Function() taskNotificationsEnabled = () => true;

  /// Bir işlem bitince çağrılır: dokunsal geri bildirim verir ve (açıksa,
  /// uygulama arka plandayken) sonuç bildirimi gönderir.
  void reportDone(String title, String body, {bool ok = true}) {
    if (ok) {
      Haptics.success();
    } else {
      Haptics.warning();
    }
    final n = notifier;
    if (n != null && taskNotificationsEnabled()) {
      unawaited(n.showTask(title: title, body: body));
    }
  }

  ControlPhase _phase = ControlPhase.checking;
  AccessPath _path = AccessPath.none;
  String _identity = '';
  String? _error;
  bool _shizukuRunning = false;
  bool _shizukuPermitted = false;
  bool _settingUp = false;

  List<Tweak> _tweaks = const [];
  final Map<String, TweakStatus> _statuses = {};
  final Set<String> _working = {};
  String? _busyLabel;
  final List<String> _log = [];
  bool _disposed = false;

  ControlPhase get phase => _phase;
  AccessPath get path => _path;
  bool get ready => _phase == ControlPhase.ready;
  bool get checking => _phase == ControlPhase.checking;
  bool get settingUp => _settingUp;
  String get identity => _identity;
  String? get error => _error;
  bool get shizukuRunning => _shizukuRunning;
  bool get shizukuPermitted => _shizukuPermitted;
  List<Tweak> get tweaks => _tweaks;
  String? get busyLabel => _busyLabel;
  bool get busy => _busyLabel != null;
  List<String> get log => List.unmodifiable(_log);

  bool isWorking(String tweakId) => _working.contains(tweakId);
  TweakState stateOf(String tweakId) => _statuses[tweakId]?.state ?? TweakState.unknown;

  /// Kullanıcıya gösterilen tek satırlık durum.
  String get headline {
    switch (_phase) {
      case ControlPhase.checking:
        return 'Denetleniyor…';
      case ControlPhase.ready:
        return _path == AccessPath.root ? 'Tam kontrol · root' : 'Tam kontrol · $_identity';
      case ControlPhase.needsSetup:
        return 'Tam kontrol kapalı';
    }
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Tweak? tweakById(String id) {
    for (final t in _tweaks) {
      if (t.id == id) return t;
    }
    return null;
  }

  void _addLog(String line) {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    _log.add('${two(now.hour)}:${two(now.minute)}:${two(now.second)}  $line');
    while (_log.length > 200) {
      _log.removeAt(0);
    }
  }

  void clearLog() {
    _log.clear();
    notifyListeners();
  }

  Future<void> init() async {
    try {
      _tweaks = await _catalog.loadTweaks();
    } catch (e) {
      _tweaks = const [];
      _addLog('✗ Tweak listesi okunamadı: $e');
    }
    notifyListeners();
    await detect();
  }

  /// Yetki yolunu yeniden bulur: önce kök, sonra Shizuku.
  Future<void> detect() async {
    _phase = ControlPhase.checking;
    _error = null;
    notifyListeners();

    if (await _root.hasRoot(forceRecheck: true)) {
      _path = AccessPath.root;
      _identity = _root.identity?.label ?? 'root';
      _phase = ControlPhase.ready;
      _addLog('✓ Kök erişimi bulundu.');
      notifyListeners();
      unawaited(refreshStatuses());
      return;
    }

    final probe = await _shizuku.probe();
    _shizukuRunning = probe.running;
    _shizukuPermitted = probe.permitted;
    if (probe.ready) {
      _path = AccessPath.shizuku;
      _identity = probe.identity?.label ?? 'shell';
      _phase = ControlPhase.ready;
      _addLog('✓ Shizuku hazır ($_identity).');
      notifyListeners();
      unawaited(refreshStatuses());
    } else {
      _path = AccessPath.none;
      _identity = '';
      _phase = ControlPhase.needsSetup;
      _error = probe.error;
      notifyListeners();
    }
  }

  /// "Tam kontrolü etkinleştir" düğmesi: o an yapılabilecek bir SONRAKİ
  /// adımı kendisi yapar (izin ister) ve ardından yeniden denetler.
  Future<void> setUp() async {
    if (_settingUp) return;
    _settingUp = true;
    notifyListeners();
    try {
      await detect();
      if (!ready && _shizukuRunning && !_shizukuPermitted) {
        final granted = await _shizuku.requestPermission();
        _addLog(granted ? '✓ Shizuku izni verildi.' : '✗ Shizuku izni verilmedi.');
        await detect();
      }
    } finally {
      _settingUp = false;
      notifyListeners();
    }
  }

  Future<ShellResult> exec(String command) async {
    switch (_path) {
      case AccessPath.root:
        return _root.exec(command);
      case AccessPath.shizuku:
        return _shizuku.exec(command);
      case AccessPath.none:
        throw const ControlUnavailableException('Tam kontrol etkin değil.');
    }
  }

  Future<void> refreshStatuses() async {
    if (!ready) return;
    for (final tweak in _tweaks) {
      if (!tweak.hasCheck) continue;
      await _readStatus(tweak);
      if (!ready) return;
    }
    notifyListeners();
  }

  Future<void> _readStatus(Tweak tweak) async {
    try {
      final result = await exec(tweak.checkCommand!);
      _statuses[tweak.id] = TweakStatus(
        stateFromCheckResult(expected: tweak.expectedOutput!, result: result),
      );
    } catch (_) {
      _statuses[tweak.id] = const TweakStatus(TweakState.unknown);
    }
  }

  /// Tek bir komutu çalıştırır; sonucu günlüğe yazar ve sade bir sonuç döner.
  Future<TweakOutcome> shell(String label, String command) async {
    if (!ready) return const TweakOutcome(false, 'Tam kontrol etkin değil.');
    try {
      final result = await exec(command);
      final reason = failureReason(result);
      for (final line in outputLines(result.output).take(6)) {
        _addLog('  $line');
      }
      if (reason != null) {
        _addLog('✗ $label: $reason');
        return TweakOutcome(false, '$label başarısız: $reason');
      }
      _addLog('✓ $label');
      return TweakOutcome(true, '$label tamamlandı');
    } on ShizukuUnavailableException catch (e) {
      _addLog('✗ $label: ${e.reason}');
      return TweakOutcome(false, e.reason);
    } on ControlUnavailableException catch (e) {
      return TweakOutcome(false, e.message);
    } catch (e) {
      _addLog('✗ $label: $e');
      return TweakOutcome(false, '$label çalıştırılamadı.');
    }
  }

  Future<TweakOutcome> _runTweak(Tweak tweak, {required bool apply}) async {
    final command = apply ? tweak.applyCommand : tweak.revertCommand;
    if (command == null || command.isEmpty) {
      return const TweakOutcome(false, 'Bu işlem geri alınamaz.');
    }
    _addLog('› ${tweak.title} ${apply ? '' : '(geri al)'}');
    final outcome = await shell(tweak.title, command);
    if (outcome.ok && tweak.hasCheck) {
      await _readStatus(tweak);
      // Komut "başarılı" döndü ama değer değişmediyse bunu gizleme.
      final wanted = apply ? TweakState.on : TweakState.off;
      final actual = stateOf(tweak.id);
      if (actual != TweakState.unknown && actual != wanted) {
        const msg = 'Komut çalıştı ama cihaz ayarı değişmedi (üretici kısıtlıyor olabilir).';
        _addLog('✗ ${tweak.title}: $msg');
        return const TweakOutcome(false, msg);
      }
    }
    return outcome;
  }

  /// Tek bir tweak'i açar/kapatır (ya da tek seferlik eylemi çalıştırır).
  Future<TweakOutcome> setTweak(Tweak tweak, {required bool apply}) async {
    if (!ready) return const TweakOutcome(false, 'Önce tam kontrolü etkinleştirin.');
    _working.add(tweak.id);
    notifyListeners();
    try {
      return await _runTweak(tweak, apply: apply);
    } finally {
      _working.remove(tweak.id);
      notifyListeners();
    }
  }

  /// Bir profilin tüm ayarlarını sırayla uygular ya da geri alır.
  Future<ProfileResult> runProfile(OptimizationProfile profile, {required bool apply}) async {
    if (!ready || busy) return const ProfileResult(applied: 0, skipped: 0, failed: 0);
    _busyLabel = '${profile.title} ${apply ? 'uygulanıyor' : 'geri alınıyor'}…';
    notifyListeners();
    var applied = 0, skipped = 0, failed = 0;
    try {
      for (final id in profile.tweakIds) {
        final tweak = tweakById(id);
        if (tweak == null) continue;
        if (!apply && !tweak.isToggle) continue;
        final state = stateOf(id);
        if (tweak.isToggle) {
          if (apply && state == TweakState.on) {
            skipped++;
            continue;
          }
          if (!apply && state == TweakState.off) {
            skipped++;
            continue;
          }
        }
        _working.add(id);
        notifyListeners();
        final outcome = await _runTweak(tweak, apply: apply);
        _working.remove(id);
        if (outcome.ok) {
          applied++;
        } else {
          failed++;
        }
        notifyListeners();
      }
    } finally {
      _busyLabel = null;
      _working.clear();
      notifyListeners();
    }
    return ProfileResult(applied: applied, skipped: skipped, failed: failed);
  }

  /// Bir profilde kaç ayar şu an AÇIK (rozet için).
  int activeCount(OptimizationProfile profile) {
    var n = 0;
    for (final id in profile.tweakIds) {
      final t = tweakById(id);
      if (t != null && t.isToggle && stateOf(id) == TweakState.on) n++;
    }
    return n;
  }

  int toggleCount(OptimizationProfile profile) {
    var n = 0;
    for (final id in profile.tweakIds) {
      final t = tweakById(id);
      if (t != null && t.isToggle) n++;
    }
    return n;
  }

  // ---- Hızlı eylemler (Ana Sayfa) ------------------------------------

  /// RAM'i boşaltır: arka plan uygulamalarını sonlandırır.
  Future<TweakOutcome> freeMemory() => shell('Bellek temizliği', 'am kill-all');

  /// Tüm uygulamaların önbelleğini temizler.
  Future<TweakOutcome> trimAllCaches() =>
      shell('Önbellek temizliği', 'pm trim-caches 999999999999');

  // ---- Uygulama eylemleri (Uygulamalar sayfası) -----------------------

  Future<TweakOutcome> forceStop(String package) => _pkg('Durdur', package, (p) => 'am force-stop $p');
  Future<TweakOutcome> clearAppCache(String package) =>
      _pkg('Önbellek temizle', package, (p) => 'pm clear --cache-only $p');
  Future<TweakOutcome> freeze(String package) =>
      _pkg('Dondur', package, (p) => 'pm disable-user --user 0 $p');
  Future<TweakOutcome> unfreeze(String package) =>
      _pkg('Etkinleştir', package, (p) => 'pm enable $p');
  Future<TweakOutcome> uninstallForUser(String package) =>
      _pkg('Kaldır', package, (p) => 'pm uninstall --user 0 $p');

  Future<TweakOutcome> _pkg(String label, String package, String Function(String) build) {
    if (!isValidPackageName(package)) {
      return Future.value(const TweakOutcome(false, 'Geçersiz paket adı.'));
    }
    return shell('$label: $package', build(package));
  }
}
