/// Sağlık uyarılarının kuralları. Saf mantık: platforma bağlı değil,
/// birim testli (bkz. `test/alert_rules_test.dart`).
///
/// Her uyarı bir kez tetiklenir; durum düzelmeden (histerezis payı kadar)
/// tekrar bildirim gönderilmez, böylece sınırda dolaşan bir değer
/// kullanıcıyı bildirim yağmuruna tutmaz.
library;

enum AlertKind { heat, lowStorage, lowBattery, highMemory }

class AlertThresholds {
  const AlertThresholds({
    this.temperatureC = 42,
    this.storageUsedPercent = 90,
    this.batteryPercent = 15,
    this.memoryUsedPercent = 92,
  });

  /// Pil sıcaklığı bu değere ulaşınca uyarılır (°C).
  final double temperatureC;

  /// Depolama doluluğu bu yüzdeye ulaşınca uyarılır.
  final int storageUsedPercent;

  /// Pil bu yüzdenin altına inince (şarjda değilken) uyarılır.
  final int batteryPercent;

  /// RAM doluluğu bu yüzdeye ulaşınca uyarılır.
  final int memoryUsedPercent;
}

class AlertEvent {
  const AlertEvent(this.kind, this.title, this.body);

  final AlertKind kind;
  final String title;
  final String body;
}

class AlertEvaluation {
  const AlertEvaluation({required this.fire, required this.active});

  /// Şimdi gönderilecek yeni uyarılar.
  final List<AlertEvent> fire;

  /// Hâlâ geçerli olan (tekrar bildirilmeyecek) uyarılar.
  final Set<AlertKind> active;
}

/// Ölçümleri eşiklerle karşılaştırır. Okunamayan (`null`) bir ölçüm o
/// uyarının durumunu değiştirmez.
AlertEvaluation evaluateAlerts({
  required AlertThresholds thresholds,
  required Set<AlertKind> active,
  double? temperatureC,
  double? storageUsedRatio,
  int? batteryPercent,
  bool charging = false,
  double? memoryUsedRatio,
}) {
  final next = <AlertKind>{...active};
  final fire = <AlertEvent>[];

  void apply({
    required AlertKind kind,
    required bool? trigger,
    required bool? clear,
    required String title,
    required String body,
  }) {
    if (trigger == null || clear == null) return; // ölçüm yok
    if (!next.contains(kind)) {
      if (trigger) {
        next.add(kind);
        fire.add(AlertEvent(kind, title, body));
      }
    } else if (clear) {
      next.remove(kind);
    }
  }

  final t = temperatureC;
  apply(
    kind: AlertKind.heat,
    trigger: t == null ? null : t >= thresholds.temperatureC,
    clear: t == null ? null : t < thresholds.temperatureC - 3,
    title: 'Cihaz ısındı',
    body: 'Pil sıcaklığı ${t?.toStringAsFixed(1)} °C. Ağır uygulamaları kapatıp '
        'şarjı ya da ekranı bir süre bırakmak iyi olur.',
  );

  final s = storageUsedRatio;
  final sPct = s == null ? null : s * 100;
  apply(
    kind: AlertKind.lowStorage,
    trigger: sPct == null ? null : sPct >= thresholds.storageUsedPercent,
    clear: sPct == null ? null : sPct < thresholds.storageUsedPercent - 2,
    title: 'Depolama dolmak üzere',
    body: 'Depolama %${sPct?.round()} dolu. Önbellek temizliği yer açabilir.',
  );

  final b = batteryPercent;
  apply(
    kind: AlertKind.lowBattery,
    trigger: b == null ? null : (!charging && b <= thresholds.batteryPercent),
    clear: b == null ? null : (charging || b >= thresholds.batteryPercent + 3),
    title: 'Pil azalıyor',
    body: 'Pil %$b. Pil Tasarrufu profilini açmak ömrü uzatır.',
  );

  final m = memoryUsedRatio;
  final mPct = m == null ? null : m * 100;
  apply(
    kind: AlertKind.highMemory,
    trigger: mPct == null ? null : mPct >= thresholds.memoryUsedPercent,
    clear: mPct == null ? null : mPct < thresholds.memoryUsedPercent - 4,
    title: 'Bellek dolu',
    body: 'RAM %${mPct?.round()} dolu. Hızlandır ile arka plan uygulamalarını '
        'kapatabilirsiniz.',
  );

  return AlertEvaluation(fire: fire, active: next);
}
