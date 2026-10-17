import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terminal_flutter/app.dart';
import 'package:terminal_flutter/services/battery_service.dart';
import 'package:terminal_flutter/services/catalog_service.dart';
import 'package:terminal_flutter/services/root_service.dart';
import 'package:terminal_flutter/services/shizuku_service.dart';
import 'package:terminal_flutter/services/system_stats_service.dart';
import 'package:terminal_flutter/models/tweak_model.dart';
import 'package:terminal_flutter/services/notification_service.dart';
import 'package:terminal_flutter/state/app_settings.dart';
import 'package:terminal_flutter/utils/alert_rules.dart';
import 'package:terminal_flutter/state/control_controller.dart';
import 'package:terminal_flutter/state/live_stats.dart';
import 'package:terminal_flutter/utils/system_parsers.dart';

class _FakeBattery implements BatteryReader {
  @override
  Future<BatteryReading> read() async => const BatteryReading(
        percent: 80,
        state: BatteryState.discharging,
        temperatureCelsius: 31,
      );

  @override
  void dispose() {}
}

class _FakeStats extends SystemStatsService {
  @override
  Future<SystemStats> read() async => const SystemStats(
        memory: MemInfo(totalBytes: 4 * 1024 * 1024 * 1024, availableBytes: 2 * 1024 * 1024 * 1024),
        disk: DiskInfo(totalBytes: 128 * 1024 * 1024 * 1024, usedBytes: 40 * 1024 * 1024 * 1024),
        uptime: Duration(hours: 5),
      );
}

class _NoRoot extends RootService {
  @override
  Future<bool> hasRoot({bool forceRecheck = false}) async => false;
}

class _NoShizuku extends ShizukuService {
  @override
  Future<ShizukuProbe> probe() async =>
      const ShizukuProbe(running: false, permitted: false, error: 'Shizuku servisi çalışmıyor.');
}

class _FakeNotifier implements Notifier {
  int permissionRequests = 0;
  final tasks = <String>[];
  final alerts = <AlertKind>[];

  @override
  Future<void> init() async {}

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<void> showTask({required String title, required String body}) async {
    tasks.add(title);
  }

  @override
  Future<void> showAlert(AlertEvent event) async {
    alerts.add(event.kind);
  }

  @override
  Future<void> showTest() async {}
}

class _NoCatalog extends CatalogService {
  @override
  Future<List<Tweak>> loadTweaks() async => const [];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({AppSettings.onboardedKey: true}));

  testWidgets('Ana sayfa açılır, sağlık puanı görünür ve sekmeler çalışır', (tester) async {
    final live = LiveStats(
      battery: _FakeBattery(),
      system: _FakeStats(),
      interval: const Duration(hours: 1),
    );
    final control = ControlController(
      root: _NoRoot(),
      shizuku: _NoShizuku(),
      catalog: _NoCatalog(),
    );

    await tester.pumpWidget(
      TerminalApp(live: live, control: control, notifier: _FakeNotifier()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('TerminalF'), findsOneWidget);
    expect(find.text('Cihaz Sağlığı'), findsOneWidget);
    expect(find.text('Anlık Durum'), findsOneWidget);
    // Kontrol kapalıyken kullanıcıya açık bir sonraki adım sunulur.
    expect(find.text('Tam kontrol kapalı'), findsOneWidget);

    await tester.tap(find.text('Optimize'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hazır Profiller'), findsOneWidget);
    expect(find.text('Performans'), findsOneWidget);

    // Ağaç kaldırılınca zamanlayıcılar iptal edilir.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('İlk açılışta karşılama görünür ve izin bir kez istenir', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final notifier = _FakeNotifier();
    final live = LiveStats(
      battery: _FakeBattery(),
      system: _FakeStats(),
      interval: const Duration(hours: 1),
    );
    final control = ControlController(
      root: _NoRoot(),
      shizuku: _NoShizuku(),
      catalog: _NoCatalog(),
    );

    await tester.pumpWidget(TerminalApp(live: live, control: control, notifier: notifier));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('TerminalF\'e hoş geldiniz'), findsOneWidget);
    await tester.tap(find.text('Bildirimlere İzin Ver ve Başla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(notifier.permissionRequests, 1);
    expect(find.text('TerminalF\'e hoş geldiniz'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('İşlem bitince bildirim gönderilir, ayar kapalıysa gönderilmez', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final notifier = _FakeNotifier();
    var enabled = true;
    final control = ControlController(
      root: _NoRoot(),
      shizuku: _NoShizuku(),
      catalog: _NoCatalog(),
    )
      ..notifier = notifier
      ..taskNotificationsEnabled = () => enabled;

    control.reportDone('Hızlandır', 'Tamam');
    enabled = false;
    control.reportDone('Önbellek', 'Tamam');
    await Future<void>.delayed(Duration.zero);

    expect(notifier.tasks, ['Hızlandır']);
  });
}
