import 'package:screen_brightness/screen_brightness.dart';

/// Godot çekirdeğinde karşılığı olmayan, bu Flutter sürümüne özgü yeni
/// bir yönetim özelliği: ekran parlaklığını uygulama içinden ayarlama.
///
/// `screen_brightness` paketinin **uygulama-seviyesi** ("application")
/// API'si kullanılıyor - bu, sadece Terminal ön plandayken etkili olur
/// ve Android'de `WRITE_SETTINGS` gibi kullanıcının ayrıca ayarlar
/// ekranından elle vermesi gereken özel bir izin GEREKTİRMEZ. Sistem
/// genelinde kalıcı parlaklık değiştirme ("system" API'si) bilinçli
/// olarak bu temel sürümün kapsamı dışında tutuldu - bkz. README >
/// "sınırlar".
class BrightnessService {
  final ScreenBrightness _screenBrightness = ScreenBrightness.instance;

  /// Uygulamanın su anki efektif parlaklığını okur (0.0 - 1.0).
  /// Hiç değiştirilmediyse sistemin mevcut değerini yansıtır.
  Future<double?> current() async {
    try {
      return await _screenBrightness.application;
    } catch (_) {
      return null;
    }
  }

  Future<bool> setBrightness(double value) async {
    try {
      await _screenBrightness.setApplicationScreenBrightness(value.clamp(0.0, 1.0));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Uygulama-seviyesi parlaklığı sıfırlar; ekran sistemin genel
  /// değerine döner (bkz. paket belgeleri > "Reset application
  /// brightness"). Uygulama arka plana atıldığında/kapatıldığında da
  /// paket bunu otomatik yapar (bkz. sınıf açıklaması).
  Future<void> reset() async {
    try {
      await _screenBrightness.resetApplicationScreenBrightness();
    } catch (_) {
      // Platform desteklemiyorsa sessizce yok say.
    }
  }
}
