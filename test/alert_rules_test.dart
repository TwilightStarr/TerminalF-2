import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_flutter/utils/alert_rules.dart';

void main() {
  const t = AlertThresholds();

  test('Eşik aşılınca bir kez uyarır, tekrar uyarmaz', () {
    var r = evaluateAlerts(thresholds: t, active: {}, temperatureC: 44);
    expect(r.fire.map((e) => e.kind), [AlertKind.heat]);

    r = evaluateAlerts(thresholds: t, active: r.active, temperatureC: 45);
    expect(r.fire, isEmpty);
    expect(r.active, {AlertKind.heat});
  });

  test('Histerezis: sınırın hemen altında uyarı temizlenmez', () {
    var r = evaluateAlerts(thresholds: t, active: {AlertKind.heat}, temperatureC: 41);
    expect(r.active, {AlertKind.heat});

    r = evaluateAlerts(thresholds: t, active: r.active, temperatureC: 38);
    expect(r.active, isEmpty);

    // Temizlendikten sonra yeniden aşılırsa tekrar uyarır.
    r = evaluateAlerts(thresholds: t, active: r.active, temperatureC: 43);
    expect(r.fire, hasLength(1));
  });

  test('Düşük pil yalnızca şarjda değilken uyarır', () {
    var r = evaluateAlerts(thresholds: t, active: {}, batteryPercent: 10, charging: true);
    expect(r.fire, isEmpty);

    r = evaluateAlerts(thresholds: t, active: {}, batteryPercent: 10);
    expect(r.fire.single.kind, AlertKind.lowBattery);

    // Şarja takılınca uyarı temizlenir.
    r = evaluateAlerts(thresholds: t, active: r.active, batteryPercent: 10, charging: true);
    expect(r.active, isEmpty);
  });

  test('Depolama ve bellek yüzdeleri doğru karşılaştırılır', () {
    final r = evaluateAlerts(
      thresholds: t,
      active: {},
      storageUsedRatio: 0.93,
      memoryUsedRatio: 0.95,
    );
    expect(r.fire.map((e) => e.kind), containsAll([AlertKind.lowStorage, AlertKind.highMemory]));

    final calm = evaluateAlerts(
      thresholds: t,
      active: {},
      storageUsedRatio: 0.5,
      memoryUsedRatio: 0.6,
    );
    expect(calm.fire, isEmpty);
  });

  test('Okunamayan ölçüm (null) durumu değiştirmez', () {
    final r = evaluateAlerts(thresholds: t, active: {AlertKind.heat});
    expect(r.active, {AlertKind.heat});
    expect(r.fire, isEmpty);
  });

  test('Eşikler özelleştirilebilir', () {
    const strict = AlertThresholds(temperatureC: 36, batteryPercent: 30);
    final r = evaluateAlerts(
      thresholds: strict,
      active: {},
      temperatureC: 37,
      batteryPercent: 25,
    );
    expect(r.fire.map((e) => e.kind), containsAll([AlertKind.heat, AlertKind.lowBattery]));
  });
}
