import 'package:battery_plus/battery_plus.dart';

import '../services/notification_service.dart';
import '../utils/alert_rules.dart';
import 'app_settings.dart';
import 'live_stats.dart';

/// Canlı ölçümleri dinler ve eşik aşılınca BİR KEZ bildirim gönderir.
/// Ölçümler yalnızca uygulama çalışırken güncellenir (pil dostu); arka plan
/// servisi yoktur.
class AlertMonitor {
  AlertMonitor({required this.live, required this.notifier, required this.settings});

  final LiveStats live;
  final Notifier notifier;
  final AppSettings settings;

  Set<AlertKind> _active = {};
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    live.addListener(_onTick);
  }

  void dispose() {
    if (_started) live.removeListener(_onTick);
    _started = false;
  }

  void _onTick() {
    if (!settings.healthAlerts) {
      _active = {};
      return;
    }
    final snap = live.snapshot;
    if (snap.time == null) return; // henüz gerçek ölçüm yok
    final battery = snap.battery;
    final charging =
        battery.state == BatteryState.charging || battery.state == BatteryState.full;
    final result = evaluateAlerts(
      thresholds: settings.thresholds,
      active: _active,
      temperatureC: battery.temperatureCelsius,
      storageUsedRatio: snap.system.disk?.usedRatio,
      batteryPercent: battery.percent,
      charging: charging,
      memoryUsedRatio: snap.system.memory?.usedRatio,
    );
    _active = result.active;
    for (final event in result.fire) {
      notifier.showAlert(event);
    }
  }
}
