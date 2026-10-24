import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_flutter/utils/game_mode.dart';
import 'package:terminal_flutter/utils/game_probe.dart';
import 'package:terminal_flutter/utils/nine_kings.dart';

SessionStats _stats({double? fps = 10, int thermal = 0, bool guard = false, int samples = 10}) =>
    SessionStats(
      samples: samples,
      durationSec: 100,
      avgFps: fps,
      minFps: fps,
      maxThermal: thermal,
      guardTriggered: guard,
    );

void main() {
  group('profil', () {
    test('varsayılan: orta bulanıklık, 30 FPS, oyun-başına yöntem', () {
      final c = const NineKingsProfile().toConfig();
      expect(c.package, kNineKingsPackage);
      expect(c.targetFps, 30);
      expect(c.scale, 0.5);
      expect(c.method, ResolutionMethod.perGame);
      expect(c.autoRevert, isTrue);
      expect(c.dimScreen, isTrue);
      expect(c.cpuCap, isTrue);
      expect(c.animationsOff, isTrue);
      expect(c.dnd, isTrue);
    });

    test('ayrıntı kademeleri ve güçlü yöntem yapılandırmaya yansır', () {
      expect(const NineKingsProfile(detail: DetailLevel.light).toConfig().scale, 0.7);
      final strong = const NineKingsProfile(detail: DetailLevel.strong, wholeScreen: true).toConfig();
      expect(strong.scale, 0.4);
      expect(strong.method, ResolutionMethod.wholeScreen);
    });

    test('paket her zaman 9Kings paketidir', () {
      for (final d in DetailLevel.values) {
        expect(NineKingsProfile(detail: d).toConfig().package, kNineKingsPackage);
      }
    });

    test('JSON gidiş-dönüş; bozuk ya da boş veri varsayılana döner', () {
      const p = NineKingsProfile(detail: DetailLevel.strong, fps: 60, wholeScreen: true);
      final back = NineKingsProfile.decode(p.encode());
      expect(back.detail, DetailLevel.strong);
      expect(back.fps, 60);
      expect(back.wholeScreen, isTrue);
      expect(NineKingsProfile.decode('zzz').detail, DetailLevel.medium);
      expect(NineKingsProfile.decode('').fps, 30);
      expect(NineKingsProfile.fromJson({'fps': 45}).fps, 30);
    });

    test('kademe geçişleri', () {
      expect(DetailLevel.light.stronger, DetailLevel.medium);
      expect(DetailLevel.strong.stronger, isNull);
      expect(DetailLevel.strong.lighter, DetailLevel.medium);
      expect(DetailLevel.light.lighter, isNull);
    });
  });

  group('öneri', () {
    const medium = NineKingsProfile();

    test('ısındıysa bir kademe daha bulanık', () {
      final s = suggestDetail(_stats(thermal: 3), medium)!;
      expect(s.level, DetailLevel.strong);
    });

    test('ısı koruması devreye girdiyse de ısınmış sayılır', () {
      expect(suggestDetail(_stats(guard: true), medium)!.level, DetailLevel.strong);
    });

    test('en bulanık kademede daha fazla öneri yok', () {
      expect(suggestDetail(_stats(thermal: 3), const NineKingsProfile(detail: DetailLevel.strong)), isNull);
    });

    test('ısınmadı ve hedef tutuldu: bir kademe daha net', () {
      final s = suggestDetail(_stats(fps: 29), medium)!;
      expect(s.level, DetailLevel.light);
    });

    test('en net kademede daha net önerilmez', () {
      expect(suggestDetail(_stats(fps: 29), const NineKingsProfile(detail: DetailLevel.light)), isNull);
    });

    test('ısınmadı ama hedef tutmadı: öneri yok (sorun ısı değil)', () {
      expect(suggestDetail(_stats(fps: 10), medium), isNull);
    });

    test('veri yetersizse öneri yok', () {
      expect(suggestDetail(null, medium), isNull);
      expect(suggestDetail(_stats(fps: null), medium), isNull);
      expect(suggestDetail(_stats(samples: 2, thermal: 3), medium), isNull);
    });
  });
}
