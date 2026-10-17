import 'package:flutter/foundation.dart';

import '../services/settings_service.dart';
import '../utils/alert_rules.dart';
import '../utils/haptics.dart';

/// Kullanıcı tercihlerinin bellekteki (dinlenebilir) hâli. Bir kez diskten
/// okunur; değişiklikler hem arayüze hem diske yansır.
class AppSettings extends ChangeNotifier {
  AppSettings({SettingsService? store}) : _store = store ?? SettingsService();

  final SettingsService _store;

  static const String onboardedKey = 'onboarded';
  static const String _taskNotifKey = 'notif_tasks';
  static const String _alertsKey = 'notif_alerts';
  static const String _hapticsKey = 'haptics';
  static const String _tempKey = 'alert_temp';
  static const String _storageKey = 'alert_storage';
  static const String _batteryKey = 'alert_battery';
  static const String _memoryKey = 'alert_memory';

  /// İlk açılış karşılama sayfası görüldü mü? Okuma başarısız olursa
  /// (örn. test ortamı) karşılama gösterilmesin diye `true` başlar.
  bool onboarded = true;

  /// Uygulama arka plandayken işlem sonucu bildirimi.
  bool taskNotifications = true;

  /// Isınma, depolama, pil, bellek uyarıları.
  bool healthAlerts = true;

  bool haptics = true;

  double temperatureC = 42;
  int storagePercent = 90;
  int batteryPercent = 15;
  int memoryPercent = 92;

  AlertThresholds get thresholds => AlertThresholds(
        temperatureC: temperatureC,
        storageUsedPercent: storagePercent,
        batteryPercent: batteryPercent,
        memoryUsedPercent: memoryPercent,
      );

  Future<void>? _loading;

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      onboarded = await _store.readBool(onboardedKey, fallback: false);
      taskNotifications = await _store.readBool(_taskNotifKey, fallback: true);
      healthAlerts = await _store.readBool(_alertsKey, fallback: true);
      haptics = await _store.readBool(_hapticsKey, fallback: true);
      temperatureC = (await _store.readDouble(_tempKey, fallback: 42)).clamp(35.0, 50.0);
      storagePercent = (await _store.readDouble(_storageKey, fallback: 90)).round().clamp(70, 98);
      batteryPercent = (await _store.readDouble(_batteryKey, fallback: 15)).round().clamp(5, 30);
      memoryPercent = (await _store.readDouble(_memoryKey, fallback: 92)).round().clamp(80, 98);
    } catch (_) {
      // Tercihler okunamazsa varsayılanlarla devam et.
    }
    Haptics.enabled = haptics;
    notifyListeners();
  }

  Future<void> markOnboarded() async {
    onboarded = true;
    notifyListeners();
    await _safe(() => _store.writeBool(onboardedKey, true));
  }

  Future<void> setTaskNotifications(bool v) async {
    taskNotifications = v;
    notifyListeners();
    await _safe(() => _store.writeBool(_taskNotifKey, v));
  }

  Future<void> setHealthAlerts(bool v) async {
    healthAlerts = v;
    notifyListeners();
    await _safe(() => _store.writeBool(_alertsKey, v));
  }

  Future<void> setHaptics(bool v) async {
    haptics = v;
    Haptics.enabled = v;
    notifyListeners();
    await _safe(() => _store.writeBool(_hapticsKey, v));
  }

  Future<void> setTemperature(double v) async {
    temperatureC = v.clamp(35.0, 50.0);
    notifyListeners();
    await _safe(() => _store.writeDouble(_tempKey, temperatureC));
  }

  Future<void> setStoragePercent(int v) async {
    storagePercent = v.clamp(70, 98);
    notifyListeners();
    await _safe(() => _store.writeDouble(_storageKey, storagePercent.toDouble()));
  }

  Future<void> setBatteryPercent(int v) async {
    batteryPercent = v.clamp(5, 30);
    notifyListeners();
    await _safe(() => _store.writeDouble(_batteryKey, batteryPercent.toDouble()));
  }

  Future<void> setMemoryPercent(int v) async {
    memoryPercent = v.clamp(80, 98);
    notifyListeners();
    await _safe(() => _store.writeDouble(_memoryKey, memoryPercent.toDouble()));
  }

  Future<void> _safe(Future<void> Function() write) async {
    try {
      await write();
    } catch (_) {
      // Yazılamazsa bellekteki değer bu oturum için geçerli kalır.
    }
  }
}
