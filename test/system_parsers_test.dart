import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_flutter/utils/package_safety.dart';
import 'package:terminal_flutter/utils/system_parsers.dart';

void main() {
  group('parseMemInfo', () {
    const sample = 'MemTotal:        3800000 kB\n'
        'MemFree:          200000 kB\n'
        'MemAvailable:    1900000 kB\n'
        'Buffers:           10000 kB\n';

    test('toplam ve kullanılabilir belleği okur', () {
      final info = parseMemInfo(sample)!;
      expect(info.totalBytes, 3800000 * 1024);
      expect(info.availableBytes, 1900000 * 1024);
      expect(info.usedRatio, closeTo(0.5, 0.001));
    });

    test('MemAvailable yoksa MemFree kullanılır', () {
      final info = parseMemInfo('MemTotal: 1000 kB\nMemFree: 250 kB\n')!;
      expect(info.availableBytes, 250 * 1024);
    });

    test('bozuk girdide null döner', () {
      expect(parseMemInfo(''), isNull);
      expect(parseMemInfo('foo'), isNull);
    });
  });

  group('parseDfOutput', () {
    test('son satırdan toplam ve kullanılanı okur', () {
      const out = 'Filesystem     1K-blocks     Used Available Use% Mounted on\n'
          '/dev/block/dm-9 113000000 56500000  56000000  51% /data\n';
      final disk = parseDfOutput(out)!;
      expect(disk.totalBytes, 113000000 * 1024);
      expect(disk.usedBytes, 56500000 * 1024);
      expect(disk.usedRatio, closeTo(0.5, 0.001));
    });

    test('tek satırda ya da bozuk girdide null', () {
      expect(parseDfOutput('Filesystem 1K-blocks'), isNull);
      expect(parseDfOutput('a\nb c'), isNull);
      expect(parseDfOutput(''), isNull);
    });
  });

  group('parseUptime', () {
    test('saniyeyi okur', () {
      expect(parseUptime('3600.55 12345.00'), const Duration(seconds: 3601));
      expect(parseUptime('abc'), isNull);
    });
  });

  group('package_safety', () {
    test('kritik ve kendi paketimiz korunur', () {
      expect(isProtectedPackage('android'), isTrue);
      expect(isProtectedPackage('com.android.systemui'), isTrue);
      expect(isProtectedPackage('com.example.terminal_flutter'), isTrue);
      expect(isProtectedPackage('com.facebook.katana'), isFalse);
    });

    test('pm list packages çıktısı ayrıştırılır', () {
      const out = 'package:com.b.app\r\npackage:com.a.app\nWarning: foo\n';
      expect(parsePackageList(out), ['com.a.app', 'com.b.app']);
    });
  });
}
