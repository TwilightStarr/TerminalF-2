import 'dart:io';

import '../utils/system_parsers.dart';

/// Cihazın GERÇEK (yalnızca uygulamaya ait değil) bellek, depolama ve çalışma
/// süresi bilgisi. Android'in herkese açık dosyalarından okunur; kök gerekmez.
/// Bir kalem okunamazsa `null` kalır, uydurma değer üretilmez.
class SystemStats {
  const SystemStats({this.memory, this.disk, this.uptime});

  final MemInfo? memory;
  final DiskInfo? disk;
  final Duration? uptime;

  static const SystemStats empty = SystemStats();
}

class SystemStatsService {
  Future<SystemStats> read() async {
    final results = await Future.wait<Object?>([_memory(), _disk(), _uptime()]);
    return SystemStats(
      memory: results[0] as MemInfo?,
      disk: results[1] as DiskInfo?,
      uptime: results[2] as Duration?,
    );
  }

  Future<MemInfo?> _memory() async {
    try {
      return parseMemInfo(await File('/proc/meminfo').readAsString());
    } catch (_) {
      return null;
    }
  }

  Future<DiskInfo?> _disk() async {
    for (final path in const ['/data', '/storage/emulated/0']) {
      try {
        final r = await Process.run('df', ['-k', path]).timeout(const Duration(seconds: 4));
        if (r.exitCode == 0) {
          final parsed = parseDfOutput('${r.stdout}');
          if (parsed != null) return parsed;
        }
      } catch (_) {
        // Sıradaki yolu dene.
      }
    }
    return null;
  }

  Future<Duration?> _uptime() async {
    try {
      return parseUptime(await File('/proc/uptime').readAsString());
    } catch (_) {
      return null;
    }
  }
}
