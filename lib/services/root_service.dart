import 'dart:async';
import 'dart:io';

import '../utils/shell_utils.dart';

/// Kök (root) yetkisiyle komut çalıştırma. Cihaz köklü değilse sessizce
/// "kök yok" der; hiçbir şey uydurmaz.
class RootService {
  bool? _cache;
  ShellIdentity? _identity;

  ShellIdentity? get identity => _identity;

  /// `su -c id` ile kök erişimini dener; sonuç önbelleğe alınır.
  Future<bool> hasRoot({bool forceRecheck = false}) async {
    if (_cache != null && !forceRecheck) return _cache!;
    try {
      final result = await Process.run('su', ['-c', 'id']).timeout(const Duration(seconds: 8));
      final out = '${result.stdout}';
      _cache = result.exitCode == 0 && out.contains('uid=0');
      _identity = _cache == true ? parseIdOutput(out) : null;
    } catch (_) {
      // `su` yok (cihaz köklü değil) ya da izin isteği zaman aşımına uğradı.
      _cache = false;
      _identity = null;
    }
    return _cache!;
  }

  /// [command]'ı `su -c` altında çalıştırır. Çıkış kodu sıfırdan farklıysa
  /// stderr da çıktıya eklenir ki hata nedeni görülebilsin.
  Future<ShellResult> exec(String command) async {
    final result = await Process.run('su', ['-c', command]).timeout(const Duration(seconds: 30));
    var output = '${result.stdout}'.trim();
    final err = '${result.stderr}'.trim();
    if (result.exitCode != 0 && err.isNotEmpty) {
      output = '$output\n$err'.trim();
    }
    return ShellResult(output: output, exitCode: result.exitCode);
  }
}
