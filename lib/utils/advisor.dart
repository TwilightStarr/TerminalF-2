/// Cihaz sağlığı puanı ve "şimdi ne yapmalıyım?" önerileri. Saf mantık:
/// platforma bağlı değil, birim testli.
library;

enum AdviceAction { freeMemory, cleanStorage, saveBattery, coolDown, enableControl }

enum AdviceLevel { info, warning, critical }

class Advice {
  const Advice({
    required this.title,
    required this.detail,
    required this.level,
    required this.action,
    required this.actionLabel,
  });

  final String title;
  final String detail;
  final AdviceLevel level;
  final AdviceAction action;
  final String actionLabel;
}

/// 0-100 arası sağlık puanı. Veri yoksa (null) o kalem puanı düşürmez.
int computeHealthScore({
  double? ramUsedRatio,
  double? storageUsedRatio,
  int? batteryPercent,
  bool charging = false,
  double? temperatureCelsius,
}) {
  var penalty = 0.0;
  if (ramUsedRatio != null && ramUsedRatio > 0.6) {
    penalty += ((ramUsedRatio - 0.6) / 0.4).clamp(0.0, 1.0) * 25;
  }
  if (storageUsedRatio != null && storageUsedRatio > 0.7) {
    penalty += ((storageUsedRatio - 0.7) / 0.3).clamp(0.0, 1.0) * 25;
  }
  if (batteryPercent != null && !charging && batteryPercent < 50) {
    penalty += ((50 - batteryPercent) / 50).clamp(0.0, 1.0) * 15;
  }
  if (temperatureCelsius != null && temperatureCelsius > 38) {
    penalty += ((temperatureCelsius - 38) / 10).clamp(0.0, 1.0) * 20;
  }
  return (100 - penalty).round().clamp(0, 100);
}

String healthLabel(int score) {
  if (score >= 85) return 'Mükemmel';
  if (score >= 70) return 'İyi';
  if (score >= 45) return 'Dikkat gerekiyor';
  return 'Kritik';
}

String _pct(double ratio) => '%${(ratio * 100).round()}';

/// Mevcut ölçümlerden, önem sırasına göre öneri listesi üretir.
List<Advice> buildAdvice({
  double? ramUsedRatio,
  double? storageUsedRatio,
  int? batteryPercent,
  bool charging = false,
  double? temperatureCelsius,
  required bool controlReady,
}) {
  final out = <Advice>[];

  if (temperatureCelsius != null && temperatureCelsius >= 42) {
    out.add(Advice(
      title: 'Cihaz ısınıyor',
      detail: 'Pil sıcaklığı ${temperatureCelsius.toStringAsFixed(1)}°C. Arka plan uygulamalarını kapatmak yardımcı olur.',
      level: temperatureCelsius >= 45 ? AdviceLevel.critical : AdviceLevel.warning,
      action: AdviceAction.coolDown,
      actionLabel: 'Soğut',
    ));
  }
  if (ramUsedRatio != null && ramUsedRatio >= 0.8) {
    out.add(Advice(
      title: 'Bellek dolu (${_pct(ramUsedRatio)})',
      detail: 'Arka plandaki uygulamalar belleği tutuyor. Temizlemek cihazı hızlandırır.',
      level: ramUsedRatio >= 0.9 ? AdviceLevel.critical : AdviceLevel.warning,
      action: AdviceAction.freeMemory,
      actionLabel: 'Hızlandır',
    ));
  }
  if (storageUsedRatio != null && storageUsedRatio >= 0.85) {
    out.add(Advice(
      title: 'Depolama dolmak üzere (${_pct(storageUsedRatio)})',
      detail: 'Önbellekleri temizleyerek yer açabilirsiniz.',
      level: storageUsedRatio >= 0.95 ? AdviceLevel.critical : AdviceLevel.warning,
      action: AdviceAction.cleanStorage,
      actionLabel: 'Temizle',
    ));
  }
  if (batteryPercent != null && batteryPercent <= 20 && !charging) {
    out.add(Advice(
      title: 'Pil azalıyor (%$batteryPercent)',
      detail: 'Pil Tasarrufu profili ekranı ve arka plan işlerini kısıtlar.',
      level: batteryPercent <= 10 ? AdviceLevel.critical : AdviceLevel.warning,
      action: AdviceAction.saveBattery,
      actionLabel: 'Tasarruf',
    ));
  }
  if (!controlReady) {
    out.add(const Advice(
      title: 'Tam kontrol kapalı',
      detail: 'Tek dokunuşla kurulumu tamamlayın; optimizasyon ve uygulama yönetimi açılır.',
      level: AdviceLevel.info,
      action: AdviceAction.enableControl,
      actionLabel: 'Etkinleştir',
    ));
  }
  return out;
}
