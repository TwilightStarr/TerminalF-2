import 'package:shizuku_api/shizuku_api.dart';

import '../models/tweak_model.dart';
import '../utils/shell_utils.dart';

/// Bir tweak, Shizuku servisi çalışmıyorken, izin verilmemişken ya da test
/// komutu (`id`) başarısız olmuşken çalıştırılmaya çalışıldığında
/// fırlatılır - bkz. sınıf yorumu.
class ShizukuUnavailableException implements Exception {
  const ShizukuUnavailableException(this.reason);
  final String reason;
  @override
  String toString() => reason;
}

/// [ShizukuService.probe] sonucu: servis çalışıyor mu, izin var mı ve test
/// komutu (`id`) hangi kimlikle çalıştı.
class ShizukuProbe {
  const ShizukuProbe({
    required this.running,
    required this.permitted,
    this.identity,
    this.error,
  });

  final bool running;
  final bool permitted;

  /// Test komutunun (`id`) çalıştığı kimlik (`shell` ya da `root`). Yalnızca
  /// test komutu gerçekten başarılı olduysa doludur.
  final ShellIdentity? identity;

  /// Hazır değilse nedeni (kullanıcıya gösterilir).
  final String? error;

  /// Servis çalışıyor, izin verilmiş VE test komutu başarılı.
  bool get ready => running && permitted && identity != null;
}

/// Komutların Shizuku'ya nasıl iletildiği (bkz. [ShizukuService.probe]).
enum _ExecMode {
  /// `sh -c '( komut ) 2>&1; echo __TF_EXIT__:$?'` - zincirlenmiş (`;`)
  /// komutlar çalışır ve çıkış kodu geri okunabilir.
  wrapped,

  /// Sarmalayıcı bu Shizuku/eklenti sürümünde çalışmadı; komut ham olarak
  /// gönderilir. `;` zinciri tek tek bölünüp çalıştırılır ve ÇIKIŞ KODU
  /// YOKTUR (yalnızca çıktı metnine bakılır).
  raw,
}

/// [RootService]'in kök (root) tabanlı yoluna paralel, KÖK GEREKTİRMEYEN
/// ikinci bir çalıştırma yolu: Shizuku (bkz. https://shizuku.rikka.app).
///
/// Kullanıcının cihazında bir kez yaptığı "Kablosuz hata ayıklama"
/// eşleştirmesi üzerinden Shizuku bir arka plan servisi başlatır; bu servis
/// çalıştığı sürece bu uygulama `adb shell` ile aynı yetki seviyesinde
/// komut çalıştırabilir:
/// - Kullanıcı Shizuku'yu normal (rootsuz) başlattıysa komutlar "shell"
///   kullanıcısı (adb ile aynı) kimliğiyle çalışır - `pm`, `settings`,
///   `cmd`, `dumpsys` gibi çoğu debloat/tweak komutu bu seviyede çalışır.
/// - Kullanıcı Shizuku'yu kökle (Sui/Magisk) başlattıysa komutlar root
///   kimliğiyle çalışır.
/// - Gerçekten tam kök isteyen bazı tweak'ler shell kimliğiyle YİNE DE
///   başarısız olabilir; bu servis bunu gizlemez, komutun gerçek
///   çıktısına/çıkış koduna göre [TweakCommandFailedException] fırlatır.
///
/// `shizuku_api` paketinin GERÇEK yüzeyi (pub.dev API belgesi, sürüm 1.2.3)
/// yalnızca dört metottur: `pingBinder()`, `checkPermission()`,
/// `requestPermission()` (hepsi `Future<bool?>`) ve `runCommand(String)`
/// (`Future<String?>`). `runCommand` ÇIKIŞ KODU DÖNDÜRMEZ; bu yüzden çıkış
/// kodu, komutu `sh -c` ile sarıp sonuna `echo $?` ekleyerek elde edilir
/// (bkz. [wrapForShell]). Bu sarmalayıcının paketin komutu nasıl
/// çalıştırdığıyla uyumlu olduğu [probe] içinde gerçek bir `id` komutuyla
/// sınanır; uyumsuzsa ham moda düşülür ve bu, kullanıcıya açıkça söylenir.
///
/// `RootService` ile AYNI İMZAYI taşır ki `ControlController` iki çalıştırma yolunu birbirinin yerine kullanabilsin.
class ShizukuService {
  final _api = ShizukuApi();

  _ExecMode? _mode;
  ShellIdentity? _identity;
  String? _lastRunError;

  /// Son başarılı [probe]'un bulduğu çalışma kimliği (yoksa `null`).
  ShellIdentity? get identity => _identity;

  /// `true` ise çıkış kodu doğrulanamıyor (ham mod) - bkz. [_ExecMode.raw].
  bool get exitCodeAvailable => _mode == _ExecMode.wrapped;

