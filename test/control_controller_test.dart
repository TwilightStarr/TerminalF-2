import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_flutter/models/profile.dart';
import 'package:terminal_flutter/models/tweak_model.dart';
import 'package:terminal_flutter/services/catalog_service.dart';
import 'package:terminal_flutter/services/root_service.dart';
import 'package:terminal_flutter/services/shizuku_service.dart';
import 'package:terminal_flutter/state/control_controller.dart';
import 'package:terminal_flutter/utils/shell_utils.dart';
import 'package:terminal_flutter/utils/tweak_status.dart';

/// Kök varmış gibi davranan, komutları kaydeden sahte servis.
class _FakeRoot extends RootService {
  _FakeRoot({this.available = true});

  final bool available;
  final List<String> commands = [];
  String Function(String command)? responder;

  @override
  ShellIdentity? get identity =>
      available ? const ShellIdentity(uid: 0, name: 'root', raw: 'uid=0(root)') : null;

  @override
  Future<bool> hasRoot({bool forceRecheck = false}) async => available;

  @override
  Future<ShellResult> exec(String command) async {
    commands.add(command);
    final out = responder?.call(command) ?? '';
    return ShellResult(output: out, exitCode: 0);
  }
}

class _FakeShizuku extends ShizukuService {
  @override
  Future<ShizukuProbe> probe() async => const ShizukuProbe(
        running: false,
        permitted: false,
        error: 'Shizuku servisi çalışmıyor.',
      );
}

class _FakeCatalog extends CatalogService {
  _FakeCatalog(this.tweaks);
  final List<Tweak> tweaks;

  @override
  Future<List<Tweak>> loadTweaks() async => tweaks;
}

const _animations = Tweak(
  id: 'anim',
  title: 'Animasyonlar',
  description: '',
  category: TweakCategory.performance,
  applyCommand: 'settings put global window_animation_scale 0',
  revertCommand: 'settings put global window_animation_scale 1',
  checkCommand: 'settings get global window_animation_scale',
  expectedOutput: '0',
);

void main() {
  test('kök yoksa ve Shizuku çalışmıyorsa kurulum gerekir', () async {
    final c = ControlController(
      root: _FakeRoot(available: false),
      shizuku: _FakeShizuku(),
      catalog: _FakeCatalog(const []),
    );
    await c.init();
    expect(c.phase, ControlPhase.needsSetup);
    expect(c.ready, isFalse);
    expect(c.error, isNotNull);
    final outcome = await c.setTweak(_animations, apply: true);
    expect(outcome.ok, isFalse);
    c.dispose();
  });

  test('kök varsa otomatik seçilir ve durumlar cihazdan okunur', () async {
    final root = _FakeRoot()..responder = (cmd) => cmd.startsWith('settings get') ? '0' : '';
    final c = ControlController(
      root: root,
      shizuku: _FakeShizuku(),
      catalog: _FakeCatalog(const [_animations]),
    );
    await c.init();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.ready, isTrue);
    expect(c.path, AccessPath.root);
    expect(c.stateOf('anim'), TweakState.on);
    c.dispose();
  });

  test('komut çalışır ama değer değişmezse başarı bildirilmez', () async {
    // Cihaz her zaman "1" döndürüyor: tweak uygulanamıyor.
    final root = _FakeRoot()..responder = (cmd) => cmd.startsWith('settings get') ? '1' : '';
    final c = ControlController(
      root: root,
      shizuku: _FakeShizuku(),
      catalog: _FakeCatalog(const [_animations]),
    );
    await c.init();
    final outcome = await c.setTweak(_animations, apply: true);
    expect(outcome.ok, isFalse);
    expect(root.commands, contains(_animations.applyCommand));
    c.dispose();
  });

  test('profil, zaten açık olanı atlar ve özet verir', () async {
    var value = '0';
    final root = _FakeRoot()
      ..responder = (cmd) {
        if (cmd.startsWith('settings get')) return value;
        return '';
      };
    final c = ControlController(
      root: root,
      shizuku: _FakeShizuku(),
      catalog: _FakeCatalog(const [_animations]),
    );
    await c.init();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    const profile = OptimizationProfile(
      id: 't',
      title: 'Test',
      description: '',
      icon: Icons.bolt_rounded,
      tweakIds: ['anim'],
    );
    final result = await c.runProfile(profile, apply: true);
    expect(result.skipped, 1);
    expect(result.applied, 0);
    c.dispose();
  });

  test('paket adı doğrulaması komut enjeksiyonunu engeller', () async {
    expect(isValidPackageName('com.example.app'), isTrue);
    expect(isValidPackageName('com.example.app; rm -rf /'), isFalse);
    expect(isValidPackageName(r'$(reboot)'), isFalse);
    expect(isValidPackageName('android'), isFalse);

    final root = _FakeRoot();
    final c = ControlController(
      root: root,
      shizuku: _FakeShizuku(),
      catalog: _FakeCatalog(const []),
    );
    await c.init();
    final out = await c.forceStop('x; reboot');
    expect(out.ok, isFalse);
    expect(root.commands.where((e) => e.contains('reboot')), isEmpty);
    c.dispose();
  });
}
