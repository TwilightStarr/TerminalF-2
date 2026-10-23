/// Oyun Modu için ölçüm ve teşhis mantığı (saf, platform bağımsız, birim
/// testli): SurfaceFlinger kare zamanları, ısıl durum, CPU frekansı ve
/// izleyicinin günlük dosyası.
///
/// DÜRÜST SINIR: Buradaki her sayı cihazdan OKUNAN bir değerdir; okunamayan
/// değer `null` kalır, tahmin edilip uydurulmaz. Teşhis ([diagnose]) bir
/// sezgiseldir ve metinlerinde "olası" ifadesini taşır.
library;

import 'shell_utils.dart';

/// SurfaceFlinger "henüz sunulmadı" için kullandığı değer.
const int kPendingPresent = 9223372036854775807;

final RegExp _focusPattern =
    RegExp(r'mCurrentFocus=Window\{[^ ]+ u\d+ ([A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+)/');

/// `dumpsys window | grep mCurrentFocus` çıktısındaki ön plan paketi.
/// Biçim tanınmazsa (ya da odak yoksa) `null`.
String? parseFocusedPackage(String output) {
  final m = _focusPattern.firstMatch(output);
  return m?.group(1);
}

/// `dumpsys SurfaceFlinger --list` içinden oyunun çizim katmanını seçer.
/// `SurfaceView` içeren katman tercih edilir; "Bounds"/"Background" yardımcı
/// katmanları atlanır. Bulunamazsa `null`.
String? pickGameLayer(String listOutput, String package) {
  final candidates = outputLines(listOutput).where((line) {
    if (!line.contains(package)) return false;
    if (line.contains('Bounds') || line.startsWith('Background')) return false;
    return line.length < 300;
  }).toList();
  if (candidates.isEmpty) return null;
  for (final line in candidates) {
    if (line.contains('SurfaceView')) return line;
  }
  return candidates.first;
}

/// Bir kare penceresinin özeti.
class FrameStats {
  const FrameStats({required this.frames, required this.fps, required this.worstFrameMs});

  final int frames;
  final double fps;

  /// Penceredeki en uzun iki kare arası süre (takılma göstergesi).
  final double worstFrameMs;
}

/// `fps = (kare-1) / geçen süre`. Veri yetersizse `null`.
double? fpsFromWindow(int frames, int firstNs, int lastNs) {
  if (frames < 5 || lastNs <= firstNs) return null;
  final seconds = (lastNs - firstNs) / 1e9;
  final fps = (frames - 1) / seconds;
  if (fps.isNaN || fps.isInfinite || fps <= 0 || fps > 1000) return null;
  return fps;
}

/// `dumpsys SurfaceFlinger --latency <katman>` çıktısından gerçek sunum
/// zamanlarına (2. sütun) bakarak kare hızını hesaplar.
FrameStats? parseLatency(String output) {
  final lines = outputLines(output);
  if (lines.length < 3) return null;
  final times = <int>[];
  for (final line in lines.skip(1)) {
    final parts = line.split(RegExp(r'\s+'));
    if (parts.length < 3) continue;
    final actual = int.tryParse(parts[1]);
    if (actual == null || actual <= 0 || actual == kPendingPresent) continue;
    times.add(actual);
  }
  if (times.length < 5) return null;
  final fps = fpsFromWindow(times.length, times.first, times.last);
  if (fps == null) return null;
  var worst = 0;
  for (var i = 1; i < times.length; i++) {
    final gap = times[i] - times[i - 1];
    if (gap > worst) worst = gap;
  }
  return FrameStats(frames: times.length, fps: fps, worstFrameMs: worst / 1e6);
}

/// `dumpsys thermalservice` içindeki `Thermal Status: N` (0 = normal,
/// 1 hafif, 2 orta, 3 ciddi, 4 kritik...). Bulunamazsa `null`.
int? parseThermalStatus(String output) {
  final m = RegExp(r'Thermal Status:\s*(\d+)').firstMatch(output);
  if (m == null) return null;
  return int.tryParse(m.group(1)!);
}

/// Isıl durum sayısının okunabilir adı.
String thermalLabel(int status) {
  if (status <= 0) return 'Normal';
  if (status == 1) return 'Hafif';
  if (status == 2) return 'Orta';
  if (status == 3) return 'Ciddi';
  return 'Kritik';
}

/// İzleyicinin günlüğündeki tek örnek.
class WatchSample {
  const WatchSample({
    required this.epoch,
    this.fps,
    this.thermal,
    this.cpuRatio,
  });

  final int epoch;
  final double? fps;
  final int? thermal;

  /// Büyük çekirdek: anlık frekans / azami frekans (0–1).
  final double? cpuRatio;
}

int? _intOrNull(String s) => s == '-' ? null : int.tryParse(s);

/// Günlük satırı: `epoch kare ilkNs sonNs ısıl curKHz maxKHz`
/// (eksik değerler `-`).
WatchSample? parseWatchLine(String line) {
  final p = line.trim().split(RegExp(r'\s+'));
  if (p.length < 7) return null;
  final epoch = int.tryParse(p[0]);
  if (epoch == null) return null;
  final frames = _intOrNull(p[1]);
  final first = _intOrNull(p[2]);
  final last = _intOrNull(p[3]);
  double? fps;
  if (frames != null && first != null && last != null) {
    fps = fpsFromWindow(frames, first, last);
  }
  final cur = _intOrNull(p[5]);
  final maxKhz = _intOrNull(p[6]);
  double? ratio;
  if (cur != null && maxKhz != null && maxKhz > 0) {
    final r = cur / maxKhz;
    ratio = r < 0 ? 0.0 : (r > 1 ? 1.0 : r);
  }
  return WatchSample(epoch: epoch, fps: fps, thermal: _intOrNull(p[4]), cpuRatio: ratio);
}

