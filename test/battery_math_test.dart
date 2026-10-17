import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_flutter/utils/battery_math.dart';

// `estimateRemainingDuration()` saf Dart matematiği olduğu için (bkz.
// `lib/utils/battery_math.dart` yorumu) bu testler gerçek pil
// donanımına veya bir platform kanalı mock'una ihtiyaç duymaz —
// `BatteryService`'i asıl zor test edilebilir kılan kısım (`Battery()`
// plugin çağrıları) burada devre dışı.
void main() {
  final base = DateTime(2026, 1, 1, 12, 0, 0);

  group('estimateRemainingDuration', () {
    test('şarj/deşarj dışı durumlarda null döner', () {
      final result = estimateRemainingDuration(
        state: BatteryState.full,
        sampleCount: 5,
        firstTime: base,
        firstPercent: 80,
        lastTime: base.add(const Duration(minutes: 5)),
        lastPercent: 82,
      );
      expect(result, isNull);
    });

    test('yeterli örnek yoksa null döner', () {
      final result = estimateRemainingDuration(
        state: BatteryState.discharging,
        sampleCount: 1,
        firstTime: base,
        firstPercent: 80,
        lastTime: base,
        lastPercent: 80,
      );
      expect(result, isNull);
    });

    test('yeterli zaman geçmediyse null döner', () {
      final result = estimateRemainingDuration(
        state: BatteryState.discharging,
        sampleCount: 2,
        firstTime: base,
        firstPercent: 80,
        lastTime: base.add(const Duration(seconds: 10)),
        lastPercent: 79,
      );
      expect(result, isNull);
    });

    test('yüzde hiç değişmediyse null döner', () {
      final result = estimateRemainingDuration(
        state: BatteryState.discharging,
        sampleCount: 3,
        firstTime: base,
        firstPercent: 80,
        lastTime: base.add(const Duration(minutes: 5)),
        lastPercent: 80,
      );
      expect(result, isNull);
    });

    test('deşarj hızından kalan süreyi doğru hesaplar', () {
      // 10 dakikada %5 düştü (80 -> 75): hız = 5/600 %/sn.
      // %0'a kalan: 75 / (5/600) sn = 75 * 120 = 9000 sn.
      final result = estimateRemainingDuration(
        state: BatteryState.discharging,
        sampleCount: 2,
        firstTime: base,
        firstPercent: 80,
        lastTime: base.add(const Duration(minutes: 10)),
        lastPercent: 75,
      );
      expect(result, const Duration(seconds: 9000));
    });

    test('şarj hızından kalan süreyi doğru hesaplar', () {
      // 10 dakikada %10 yükseldi (60 -> 70): %100'e kalan 30 puan.
      // hız = 10/600 %/sn. süre = 30 / (10/600) = 1800 sn.
      final result = estimateRemainingDuration(
        state: BatteryState.charging,
        sampleCount: 2,
        firstTime: base,
        firstPercent: 60,
        lastTime: base.add(const Duration(minutes: 10)),
        lastPercent: 70,
      );
      expect(result, const Duration(seconds: 1800));
    });

    test('deşarjda yüzde beklenmedik şekilde artarsa null döner', () {
      final result = estimateRemainingDuration(
        state: BatteryState.discharging,
        sampleCount: 2,
        firstTime: base,
        firstPercent: 70,
        lastTime: base.add(const Duration(minutes: 10)),
        lastPercent: 75,
      );
      expect(result, isNull);
    });

    test('şarjda yüzde beklenmedik şekilde azalırsa null döner', () {
      final result = estimateRemainingDuration(
        state: BatteryState.charging,
        sampleCount: 2,
        firstTime: base,
        firstPercent: 75,
        lastTime: base.add(const Duration(minutes: 10)),
        lastPercent: 70,
      );
      expect(result, isNull);
    });

    test('minElapsedForEstimate parametresi özelleştirilebilir', () {
      // Varsayılan eşik (60 sn) altında normalde null dönerdi; daha
      // düşük özel bir eşikle aynı örnek artık bir tahmin üretmeli.
      final result = estimateRemainingDuration(
        state: BatteryState.discharging,
        sampleCount: 2,
        firstTime: base,
        firstPercent: 50,
        lastTime: base.add(const Duration(seconds: 10)),
        lastPercent: 49,
        minElapsedForEstimate: const Duration(seconds: 5),
      );
      expect(result, isNotNull);
    });
  });
}
