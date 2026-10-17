import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_flutter/utils/advisor.dart';

void main() {
  group('computeHealthScore', () {
    test('veri yoksa tam puan', () {
      expect(computeHealthScore(), 100);
    });

    test('rahat değerlerde tam puan', () {
      expect(
        computeHealthScore(
          ramUsedRatio: 0.5,
          storageUsedRatio: 0.5,
          batteryPercent: 80,
          temperatureCelsius: 32,
        ),
        100,
      );
    });

    test('dolu bellek puanı düşürür', () {
      final s = computeHealthScore(ramUsedRatio: 1.0);
      expect(s, 75);
    });

    test('şarj olurken düşük pil puanı düşürmez', () {
      expect(computeHealthScore(batteryPercent: 5, charging: true), 100);
      expect(computeHealthScore(batteryPercent: 5, charging: false), lessThan(100));
    });

    test('puan 0-100 aralığında kalır', () {
      final worst = computeHealthScore(
        ramUsedRatio: 1,
        storageUsedRatio: 1,
        batteryPercent: 0,
        temperatureCelsius: 80,
      );
      expect(worst, inInclusiveRange(0, 100));
      expect(worst, lessThan(30));
    });
  });

  group('healthLabel', () {
    test('eşikler', () {
      expect(healthLabel(95), 'Mükemmel');
      expect(healthLabel(75), 'İyi');
      expect(healthLabel(50), 'Dikkat gerekiyor');
      expect(healthLabel(10), 'Kritik');
    });
  });

  group('buildAdvice', () {
    test('her şey yolundaysa ve kontrol hazırsa öneri yok', () {
      final list = buildAdvice(
        ramUsedRatio: 0.4,
        storageUsedRatio: 0.4,
        batteryPercent: 90,
        temperatureCelsius: 30,
        controlReady: true,
      );
      expect(list, isEmpty);
    });

    test('kontrol kapalıysa etkinleştirme önerilir', () {
      final list = buildAdvice(controlReady: false);
      expect(list.single.action, AdviceAction.enableControl);
    });

    test('dolu bellek ve depolama için öneri üretir', () {
      final list = buildAdvice(
        ramUsedRatio: 0.92,
        storageUsedRatio: 0.9,
        controlReady: true,
      );
      final actions = list.map((a) => a.action).toList();
      expect(actions, contains(AdviceAction.freeMemory));
      expect(actions, contains(AdviceAction.cleanStorage));
      expect(list.first.level, AdviceLevel.critical);
    });

    test('düşük pil şarjda değilken önerilir, şarjda önerilmez', () {
      expect(
        buildAdvice(batteryPercent: 12, controlReady: true).map((a) => a.action),
        contains(AdviceAction.saveBattery),
      );
      expect(buildAdvice(batteryPercent: 12, charging: true, controlReady: true), isEmpty);
    });
  });
}
