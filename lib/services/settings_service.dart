import 'package:shared_preferences/shared_preferences.dart';

/// Kalıcı tercihler. Bilerek küçük tutuldu: kullanıcıdan yalnızca gerçekten
/// işe yarayan şeyler saklanır.
class SettingsService {
  static const _keepScreenOnKey = 'keep_screen_on';
  static const _brightnessKey = 'app_brightness';
  static const _showSystemAppsKey = 'show_system_apps';

  Future<bool> getKeepScreenOn() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_keepScreenOnKey) ?? false;
  }

  Future<void> setKeepScreenOn(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_keepScreenOnKey, value);
  }

  Future<double?> getBrightness() async {
    final p = await SharedPreferences.getInstance();
    return p.getDouble(_brightnessKey);
  }

  Future<void> setBrightness(double value) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_brightnessKey, value.clamp(0.0, 1.0));
  }

  Future<void> clearBrightness() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_brightnessKey);
  }

  Future<bool> getShowSystemApps() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_showSystemAppsKey) ?? false;
  }

  Future<void> setShowSystemApps(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_showSystemAppsKey, value);
  }

  // ---- Genel okuma/yazma (uyarı eşikleri ve bildirim tercihleri için) ----

  Future<bool> readBool(String key, {required bool fallback}) async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(key) ?? fallback;
  }

  Future<void> writeBool(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
  }

  Future<double> readDouble(String key, {required double fallback}) async {
    final p = await SharedPreferences.getInstance();
    return p.getDouble(key) ?? fallback;
  }

  Future<void> writeDouble(String key, double value) async {
    final p = await SharedPreferences.getInstance();
    await p.setDouble(key, value);
  }
}
