import 'package:flutter/widgets.dart';

/// Uygulama animasyonlarının tek anahtarı. Kullanıcı Görünüm sayfasından
/// kapatabilir; sistem "animasyonları kaldır" ayarı açıksa da animasyon
/// oynatılmaz.
class Motion {
  Motion._();

  static bool enabled = true;

  /// Animasyon kapalıysa süreyi sıfırlar.
  static Duration d(Duration value) => enabled ? value : Duration.zero;

  /// Bu bağlamda animasyon oynatılmalı mı?
  static bool on(BuildContext context) =>
      enabled && !MediaQuery.disableAnimationsOf(context);
}
