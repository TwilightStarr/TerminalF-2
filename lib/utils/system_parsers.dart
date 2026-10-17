/// `/proc/meminfo` ve `df` çıktılarını okunabilir sayılara çeviren saf
/// (platform bağımsız, birim testli) yardımcılar.
library;

class MemInfo {
  const MemInfo({required this.totalBytes, required this.availableBytes});

  final int totalBytes;
  final int availableBytes;

  int get usedBytes => (totalBytes - availableBytes).clamp(0, totalBytes);
  double get usedRatio => totalBytes <= 0 ? 0.0 : usedBytes / totalBytes;
}

/// `MemTotal:  3800000 kB` biçimindeki satırlardan toplam ve kullanılabilir
/// belleği okur. Okunamazsa `null`.
MemInfo? parseMemInfo(String text) {
  int? read(String key) {
    final m = RegExp('^$key:\\s*(\\d+)\\s*kB', multiLine: true).firstMatch(text);
    if (m == null) return null;
    final kb = int.tryParse(m.group(1)!);
    return kb == null ? null : kb * 1024;
  }

  final total = read('MemTotal');
  if (total == null || total <= 0) return null;
  final available = read('MemAvailable') ?? read('MemFree');
  if (available == null) return null;
  return MemInfo(totalBytes: total, availableBytes: available);
}

class DiskInfo {
  const DiskInfo({required this.totalBytes, required this.usedBytes});

  final int totalBytes;
  final int usedBytes;

  int get freeBytes => (totalBytes - usedBytes).clamp(0, totalBytes);
  double get usedRatio => totalBytes <= 0 ? 0.0 : usedBytes / totalBytes;
}

/// `df -k <yol>` çıktısının son veri satırından toplam/kullanılan boyutu okur
/// (sütunlar: Filesystem 1K-blocks Used Available Use% Mounted on).
DiskInfo? parseDfOutput(String text) {
  final lines = text
      .replaceAll('\r', '')
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  if (lines.length < 2) return null;
  final cols = lines.last.split(RegExp(r'\s+'));
  if (cols.length < 4) return null;
  final total = int.tryParse(cols[1]);
  final used = int.tryParse(cols[2]);
  if (total == null || used == null || total <= 0) return null;
  return DiskInfo(totalBytes: total * 1024, usedBytes: used * 1024);
}

/// `/proc/uptime` ilk sayısı (saniye).
Duration? parseUptime(String text) {
  final first = text.trim().split(RegExp(r'\s+')).first;
  final seconds = double.tryParse(first);
  if (seconds == null || seconds < 0) return null;
  return Duration(seconds: seconds.round());
}
