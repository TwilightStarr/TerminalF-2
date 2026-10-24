import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_flutter/models/tweak_model.dart';
import 'package:terminal_flutter/services/catalog_service.dart';
import 'package:terminal_flutter/services/root_service.dart';
import 'package:terminal_flutter/services/settings_service.dart';
import 'package:terminal_flutter/services/shizuku_service.dart';
import 'package:terminal_flutter/state/control_controller.dart';
import 'package:terminal_flutter/state/game_mode_controller.dart';
import 'package:terminal_flutter/utils/game_mode.dart';
import 'package:terminal_flutter/utils/shell_utils.dart';

class _FakeRoot extends RootService {
  final List<String> commands = [];
  String Function(String command)? responder;
  bool Function(String command)? failIf;

  @override
  ShellIdentity? get identity => const ShellIdentity(uid: 0, name: 'root', raw: 'uid=0(root)');

  @override
  Future<bool> hasRoot({bool forceRecheck = false}) async => true;

  @override
  Future<ShellResult> exec(String command) async {
    commands.add(command);
    if (failIf?.call(command) ?? false) {
      return const ShellResult(output: 'Exception: unsupported', exitCode: 1);
    }
    return ShellResult(output: responder?.call(command) ?? '', exitCode: 0);
  }
}

class _NoShizuku extends ShizukuService {
  @override
  Future<ShizukuProbe> probe() async =>
      const ShizukuProbe(running: false, permitted: false, error: 'yok');
}

class _EmptyCatalog extends CatalogService {
  @override
  Future<List<Tweak>> loadTweaks() async => const [];
}

class _MemStore extends SettingsService {
  final Map<String, String> data = {};

  @override
  Future<String> readString(String key, {required String fallback}) async => data[key] ?? fallback;

  @override
  Future<void> writeString(String key, String value) async => data[key] = value;
}

String _device(String cmd) {
  if (cmd == 'settings get system peak_refresh_rate') return '120.0';
  if (cmd == 'settings get system min_refresh_rate') return 'null';
  if (cmd == 'settings get system user_refresh_rate') return 'null';
  if (cmd == 'settings get secure miui_refresh_rate') return '120';
  if (cmd == 'wm size') return 'Physical size: 1220x2712';
  if (cmd == 'wm density') return 'Physical density: 440';
  if (cmd.startsWith('dumpsys display')) return 'mActiveMode={id=2, fps=90.0}';
  return '';
}

Future<({ControlController control, _FakeRoot root, _MemStore store, GameModeController game, List<String> launched})>
    _setup() async {
  final root = _FakeRoot()..responder = _device;
  final control = ControlController(root: root, shizuku: _NoShizuku(), catalog: _EmptyCatalog());
  await control.init();
  final store = _MemStore();
  final launched = <String>[];
  final game = GameModeController(
    control: control,
    store: store,
    launcher: (p) async => launched.add(p),
    delay: (_) async {},
  );
  await game.load();
  return (control: control, root: root, store: store, game: game, launched: launched);
}

