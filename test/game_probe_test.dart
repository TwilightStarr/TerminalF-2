import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_flutter/utils/game_probe.dart';

String _latency({int frames = 11, int stepNs = 100000000}) {
  final lines = <String>['16666666'];
  for (var i = 0; i < frames; i++) {
    final t = 1000000000000 + i * stepNs;
    lines.add('$t $t $t');
  }
  lines.add('9223372036854775807 9223372036854775807 9223372036854775807');
  lines.add('0 0 0');
  return lines.join('\n');
}

void main() {
  group('ön plan paketi', () {
    test('mCurrentFocus satırından paket adı okunur', () {
      const out = '  mCurrentFocus=Window{4f3a1b2 u0 com.playdigious.ninekings/'
          'com.unity3d.player.UnityPlayerActivity}';
      expect(parseFocusedPackage(out), 'com.playdigious.ninekings');
    });

    test('odak yoksa ya da biçim tanınmazsa null', () {
      expect(parseFocusedPackage('  mCurrentFocus=null'), isNull);
      expect(parseFocusedPackage(''), isNull);
      expect(parseFocusedPackage('bambaşka çıktı'), isNull);
    });
  });

  group('katman seçimi', () {
    const list = 'Background for SurfaceView[com.playdigious.ninekings/com.unity3d.player.UnityPlayerActivity](BLAST)#123\n'
        'SurfaceView[com.playdigious.ninekings/com.unity3d.player.UnityPlayerActivity](BLAST)#124\n'
        'com.playdigious.ninekings/com.unity3d.player.UnityPlayerActivity#122\n'
        'Bounds for - com.playdigious.ninekings/com.unity3d.player.UnityPlayerActivity#125\n'
        'StatusBar#5';

    test('SurfaceView katmanı tercih edilir, yardımcı katmanlar atlanır', () {
      final layer = pickGameLayer(list, 'com.playdigious.ninekings');
      expect(layer, startsWith('SurfaceView[com.playdigious.ninekings'));
    });

    test('SurfaceView yoksa ilk uygun katman', () {
      final layer = pickGameLayer(
        'com.playdigious.ninekings/x.Activity#1\nStatusBar#5',
        'com.playdigious.ninekings',
      );
      expect(layer, 'com.playdigious.ninekings/x.Activity#1');
    });

    test('oyun katmanı yoksa null', () {
      expect(pickGameLayer('StatusBar#5\nNavigationBar0#6', 'com.playdigious.ninekings'), isNull);
    });
  });

  group('kare hızı', () {
    test('100 ms aralıklı 11 kare = 10 FPS, bekleyen satırlar yok sayılır', () {
      final s = parseLatency(_latency())!;
      expect(s.frames, 11);
      expect(s.fps, closeTo(10.0, 0.01));
      expect(s.worstFrameMs, closeTo(100, 0.01));
    });

    test('11 ms aralık ≈ 90 FPS', () {
      final s = parseLatency(_latency(frames: 60, stepNs: 11111111))!;
      expect(s.fps, closeTo(90, 0.5));
    });

    test('yetersiz ya da bozuk veri null döner', () {
      expect(parseLatency(''), isNull);
      expect(parseLatency('16666666\n1 1 1'), isNull);
      expect(parseLatency(_latency(frames: 3)), isNull);
    });

    test('fpsFromWindow sınır durumları', () {
      expect(fpsFromWindow(3, 0, 1000000000), isNull);
      expect(fpsFromWindow(20, 5, 5), isNull);
      expect(fpsFromWindow(20, 1000000000000, 1001900000000), closeTo(10, 0.01));
    });
  });

  group('ısıl durum', () {
    test('Thermal Status okunur', () {
      expect(parseThermalStatus('Thermal Status: 2\nOther: 1'), 2);
      expect(parseThermalStatus('hiçbir şey'), isNull);
    });

    test('etiketler', () {
      expect(thermalLabel(0), 'Normal');
      expect(thermalLabel(2), 'Orta');
      expect(thermalLabel(5), 'Kritik');
    });
  });

  group('izleyici günlüğü', () {
    test('satır çözümü: FPS ve büyük çekirdek oranı', () {
      final s = parseWatchLine('1700000010 20 1000000000000 1001900000000 2 3000000 3400000')!;
      expect(s.fps, closeTo(10, 0.01));
      expect(s.thermal, 2);
      expect(s.cpuRatio, closeTo(0.882, 0.001));
    });

    test('eksik değerler (-) null olur, uydurulmaz', () {
      final s = parseWatchLine('1700000010 - - - - - -')!;
      expect(s.fps, isNull);
      expect(s.thermal, isNull);
      expect(s.cpuRatio, isNull);
    });

    test('bozuk satır null', () {
      expect(parseWatchLine('merhaba'), isNull);
      expect(parseWatchLine('x 1 2 3 4 5 6'), isNull);
    });

    test('oturum özeti', () {
      const log = '1700000000 20 1000000000000 1001900000000 1 3000000 3400000\n'
          '1700000010 20 1000000000000 1000950000000 2 3200000 3400000\n'
          'çöp satır\n'
          '1700000020 - - - 3 - -';
      final s = parseWatchLog(log)!;
      expect(s.samples, 3);
      expect(s.durationSec, 20);
      expect(s.avgFps, closeTo(15.0, 0.01)); // (10 + 20) / 2
      expect(s.minFps, closeTo(10, 0.01));
      expect(s.maxThermal, 3);
      expect(s.avgCpuRatio, closeTo(0.912, 0.001));
    });

    test('boş günlük null', () {
      expect(parseWatchLog(''), isNull);
      expect(parseWatchLog('çöp'), isNull);
    });
  });

  group('teşhis', () {
    SessionStats stats({double? fps = 10, int? thermal = 0, double? ratio}) => SessionStats(
          samples: 10,
          durationSec: 100,
          avgFps: fps,
          minFps: fps,
          maxThermal: thermal,
          avgCpuRatio: ratio,
        );

    test('hedefin %90\'ı → hedefe ulaşıldı', () {
      expect(diagnose(stats(fps: 85), 90).kind, DiagnosisKind.onTarget);
    });

    test('ısıl durum ≥ 2 → ısıl kısıtlama', () {
      expect(diagnose(stats(thermal: 3, ratio: 0.9), 90).kind, DiagnosisKind.thermal);
    });

    test('ısı normal, büyük çekirdek dolu → işlemci sınırlı', () {
      expect(diagnose(stats(ratio: 0.92), 90).kind, DiagnosisKind.cpuBound);
    });

    test('ısı normal, büyük çekirdek boşta → GPU/bekleme', () {
      expect(diagnose(stats(ratio: 0.4), 90).kind, DiagnosisKind.gpuBound);
    });

    test('veri yoksa kesin hüküm verilmez', () {
      expect(diagnose(stats(), 90).kind, DiagnosisKind.unknown);
      expect(diagnose(stats(fps: null), 90).kind, DiagnosisKind.unknown);
    });

    test('metinler kesinlik iddia etmez', () {
      expect(diagnose(stats(ratio: 0.92), 90).title, contains('olası'));
      expect(diagnose(stats(thermal: 3), 90).title, contains('olası'));
    });
  });
}
