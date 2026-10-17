import 'dart:async';

import 'package:flutter/widgets.dart';

import '../services/battery_service.dart';
import '../services/system_stats_service.dart';

class LiveSnapshot {
  const LiveSnapshot({required this.battery, required this.system, this.time});

  final BatteryReading battery;
  final SystemStats system;
  final DateTime? time;

  static const LiveSnapshot empty = LiveSnapshot(
    battery: BatteryReading.unknown,
    system: SystemStats.empty,
  );
}

/// Canlı ölçümler (pil, bellek, depolama). Önceki sürümdeki "her saniye tüm
/// ekranı yeniden çiz" döngüsünün yerini alır:
/// - Yalnızca bu nesneyi dinleyen küçük parçalar yeniden çizilir.
/// - Uygulama arka plana geçince zamanlayıcı DURUR (pil ve CPU harcamaz).
/// - Okumalar üst üste binmez.
class LiveStats extends ChangeNotifier with WidgetsBindingObserver {
  LiveStats({
    BatteryReader? battery,
    SystemStatsService? system,
    this.interval = const Duration(seconds: 4),
  })  : _battery = battery ?? BatteryService(),
        _system = system ?? SystemStatsService();

  final BatteryReader _battery;
  final SystemStatsService _system;
  final Duration interval;

  LiveSnapshot _snapshot = LiveSnapshot.empty;
  LiveSnapshot get snapshot => _snapshot;

  Timer? _timer;
  bool _reading = false;
  bool _disposed = false;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    refresh();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      refresh();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> refresh() async {
    if (_reading || _disposed) return;
    _reading = true;
    try {
      final results = await Future.wait<Object>([_battery.read(), _system.read()]);
      if (_disposed) return;
      _snapshot = LiveSnapshot(
        battery: results[0] as BatteryReading,
        system: results[1] as SystemStats,
        time: DateTime.now(),
      );
      notifyListeners();
    } catch (_) {
      // Tek bir başarısız okuma bir sonraki turu etkilemesin.
    } finally {
      _reading = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _battery.dispose();
    super.dispose();
  }
}