  /// Cihazda Shizuku servisi kurulu ve çalışıyor mu?
  Future<bool> isRunning() async {
    try {
      return await _api.pingBinder() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Uygulamaya daha önce Shizuku izni verilmiş mi?
  Future<bool> hasPermission() async {
    try {
      return await _api.checkPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Kullanıcıya Shizuku izin diyaloğunu gösterir ve sonucu döner.
  Future<bool> requestPermission() async {
    try {
      return await _api.requestPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Shizuku'nun GERÇEKTEN hazır olduğunu doğrular: servis çalışıyor mu,
  /// izin var mı ve `id` test komutu hangi kimlikle (shell/root) çalışıyor.
  /// "Servis çalışıyor + izin var" tek başına yeterli sayılmaz - komutların
  /// gerçekten çalıştığı ancak bu test komutuyla kanıtlanır.
  Future<ShizukuProbe> probe() async {
    _mode = null;
    _identity = null;
    _lastRunError = null;

    if (!await isRunning()) {
      return const ShizukuProbe(
        running: false,
        permitted: false,
        error: 'Shizuku servisi çalışmıyor.',
      );
    }
    if (!await hasPermission()) {
      return const ShizukuProbe(
        running: true,
        permitted: false,
        error: 'Shizuku izni verilmedi.',
      );
    }

    // 1) `sh -c` sarmalayıcısıyla dene: çalışırsa çıkış kodu da gelir.
    final wrappedRaw = await _safeRun(wrapForShell('id'));
    if (wrappedRaw != null) {
      final parsed = parseWrappedOutput(wrappedRaw);
      final identity = parseIdOutput(parsed.output);
      if (identity != null && parsed.exitCode == 0) {
        _mode = _ExecMode.wrapped;
        _identity = identity;
        return ShizukuProbe(running: true, permitted: true, identity: identity);
      }
    }

    // 2) Sarmalayıcı işe yaramadı: ham `id` ile dene.
    final rawOut = await _safeRun('id');
    final rawIdentity = rawOut == null ? null : parseIdOutput(rawOut);
    if (rawIdentity != null) {
      _mode = _ExecMode.raw;
      _identity = rawIdentity;
      return ShizukuProbe(running: true, permitted: true, identity: rawIdentity);
    }

    final seen = (rawOut ?? wrappedRaw ?? '').trim();
    final shortSeen = seen.length > 80 ? '${seen.substring(0, 80)}…' : seen;
    return ShizukuProbe(
      running: true,
      permitted: true,
      error: _lastRunError != null
          ? 'Test komutu (id) çalıştırılamadı: $_lastRunError'
          : 'Test komutu (id) beklenen çıktıyı döndürmedi'
              '${shortSeen.isEmpty ? ' (boş yanıt)' : ' (yanıt: $shortSeen)'}.',
    );
  }

  Future<String?> _safeRun(String command) async {
    try {
      return await _api.runCommand(command);
    } catch (e) {
      _lastRunError = '$e';
      return null;
    }
  }

  Future<void> _ensureReady() async {
    if (_mode != null) return;
    final result = await probe();
    if (!result.ready) {
      throw ShizukuUnavailableException(
        result.error ?? 'Shizuku hazır değil.',
      );
    }
  }

  /// [command]'ı Shizuku üzerinden çalıştırır ve sonucunu döner. Servis
  /// hazır değilse ya da Shizuku yanıt vermezse [ShizukuUnavailableException]
  /// fırlatır. Çıkış kodu yalnızca sarmalayıcı modunda vardır
  /// ([ShellResult.exitCode] aksi halde `null`).
  Future<ShellResult> exec(String command) async {
    await _ensureReady();
    _lastRunError = null;
    if (_mode == _ExecMode.wrapped) {
      final raw = await _safeRun(wrapForShell(command));
      if (raw == null) throw _noResponse();
      return parseWrappedOutput(raw);
    }

    // Ham mod: `;` zincirini tek tek çalıştır, çıktıları birleştir.
    final buffer = StringBuffer();
    for (final part in splitCommandChain(command)) {
      final raw = await _safeRun(part);
      if (raw == null) throw _noResponse();
      if (raw.trim().isNotEmpty) buffer.writeln(raw.trim());
    }
    return ShellResult(output: buffer.toString().trim());
  }

  ShizukuUnavailableException _noResponse() {
    return ShizukuUnavailableException(
      _lastRunError != null
          ? 'Shizuku komutu çalıştıramadı: $_lastRunError'
          : 'Shizuku komuta yanıt vermedi (boş sonuç).',
    );
  }

  /// [tweak]'in komutunu (`apply` ise [Tweak.applyCommand], değilse
  /// [Tweak.revertCommand]) Shizuku üzerinden çalıştırır ve çıktısını satır
  /// satır akıtır. Servis hazır değilse hiçbir şey çalıştırmadan
  /// [ShizukuUnavailableException]; komut başarısız olursa (sıfırdan farklı
  /// çıkış kodu ya da çıktıda hata izi) [TweakCommandFailedException]
  /// fırlatır - başarısız komut ASLA "tamamlandı" diye görünmez.
  Stream<String> runTweak(Tweak tweak, {required bool apply}) async* {
    await _ensureReady();
    final command = apply ? tweak.applyCommand : tweak.revertCommand;
    if (command == null || command.isEmpty) return;

    yield '› Shizuku (${_identity?.label ?? 'shell'}) üzerinden çalıştırılıyor: $command';
    if (!exitCodeAvailable) {
      yield '  ! Bu Shizuku sürümünde çıkış kodu alınamıyor; başarı yalnızca '
          'çıktıya bakılarak tahmin edilecek.';
    }

    final result = await exec(command);
    for (final line in outputLines(result.output)) {
      yield '  $line';
    }

    final reason = failureReason(result);
    if (reason != null) throw TweakCommandFailedException(reason);
    yield result.exitCodeKnown
        ? '› tamamlandı (kod ${result.exitCode})'
        : '› tamamlandı (çıkış kodu doğrulanamadı)';
  }
}