/// Bir oyun oturumunun özeti.
class SessionStats {
  const SessionStats({
    required this.samples,
    required this.durationSec,
    this.avgFps,
    this.minFps,
    this.maxThermal,
    this.avgCpuRatio,
  });

  final int samples;
  final int durationSec;
  final double? avgFps;
  final double? minFps;
  final int? maxThermal;
  final double? avgCpuRatio;

  /// FPS ölçülebilen örnek yoksa özetin anlamı yoktur.
  bool get hasFps => avgFps != null;
}

/// Günlük metninden oturum özeti çıkarır; geçerli örnek yoksa `null`.
SessionStats? parseWatchLog(String raw) {
  final samples = <WatchSample>[];
  for (final line in outputLines(raw)) {
    final s = parseWatchLine(line);
    if (s != null) samples.add(s);
  }
  if (samples.isEmpty) return null;

  final fpsList = [for (final s in samples) if (s.fps != null) s.fps!];
  final ratios = [for (final s in samples) if (s.cpuRatio != null) s.cpuRatio!];
  int? maxThermal;
  for (final s in samples) {
    final t = s.thermal;
    if (t != null && (maxThermal == null || t > maxThermal)) maxThermal = t;
  }

  double? avgFps;
  double? minFps;
  if (fpsList.isNotEmpty) {
    avgFps = fpsList.reduce((a, b) => a + b) / fpsList.length;
    minFps = fpsList.reduce((a, b) => a < b ? a : b);
  }
  double? avgRatio;
  if (ratios.isNotEmpty) {
    avgRatio = ratios.reduce((a, b) => a + b) / ratios.length;
  }

  return SessionStats(
    samples: samples.length,
    durationSec: samples.last.epoch - samples.first.epoch,
    avgFps: avgFps,
    minFps: minFps,
    maxThermal: maxThermal,
    avgCpuRatio: avgRatio,
  );
}

/// Teşhis türü.
enum DiagnosisKind { onTarget, thermal, cpuBound, gpuBound, unknown }

class Diagnosis {
  const Diagnosis(this.kind, this.title, this.advice);
  final DiagnosisKind kind;
  final String title;
  final String advice;
}

/// Oturum özetinden olası darboğazı söyler. Sezgiseldir:
/// - Hedefin ≥ %90'ı → sorun yok.
/// - Ismıl durum ≥ 2 → ısıl kısıtlama olası (işlemci/GPU frekansı sistem
///   tarafından kısılıyor).
/// - Büyük çekirdek ≥ %80 frekansta → işlemci (oyun hesabı) sınırlı;
///   çözünürlük düşürmek akıcılığı pek artırmaz.
/// - Büyük çekirdek < %60 frekansta ve ısıl sorun yok → GPU/bekleme sınırlı
///   olası; çözünürlük düşürmek işe yarar.
Diagnosis diagnose(SessionStats stats, int targetFps) {
  final fps = stats.avgFps;
  if (fps == null) {
    return const Diagnosis(
      DiagnosisKind.unknown,
      'FPS ölçülemedi',
      'Bu cihazda oyunun kare zamanları okunamadı. Isı ve işlemci bilgisi yine de '
          'kaydedildiyse aşağıda görünür.',
    );
  }
  if (fps >= targetFps * 0.9) {
    return Diagnosis(
      DiagnosisKind.onTarget,
      'Hedefe ulaşıldı',
      'Ortalama ${fps.round()} FPS ile hedef $targetFps FPS\'e yakınsınız.',
    );
  }
  final thermal = stats.maxThermal;
  final ratio = stats.avgCpuRatio;
  if (thermal != null && thermal >= 2) {
    return const Diagnosis(
      DiagnosisKind.thermal,
      'Isıl kısıtlama olası',
      'Telefon ısındığı için sistem işlemci/GPU hızını kısıyor olabilir. 30 FPS ve %50 '
          'çözünürlük ayarını deneyin, şarj etmeden oynayın, kılıfı çıkarın ya da kısa mola verin.',
    );
  }
  if (ratio != null && ratio >= 0.8) {
    return const Diagnosis(
      DiagnosisKind.cpuBound,
      'İşlemci sınırlı (olası)',
      'Büyük çekirdek neredeyse tam hızda: yavaşlama oyunun kendi hesabından (çok sayıda '
          'birim, dev sayılar) geliyor. Çözünürlük düşürmek ısıyı ve pili azaltır ama FPS\'i '
          'çok artırmaz. Oyun içinde hızlandırma/otomatik savaşı kapatmak daha etkilidir.',
    );
  }
  if (ratio != null && ratio < 0.6) {
    return const Diagnosis(
      DiagnosisKind.gpuBound,
      'GPU ya da bekleme sınırlı (olası)',
      'İşlemci tam hızda çalışmıyor; darboğaz çizimde olabilir. Çözünürlüğü %50\'ye '
          'düşürmek işe yarar.',
    );
  }
  return const Diagnosis(
    DiagnosisKind.unknown,
    'Net bir darboğaz görünmüyor',
    'Veriler kesin bir sonuç vermiyor. Daha uzun bir oturumdan sonra tekrar bakın.',
  );
}
