/// Kabuk (shell) komutu çalıştırmayla ilgili saf (platform bağımsız)
/// yardımcılar - `RootService` (root) ve `ShizukuService` (Shizuku)
/// tarafından ortak kullanılır. Platform kanalı içermediği için birim
/// testleri gerçek cihaz gerektirmez (bkz. `test/shell_utils_test.dart`).
library;

/// Bir kabuk komutunun sonucu.
///
/// [exitCode] `null` ise çıkış kodu ELDE EDİLEMEMİŞTİR: `shizuku_api`
/// paketinin `runCommand` metodu yalnızca çıktı metnini (`String?`)
/// döndürür, çıkış kodunu vermez. Bu durumda başarı, [failureReason]
/// içinde çıktı metnine bakılarak tahmin edilir - kesin değildir.
class ShellResult {
  const ShellResult({required this.output, this.exitCode});

  final String output;
  final int? exitCode;

  bool get exitCodeKnown => exitCode != null;

  /// Çıkış kodu biliniyor VE sıfırdan farklı.
  bool get failedByExitCode => exitCode != null && exitCode != 0;
}

/// Bir tweak komutu çalıştı ama başarısız sayıldığında fırlatılır
/// (sıfırdan farklı çıkış kodu ya da çıktıda hata izi). Böylece arayüz
/// başarısız komutu "tamamlandı" diye göstermez.
class TweakCommandFailedException implements Exception {
  const TweakCommandFailedException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// `id` komutunun çıktısından okunan çalışma kimliği.
class ShellIdentity {
  const ShellIdentity({required this.uid, required this.name, required this.raw});

  final int uid;
  final String name;

  /// `id`'nin ham (kırpılmış) çıktısı.
  final String raw;

  bool get isRoot => uid == 0;

  /// Kullanıcıya gösterilen kısa ad: `root`, `shell` vb.
  String get label => isRoot ? 'root' : name;
}

/// `uid=2000(shell) gid=2000(shell) ...` biçimindeki `id` çıktısını
/// ayrıştırır; `uid=` bulunamazsa `null` döner.
ShellIdentity? parseIdOutput(String output) {
  final match = RegExp(r'uid=(\d+)(?:\(([^)]*)\))?').firstMatch(output);
  if (match == null) return null;
  final uid = int.parse(match.group(1)!);
  final name = match.group(2) ?? (uid == 0 ? 'root' : 'uid $uid');
  return ShellIdentity(uid: uid, name: name, raw: output.trim());
}

/// Bir değeri tek tırnak içine güvenle alır: `it's` -> `'it'\''s'`.
String shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";

/// [wrapForShell]'in çıktıya eklediği çıkış kodu satırının öneki.
const String exitMarker = '__TF_EXIT__';

/// Komutu `sh -c` ile sarar: alt kabukta çalıştırır (böylece `;` ile
/// zincirlenmiş komutların hepsi çalışır), stderr'i stdout'a katar ve son
/// satıra çıkış kodunu `__TF_EXIT__:<kod>` olarak yazar. Sonucu
/// [parseWrappedOutput] ile çözün.
///
/// Çıkış kodu alt kabuğun SON komutunun kodudur; zincirin ortasındaki bir
/// komutun hatası bu koda yansımaz - o yüzden [failureReason] çıktıya da
/// bakar.
String wrapForShell(String command) {
  final script = '( $command ) 2>&1; echo "$exitMarker:\$?"';
  return 'sh -c ${shellQuote(script)}';
}

/// [wrapForShell] ile sarılmış bir komutun ham çıktısından çıkış kodu
/// satırını ayıklar. Satır yoksa (`exitCode == null`) çıkış kodu
/// doğrulanamamıştır.
ShellResult parseWrappedOutput(String raw) {
  final marker = RegExp('^$exitMarker:(-?\\d+)\$');
  int? code;
  final kept = <String>[];
  for (final line in raw.replaceAll('\r', '').split('\n')) {
    final match = marker.firstMatch(line.trim());
    if (match != null) {
      code = int.tryParse(match.group(1)!);
    } else {
      kept.add(line);
    }
  }
  return ShellResult(output: kept.join('\n').trim(), exitCode: code);
}

/// `a; b; c` biçimindeki zinciri tek tek komutlara böler. YALNIZCA
/// `sh -c` sarmalayıcısının çalışmadığı durumda (bkz. `ShizukuService`)
/// yedek olarak kullanılır. Tırnak içindeki `;` karakterlerini AYIRT ETMEZ;
/// paketle gelen `tweaks.json` komutlarında böyle bir kullanım yoktur.
List<String> splitCommandChain(String command) {
  return command
      .split(';')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

/// Boş olmayan, kırpılmış çıktı satırları.
List<String> outputLines(String output) {
  return output
      .replaceAll('\r', '')
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();
}

final RegExp _failurePattern = RegExp(
  r'(exception|permission denial|permission denied|unknown package|'
  r'not found|no such file|failure|unknown command|not allowed|'
  r'inaccessible|\berror\b)',
  caseSensitive: false,
);

/// Çıktı, tipik Android kabuk hata izlerini (`Exception`, `Unknown
/// package`, `Permission denied` ...) içeriyor mu? Çıkış kodunun
/// bilinmediği ya da zincirin ortasındaki bir hatanın kodu gizlediği
/// durumlar için sezgisel bir kontroldür - kesin değildir.
bool outputLooksLikeFailure(String output) => _failurePattern.hasMatch(output);

/// Sonuç başarısızsa kullanıcıya gösterilecek açıklama, başarılıysa `null`.
String? failureReason(ShellResult result) {
  if (result.failedByExitCode) {
    return 'komut hata verdi (çıkış kodu ${result.exitCode})';
  }
  if (outputLooksLikeFailure(result.output)) {
    return result.exitCodeKnown
        ? 'çıkış kodu 0 ama çıktı hata içeriyor'
        : 'çıktı hata içeriyor (çıkış kodu alınamadı)';
  }
  return null;
}
