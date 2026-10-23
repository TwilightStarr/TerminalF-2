import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_flutter/utils/game_mode.dart';
import 'package:terminal_flutter/utils/game_watchdog.dart';

GameSession _session({String package = kNineKingsPackage}) => GameSession(
      package: package,
      settings: const {
        'system:peak_refresh_rate': '120.0',
        'system:min_refresh_rate': null,
      },
      touchedGameManager: true,
      changedScreen: true,
      startedAtMs: 1,
    );

void main() {
  group('betik', () {
    test('işaret, paket ve dosya yolları yerleşir; yer tutucu kalmaz', () {
      final script = buildWatchdogScript(_session());
      expect(script, contains(kWatchdogTag));
      expect(script, contains('PKG=$kNineKingsPackage'));
      expect(script, contains('PIDF=$kWatchdogPid'));
      expect(script, contains('MARK=$kWatchdogMark'));
      expect(script.contains('@'), isFalse, reason: 'doldurulmamış yer tutucu var');
    });

    test('geri alma komutları betikte: zorunlu olan OK=0 ile, opsiyonel olan değil', () {
      final lines = buildWatchdogScript(_session()).split('\n');
      final wm = lines.firstWhere((l) => l.contains('wm size reset'));
      expect(wm, contains('|| OK=0'));
      final settings = lines.firstWhere((l) => l.contains('settings put system peak_refresh_rate 120.0'));
      expect(settings, contains('settings delete system min_refresh_rate'));
      final game = lines.firstWhere((l) => l.contains('cmd game reset'));
      expect(game, isNot(contains('OK=0')));
    });

    test('tek tırnak ve ";;" içermez (iç içe tırnaklama ve ; ile bölme güvenli)', () {
      final script = buildWatchdogScript(_session());
      expect(script.contains("'"), isFalse);
      expect(script.contains(';;'), isFalse);
    });

    test('hiç görülmezse GERİ ALMADAN çıkar', () {
      final script = buildWatchdogScript(_session());
      final idx = script.indexOf('exit 0');
      expect(idx, greaterThan(0));
      expect(script.indexOf('OK=1'), greaterThan(idx));
    });

    test('geçersiz paket adı betik üretmez (enjeksiyon engeli)', () {
      expect(buildWatchdogScript(_session(package: 'a b; reboot')), isEmpty);
    });

    test('örnekleme parametreleri kullanılır', () {
      final script = buildWatchdogScript(_session(), pollSeconds: 5, missLimit: 7, giveUpSeconds: 99);
      expect(script, contains('sleep 5'));
      expect(script, contains('-ge 7'));
      expect(script, contains('-ge 99'));
    });
  });

  group('komutlar', () {
    test('başlatma: nohup, tek tırnaklı betik, çıktı kapalı, arka plan', () {
      final cmd = buildWatchdogLaunch(buildWatchdogScript(_session()));
      expect(cmd, startsWith("nohup sh -c '"));
      expect(cmd, endsWith("</dev/null >/dev/null 2>&1 &"));
    });

    test('sonlandırma PID\'in gerçekten izleyici olduğunu doğrular', () {
      final cmd = buildWatchdogKill();
      expect(cmd, contains(kWatchdogPid));
      expect(cmd, contains('grep -q $kWatchdogTag /proc/'));
      expect(cmd, contains('kill'));
    });

    test('durum komutu alive/dead ve mark çıktısı verir', () {
      final cmd = buildWatchdogStatus();
      expect(cmd, contains('echo alive'));
      expect(cmd, contains('echo dead'));
      expect(cmd, contains('mark:'));
    });
  });

  group('durum çözümü', () {
    test('canlı + işaret yok', () {
      final s = parseWatchdogStatus('alive\nmark:none');
      expect(s.alive, isTrue);
      expect(s.revertedOk, isFalse);
      expect(s.revertFailed, isFalse);
    });

    test('ölü + geri alındı', () {
      final s = parseWatchdogStatus('dead\nmark:ok');
      expect(s.alive, isFalse);
      expect(s.revertedOk, isTrue);
    });

    test('ölü + geri alma başarısız', () {
      expect(parseWatchdogStatus('dead\nmark:fail').revertFailed, isTrue);
    });

    test('boş ya da tanınmayan çıktı: ölü sayılır, işaret yok', () {
      final s = parseWatchdogStatus('');
      expect(s.alive, isFalse);
      expect(s.mark, 'none');
      expect(parseWatchdogStatus('mark:saçma').mark, 'none');
    });
  });
}