void main() {
  test('başlat: önce eski değerler diske yazılır, sonra uygulanır, oyun açılır', () async {
    final t = await _setup();
    final result = await t.game.start();
    expect(result.ok, isTrue);
    expect(t.game.active, isTrue);
    expect(t.launched, [kDefaultGamePackage]);

    final saved = GameSession.decode(t.store.data['game_session']!)!;
    expect(saved.settings['system:peak_refresh_rate'], '120.0');
    expect(saved.settings['system:min_refresh_rate'], isNull);

    final firstWrite = t.root.commands.indexWhere((c) => c.startsWith('settings put'));
    final lastRead = t.root.commands.lastIndexWhere((c) => c.startsWith('settings get'));
    expect(lastRead < firstWrite, isTrue, reason: 'okumalar yazmalardan önce olmalı');
    expect(t.game.displayHz, 90.0);
  });

  test('launch=false oyunu açmaz', () async {
    final t = await _setup();
    await t.game.start(launch: false);
    expect(t.launched, isEmpty);
  });

  test('geri al: orijinal değerler yazılır, oturum silinir', () async {
    final t = await _setup();
    await t.game.start(launch: false);
    t.root.commands.clear();
    final r = await t.game.stop();
    expect(r.ok, isTrue);
    expect(t.game.active, isFalse);
    expect(t.store.data['game_session'], '');
    final all = t.root.commands.join('\n');
    expect(all, contains('settings put system peak_refresh_rate 120.0'));
    expect(all, contains('settings delete system min_refresh_rate'));
    expect(all, contains('cmd game reset $kDefaultGamePackage'));
  });

  test('ikinci kez başlatmak orijinal anlık görüntüyü ezmez', () async {
    final t = await _setup();
    await t.game.start(launch: false);
    // Cihaz artık "değiştirilmiş" değerleri döndürüyor.
    t.root.responder = (c) => c == 'settings get system peak_refresh_rate' ? '90.0' : _device(c);
    await t.game.start(launch: false);
    // Araya giren geri alma orijinali yazdı; yeni anlık görüntü de buna göre alındı.
    final puts = t.root.commands.where((c) => c.contains('peak_refresh_rate 120.0'));
    expect(puts, isNotEmpty);
  });

  test('tüm ekran yöntemi wm size yazar ve geri alırken reset yapar', () async {
    final t = await _setup();
    await t.game.updateConfig(
      const GameModeConfig(method: ResolutionMethod.wholeScreen, scale: 0.5),
    );
    await t.game.start(launch: false);
    expect(t.root.commands, contains('wm size 610x1356; wm density 220'));
    t.root.commands.clear();
    await t.game.stop();
    expect(t.root.commands, contains('wm size reset; wm density reset'));
  });

  test('opsiyonel adım (cmd game) başarısızsa mod yine açık sayılır, dürüstçe raporlanır', () async {
    final t = await _setup();
    t.root.failIf = (c) => c.startsWith('cmd game');
    final r = await t.game.start(launch: false);
    expect(r.ok, isTrue);
    expect(r.optionalFailed, isNotEmpty);
    expect(r.summary, contains('desteklenmedi'));
    expect(t.game.active, isTrue);
  });

  test('zorunlu adım başarısızsa sonuç başarısız ve oturum saklanır', () async {
    final t = await _setup();
    t.root.failIf = (c) => c.contains('min_refresh_rate 90.0');
    final r = await t.game.start(launch: false);
    expect(r.ok, isFalse);
    expect(t.game.active, isTrue, reason: 'kısmen uygulanmış olabilir; geri alınabilmeli');
  });

  test('geri alma başarısızsa oturum silinmez (tekrar denenebilir)', () async {
    final t = await _setup();
    await t.game.start(launch: false);
    t.root.failIf = (c) => c.startsWith('settings put') || c.startsWith('settings delete');
    final r = await t.game.stop();
    expect(r.ok, isFalse);
    expect(t.game.active, isTrue);
    t.root.failIf = null;
    expect((await t.game.stop()).ok, isTrue);
    expect(t.game.active, isFalse);
  });

  test('uygulama yeniden açılınca oturum diskten yüklenir', () async {
    final t = await _setup();
    await t.game.start(launch: false);
    final again = GameModeController(control: t.control, store: t.store, delay: (_) async {});
    await again.load();
    expect(again.active, isTrue);
  });

  test('geçersiz paket adı reddedilir, tam kontrol yoksa işlem yapılmaz', () async {
    final t = await _setup();
    await t.game.updateConfig(const GameModeConfig(package: 'kötü paket'));
    expect(t.game.hasGame, isFalse, reason: 'geçersiz paket kaydedilmez');
    // Doğrudan geçersiz yapılandırmayla başlatmak da reddedilir:
    final bad = GameModeController(control: t.control, store: _MemStore(), delay: (_) async {});
    final r = await bad.start(overrideConfig: const GameModeConfig(package: 'a b'));
    expect(r.ok, isFalse);
    expect(t.root.commands.where((c) => c.contains('a b')), isEmpty);
  });

  test('oyun kurulu mu denetimi', () async {
    final t = await _setup();
    t.root.responder = (c) => c.startsWith('pm path') ? 'package:/data/app/base.apk' : _device(c);
    await t.game.checkInstalled();
    expect(t.game.installed, isTrue);
  });

  group('izleyici (otomatik geri alma + ölçüm)', () {
    String Function(String) withWatchdog(String status) =>
        (c) => c.contains('echo alive') ? status : _device(c);

    test('başlatılır, çalıştığı doğrulanır', () async {
      final t = await _setup();
      t.root.responder = withWatchdog('alive\nmark:none');
      final r = await t.game.start(launch: false);
      expect(
        t.root.commands.any((c) => c.startsWith('nohup sh -c ') && c.contains('TERMINALF_WATCHDOG')),
        isTrue,
      );
      expect(r.steps.last.label, 'Oyun kapanınca otomatik geri al');
      expect(r.steps.last.ok, isTrue);
      expect(t.game.watchdogAlive, isTrue);
    });

    test('çalışmıyorsa adım başarısız görünür (başarı uydurulmaz) ama mod açık kalır', () async {
      final t = await _setup();
      final r = await t.game.start(launch: false); // varsayılan yanıt: boş
      expect(r.steps.last.ok, isFalse);
      expect(r.steps.last.optional, isTrue);
      expect(r.ok, isTrue);
      expect(t.game.active, isTrue);
    });

    test('otomatik geri alma kapalıysa izleyici başlatılmaz', () async {
      final t = await _setup();
      await t.game.updateConfig(const GameModeConfig(autoRevert: false));
      await t.game.start(launch: false);
      expect(t.root.commands.any((c) => c.startsWith('nohup')), isFalse);
    });

    test('geri al izleyiciyi önce sonlandırır', () async {
      final t = await _setup();
      await t.game.start(launch: false);
      t.root.commands.clear();
      await t.game.stop();
      final kill = t.root.commands.indexWhere((c) => c.contains(r'kill $P'));
      final restore = t.root.commands.indexWhere((c) => c.startsWith('settings put'));
      expect(kill, greaterThanOrEqualTo(0));
      expect(kill < restore, isTrue);
    });

    test('izleyici geri aldıysa (mark:ok) kayıtlı oturum silinir', () async {
      final t = await _setup();
      t.root.responder = withWatchdog('alive\nmark:none');
      await t.game.start(launch: false);
      t.root.responder = withWatchdog('dead\nmark:ok');
      await t.game.syncWatchdog();
      expect(t.game.active, isFalse);
      expect(t.store.data['game_session'], '');
      expect(t.game.syncNote, contains('otomatik geri alındı'));
    });

    test('izleyicinin geri alması başarısızsa (mark:fail) oturum SAKLANIR', () async {
      final t = await _setup();
      t.root.responder = withWatchdog('alive\nmark:none');
      await t.game.start(launch: false);
      t.root.responder = withWatchdog('dead\nmark:fail');
      await t.game.syncWatchdog();
      expect(t.game.active, isTrue);
      expect(t.game.syncNote, contains('Geri Al'));
    });

    test('izleyici hâlâ canlıysa oturuma dokunulmaz', () async {
      final t = await _setup();
      t.root.responder = withWatchdog('alive\nmark:ok');
      await t.game.start(launch: false);
      await t.game.syncWatchdog();
      expect(t.game.active, isTrue);
    });

    test('animasyon ve DND: eski değerler yazılmadan önce okunur, geri alınca döner', () async {
      final t = await _setup();
      await t.game.updateConfig(const GameModeConfig(animationsOff: true, dnd: true));
      t.root.responder = (c) {
        if (c == 'settings get global window_animation_scale') return '1.0';
        if (c == 'settings get global zen_mode') return '0';
        return _device(c);
      };
      await t.game.start(launch: false);
      final saved = GameSession.decode(t.store.data['game_session']!)!;
      expect(saved.settings['global:window_animation_scale'], '1.0');
      expect(saved.settings['global:zen_mode'], '0');
      expect(t.root.commands, contains('settings put global zen_mode 1'));

      t.root.commands.clear();
      await t.game.stop();
      final all = t.root.commands.join('\n');
      expect(all, contains('settings put global window_animation_scale 1.0'));
      expect(all, contains('settings put global zen_mode 0'));
    });

    test('günlük okunur ve teşhis üretilir', () async {
      final t = await _setup();
      t.root.responder = (c) => c.startsWith('cat /data/local/tmp/terminalf_game.log')
          ? '1700000000 20 1000000000000 1001900000000 3 3200000 3400000\n'
              '1700000010 20 1000000000000 1001900000000 3 3200000 3400000'
          : _device(c);
      await t.game.refreshStats();
      expect(t.game.stats!.avgFps, closeTo(10, 0.01));
      expect(t.game.diagnosis!.kind.name, 'thermal');
    });

    test('ön plan paketi okunur', () async {
      final t = await _setup();
      t.root.responder = (c) => c.contains('mCurrentFocus')
          ? 'mCurrentFocus=Window{4f3a u0 com.example.terminal_flutter/com.example.MainActivity}'
          : _device(c);
      await t.game.detectForeground();
      expect(t.game.foregroundPackage, 'com.example.terminal_flutter');
    });
  });

  group('parlaklık ve işlemci sınırı (controller)', () {
    String Function(String) device() => (c) {
          if (c == 'settings get system screen_brightness') return '1000';
          if (c == 'settings get system screen_brightness_mode') return '1';
          if (c == kCpuPolicyReadCommand) {
            return 'policy0 2000000 2000000\npolicy4 2850000 2850000\npolicy7 3400000 3400000';
          }
          return _device(c);
        };

    test('root ile: özgün değerler okunur, sınır uygulanır, geri alınca döner', () async {
      final t = await _setup();
      await t.game.updateConfig(const GameModeConfig(dimScreen: true, cpuCap: true));
      t.root.responder = device();
      await t.game.start(launch: false);

      final saved = GameSession.decode(t.store.data['game_session']!)!;
      expect(saved.settings['system:screen_brightness'], '1000');
      expect(saved.cpuMax['policy7'], '3400000');
      expect(saved.cpuMax.containsKey('policy0'), isFalse);
      expect(t.root.commands.any((c) => c.contains('screen_brightness 600')), isTrue);
      expect(t.root.commands.any((c) => c.contains('echo 2380000 > ')), isTrue);

      t.root.commands.clear();
      final r = await t.game.stop();
      expect(r.ok, isTrue);
      final all = t.root.commands.join('\n');
      expect(all, contains('settings put system screen_brightness 1000'));
      expect(all, contains('settings put system screen_brightness_mode 1'));
      expect(all, contains('echo 3400000 > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq'));
    });

    test('parlaklık okunamazsa adım dürüstçe başarısız görünür', () async {
      final t = await _setup();
      await t.game.updateConfig(const GameModeConfig(dimScreen: true));
      final r = await t.game.start(launch: false);
      expect(r.steps.any((s) => s.label == 'Ekran parlaklığını kıs' && !s.ok), isTrue);
      expect(r.ok, isTrue);
    });
  });

  group('her oyun için ayrı profil (controller)', () {
    const logHot = '1700000000 20 1000000000000 1001900000000 3 3200000 3400000\n'
        '1700000010 20 1000000000000 1001900000000 3 3200000 3400000\n'
        '1700000020 20 1000000000000 1001900000000 3 3200000 3400000';

    test('oyun eklenince seçilir, Serin ayarıyla başlar', () async {
      final t = await _setup();
      expect(t.game.hasGame, isFalse);
      expect(await t.game.addGame('com.x.y', 'Oyun X'), isTrue);
      expect(t.game.hasGame, isTrue);
      expect(t.game.selectedName, 'Oyun X');
      expect(t.game.config.package, 'com.x.y');
      expect(t.game.config.targetFps, 30);
      expect(t.game.config.powerProfile, GamePower.battery);
    });

    test('geçersiz paket adı eklenmez', () async {
      final t = await _setup();
      expect(await t.game.addGame('a.b; rm -rf /', 'kötü'), isFalse);
      expect(t.game.games, isEmpty);
    });

    test('her oyunun ayarı ayrı tutulur ve yeniden açılınca yüklenir', () async {
      final t = await _setup();
      await t.game.addGame('com.a.one', 'Bir');
      await t.game.updateConfig(t.game.config.copyWith(targetFps: 60, scale: 0.75));
      await t.game.addGame('com.b.two', 'İki');
      expect(t.game.config.targetFps, 30);
      await t.game.selectGame('com.a.one');
      expect(t.game.config.targetFps, 60);

      final again = GameModeController(control: t.control, store: t.store, delay: (_) async {});
      await again.load();
      expect(again.games.map((g) => g.package), ['com.a.one', 'com.b.two']);
      expect(again.selectedPackage, 'com.a.one');
      expect(again.config.scale, 0.75);
    });

    test('tek dokunuş: seçili oyunun ayarı uygulanır ve o oyun açılır', () async {
      final t = await _setup();
      await t.game.addGame('com.x.y', 'Oyun X');
      final r = await t.game.startSelected();
      expect(r.ok, isTrue);
      expect(t.launched, ['com.x.y']);
      expect(t.game.activeForSelected, isTrue);
      expect(
        t.root.commands.any((c) =>
            c.startsWith('cmd game set --mode battery') &&
            c.contains('--fps 30') &&
            c.contains('--downscale 0.5') &&
            c.endsWith('com.x.y')),
        isTrue,
      );
    });

    test('oyun silinir; seçili oyun silinince diğeri seçilir', () async {
      final t = await _setup();
      await t.game.addGame('com.a.one', 'Bir');
      await t.game.addGame('com.b.two', 'İki');
      await t.game.removeGame('com.b.two');
      expect(t.game.games.map((g) => g.package), ['com.a.one']);
      expect(t.game.selectedPackage, 'com.a.one');
      await t.game.removeGame('com.a.one');
      expect(t.game.hasGame, isFalse);
    });

    test('eski tek-oyun ayarı ilk oyun olarak taşınır', () async {
      final t = await _setup();
      t.store.data['game_config'] = const GameModeConfig(package: 'com.old.game', targetFps: 60).encode();
      final again = GameModeController(control: t.control, store: t.store, delay: (_) async {});
      await again.load();
      expect(again.selectedPackage, 'com.old.game');
      expect(again.config.targetFps, 60);
    });

    test('ısındıysa daha düşük çözünürlük önerilir ve uygulanır', () async {
      final t = await _setup();
      await t.game.addGame('com.x.y', 'Oyun X');
      await t.game.startSelected(launch: false);
      t.root.responder =
          (c) => c.startsWith('cat /data/local/tmp/terminalf_game.log') ? logHot : _device(c);
      await t.game.refreshStats();
      expect(t.game.suggestion!.scale, 0.4);
      await t.game.applySuggestion();
      expect(t.game.config.scale, 0.4);
    });

    test('öneri yalnızca son oturumun oyunu için çıkar', () async {
      final t = await _setup();
      await t.game.addGame('com.a.one', 'Bir');
      await t.game.startSelected(launch: false);
      await t.game.addGame('com.b.two', 'İki');
      t.root.responder =
          (c) => c.startsWith('cat /data/local/tmp/terminalf_game.log') ? logHot : _device(c);
      await t.game.refreshStats();
      expect(t.game.suggestion, isNull);
    });
  });
}
