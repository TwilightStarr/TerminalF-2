import 'package:battery_plus/battery_plus.dart';

/// [BatteryService] içindeki deşarj/şarj hızı tahmini algoritmasının
/// saf (platform bağımsız) matematik kısmı.
///
/// Bilinçli olarak `BatteryService`'ten ayrı bir dosyaya çıkarıldı ki
/// birim testleri gerçek pil donanımına ya da bir platform kanalına
/// ihtiyaç duymadan çalışabilsin — bkz. `test/battery_math_test.dart`
/// ve README > YGL ("Widget/servis testlerinin genişletilmesi" maddesi).
///
/// [state] şarj durumunu bekler; yalnızca [BatteryState.charging] veya
/// [BatteryState.discharging] için bir tahmin üretir. [sampleCount],
/// çağıranın elindeki toplam örnek sayısıdır — en az 2 örnek (ilk/son)
/// olmadan güvenilir bir hız hesaplanamaz. [minElapsedForEstimate],
/// çok kısa aralıklarda gürültülü tahmin üretmemek için asgari geçen
/// süredir (bkz. `BatteryService._minElapsedForEstimate`).
///
/// Yeterli/güvenilir veri yoksa ya da yüzde beklenen yönde
/// değişmiyorsa (ör. deşarj sırasında yüzde artıyor gibi görünüyorsa —
/// örnekleme gürültüsü ya da hızlı bir şarj/deşarj geçişi olabilir)
/// `null` döner; uydurma bir süre göstermek yerine çağıranın
/// "hesaplanıyor" gibi dürüst bir durum göstermesine izin verir.
Duration? estimateRemainingDuration({
  required BatteryState state,
  required int sampleCount,
  required DateTime firstTime,
  required int firstPercent,
  required DateTime lastTime,
  required int lastPercent,
  Duration minElapsedForEstimate = const Duration(seconds: 60),
}) {
  if (state != BatteryState.charging && state != BatteryState.discharging) {
    return null;
  }
  if (sampleCount < 2) return null;

  final elapsed = lastTime.difference(firstTime);
  final percentDelta = lastPercent - firstPercent;

  // Yeterli zaman geçmediyse ya da yüzde henüz hiç değişmediyse
  // (bataryalar saniyede değil, dakikalarda %1 değişir) güvenilir bir
  // hız hesaplanamaz — uydurma bir sayı döndürmek yerine "hesaplanıyor"
  // durumunu koru.
  if (elapsed < minElapsedForEstimate || percentDelta == 0) return null;

  final ratePerSecond = percentDelta / elapsed.inSeconds;

  if (state == BatteryState.discharging) {
    if (ratePerSecond >= 0) return null; // beklenmedik yön, tahmin verme
    final secondsToEmpty = (lastPercent / -ratePerSecond).round();
    return Duration(seconds: secondsToEmpty);
  } else {
    if (ratePerSecond <= 0) return null; // beklenmedik yön, tahmin verme
    final remainingPercent = 100 - lastPercent;
    final secondsToFull = (remainingPercent / ratePerSecond).round();
    return Duration(seconds: secondsToFull);
  }
}
