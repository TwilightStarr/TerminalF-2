import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_flutter/utils/game_mode.dart';

void main() {
  group('wm ayrıştırıcıları', () {
    test('fiziksel ve override boyut okunur', () {
      final s = parseWmSize('Physical size: 1220x2712\nOverride size: 813x1808\n')!;
      expect(s.physical.toString(), '1220x2712');
      expect(s.override.toString(), '813x1808');
    });

    test('override yoksa null', () {
      final s = parseWmSize('Physical size: 1220x2712')!;
      expect(s.override, isNull);
      expect(parseWmSize('hata'), isNull);
    });

    test('yoğunluk okunur', () {
      final d = parseWmDensity('Physical density: 440\nOverride density: 293')!;
      expect(d.physical, 440);
      expect(d.override, 293);
      expect(parseWmDensity('Physical density: 440')!.override, isNull);
    });
  });

  group('ölçekleme', () {
    test('boyut çift sayı ve oran korunur', () {
      final s = scaledSize(const PixelSize(1220, 2712), 0.6);
      expect(s.width.isEven && s.height.isEven, isTrue);
      expect(s.width, 732);
      expect(s.height, 1627 + 1); // 1627.2 -> 1627 (tek) -> 1628
    });

    test('yoğunluk aynı oranda küçülür, 120 altına inmez', () {
      expect(scaledDensity(440, 0.5), 220);
      expect(scaledDensity(200, 0.4), 120);
    });

    test('ölçek sınırları', () {
      final s = scaledSize(const PixelSize(1000, 2000), 0.1);
      expect(s.width, 400);
    });
  });

  test('etkin yenileme hızı okunur', () {
    expect(parseActiveRefreshRate('mActiveMode={id=2, width=1220, height=2712, fps=90.0}'), 90.0);
    expect(parseActiveRefreshRate('alakasız'), isNull);
    expect(parseActiveRefreshRate('fps=3.0'), isNull);
  });

  test('downscale argümanı izin verilen değerlere yuvarlanır', () {
    expect(downscaleArg(1.0), 'disable');
    expect(downscaleArg(0.6), '0.6');
    expect(downscaleArg(0.75), '0.75');
    expect(downscaleArg(0.5), '0.5');
    expect(downscaleArg(0.62), '0.6');
  });

  group('komut üretimi', () {
    test('varsayılan: oyun profili + performans modu + ekran kilidi', () {
      final steps = buildApplySteps(const GameModeConfig());
      final cmds = steps.map((s) => s.command).toList();
      expect(cmds, contains('am kill-all'));
      expect(cmds.any((c) => c.startsWith('cmd game set --mode performance --fps 90 --downscale 0.6 ')), isTrue);
      expect(cmds.any((c) => c == 'cmd game mode performance $kDefaultGamePackage'), isTrue);
      expect(cmds.any((c) => c.contains('min_refresh_rate 90.0')), isTrue);
      expect(cmds.any((c) => c.startsWith('wm size')), isFalse);
    });

    test('30 FPS hedefinde ekran 60 Hz\'e kilitlenir (30\'un katı)', () {
      final steps = buildApplySteps(const GameModeConfig(targetFps: 30));
      expect(steps.any((s) => s.command.contains('min_refresh_rate 60.0')), isTrue);
    });

    test('kilit kapalıysa yenileme ayarına dokunulmaz', () {
      final steps = buildApplySteps(const GameModeConfig(targetFps: 30, lockRefreshRate: false));
      expect(steps.any((s) => s.command.contains('refresh_rate')), isFalse);
    });

    test('tam çözünürlükte downscale yok', () {
      final steps = buildApplySteps(const GameModeConfig(scale: 1.0));
      expect(steps.any((s) => s.command.contains('--downscale')), isFalse);
    });

    test('tüm ekran yöntemi wm size/density yazar, oyun-başına downscale yazmaz', () {
      final steps = buildApplySteps(
        const GameModeConfig(method: ResolutionMethod.wholeScreen, scale: 0.5),
        physicalSize: const PixelSize(1220, 2712),
        physicalDensity: 440,
      );
      final wm = steps.firstWhere((s) => s.command.startsWith('wm size'));
      expect(wm.command, 'wm size 610x1356; wm density 220');
      expect(steps.any((s) => s.command.contains('--downscale')), isFalse);
      expect(wm.optional, isFalse);
    });

    test('geçersiz paket adı komut üretmez (enjeksiyon engeli)', () {
      expect(buildApplySteps(const GameModeConfig(package: 'a.b; rm -rf /')), isEmpty);
    });

    test('oyun-başına adımlar opsiyonel, ekran kilidi zorunlu', () {
      final steps = buildApplySteps(const GameModeConfig());
      expect(steps.firstWhere((s) => s.command.startsWith('cmd game set')).optional, isTrue);
      expect(steps.firstWhere((s) => s.command.contains('refresh_rate')).optional, isFalse);
    });
  });

  group('geri alma', () {
    GameSession session({bool screen = false}) => GameSession(
          package: kDefaultGamePackage,
          settings: const {
            'system:peak_refresh_rate': '120.0',
            'system:min_refresh_rate': null,
            'system:user_refresh_rate': null,
            'secure:miui_refresh_rate': '120',
          },
          touchedGameManager: true,
          changedScreen: screen,
          sizeOverride: null,
          densityOverride: '420',
          startedAtMs: 1,
        );

    test('eski değer varsa put, yoksa delete', () {
      final cmd = buildRevertSteps(session()).firstWhere((s) => s.command.contains('settings')).command;
      expect(cmd, contains('settings put system peak_refresh_rate 120.0'));
      expect(cmd, contains('settings delete system min_refresh_rate'));
      expect(cmd, contains('settings put secure miui_refresh_rate 120'));
    });

    test('ekran override yoksa reset, varsa eski değer', () {
      final cmd = buildRevertSteps(session(screen: true)).first.command;
      expect(cmd, 'wm size reset; wm density 420');
    });

    test('ekran değişmediyse wm komutu yok', () {
      expect(buildRevertSteps(session()).any((s) => s.command.startsWith('wm ')), isFalse);
    });

    test('oturum JSON gidiş-dönüş', () {
      final s = GameSession.decode(session(screen: true).encode())!;
      expect(s.settings['system:peak_refresh_rate'], '120.0');
      expect(s.settings['system:min_refresh_rate'], isNull);
      expect(s.changedScreen, isTrue);
      expect(s.densityOverride, '420');
    });

    test('bozuk ya da tehlikeli kayıt reddedilir', () {
      expect(GameSession.decode('bozuk{'), isNull);
      expect(GameSession.decode(''), isNull);
      final evil = GameSession(
        package: 'x.y; reboot',
        settings: const {},
        touchedGameManager: true,
        startedAtMs: 0,
      );
      expect(GameSession.decode(evil.encode()), isNull);
    });

    test('tehlikeli eski değer komuta girmez', () {
      const s = GameSession(
        package: kDefaultGamePackage,
        settings: {'system:peak_refresh_rate': '1; reboot'},
        touchedGameManager: false,
        startedAtMs: 0,
      );
      final cmd = buildRevertSteps(s).first.command;
      expect(cmd, isNot(contains('reboot')));
      expect(cmd, contains('settings delete system peak_refresh_rate'));
    });
  });

  test('ayar JSON gidiş-dönüş ve bozuk veri varsayılana döner', () {
    const c = GameModeConfig(targetFps: 60, scale: 0.5, method: ResolutionMethod.wholeScreen);
    final back = GameModeConfig.decode(c.encode());
    expect(back.targetFps, 60);
    expect(back.scale, 0.5);
    expect(back.method, ResolutionMethod.wholeScreen);
    expect(GameModeConfig.decode('zzz').targetFps, 90);
    expect(normalizeSettingValue('null'), isNull);
    expect(normalizeSettingValue('90.0\n'), '90.0');
  });

  group('hazır ayarlar ve ek seçenekler', () {
    test('varsayılan yapılandırmada ek seçenekler kapalı, otomatik geri alma açık', () {
      const c = GameModeConfig();
      expect(c.animationsOff, isFalse);
      expect(c.dnd, isFalse);
      expect(c.autoRevert, isTrue);
    });

    test('ön ayar paket ve yöntemi korur, değerleri uygular', () {
      const base = GameModeConfig(package: 'a.b', method: ResolutionMethod.wholeScreen, killBackground: false);
      final cool = kGamePresets.firstWhere((p) => p.id == 'cool').applyTo(base);
      expect(cool.package, 'a.b');
      expect(cool.method, ResolutionMethod.wholeScreen);
      expect(cool.killBackground, isFalse);
      expect(cool.targetFps, 30);
      expect(cool.scale, 0.5);
      expect(cool.animationsOff, isTrue);
      expect(cool.dnd, isTrue);
      expect(cool.lockRefreshRate, isTrue);
      expect(cool.dimScreen, isTrue);
      expect(cool.cpuCap, isTrue);
    });

    test('matches yalnızca birebir aynı değerlerde doğru', () {
      final p = kGamePresets.firstWhere((p) => p.id == 'balanced');
      expect(p.matches(p.applyTo(const GameModeConfig())), isTrue);
      expect(p.matches(p.applyTo(const GameModeConfig()).copyWith(scale: 0.5)), isFalse);
    });

    test('animasyon ve DND adımları yalnızca açıkken üretilir', () {
      expect(buildApplySteps(const GameModeConfig()).any((s) => s.command.contains('animation_scale')), isFalse);
      final steps = buildApplySteps(const GameModeConfig(animationsOff: true, dnd: true));
      final anim = steps.firstWhere((s) => s.command.contains('window_animation_scale'));
      expect(anim.command, contains('settings put global transition_animation_scale 0'));
      expect(anim.command, contains('settings put global animator_duration_scale 0'));
      expect(anim.optional, isTrue);
      expect(steps.any((s) => s.command == 'settings put global zen_mode 1'), isTrue);
    });

    test('geri alma: animasyon ve DND eski değerlerine döner', () {
      const s = GameSession(
        package: kDefaultGamePackage,
        settings: {
          'global:window_animation_scale': '1.0',
          'global:transition_animation_scale': null,
          'global:animator_duration_scale': '0.5',
          'global:zen_mode': '0',
        },
        touchedGameManager: false,
        startedAtMs: 0,
      );
      final steps = buildRevertSteps(s);
      final anim = steps.firstWhere((x) => x.command.contains('window_animation_scale')).command;
      expect(anim, contains('settings put global window_animation_scale 1.0'));
      expect(anim, contains('settings delete global transition_animation_scale'));
      expect(anim, contains('settings put global animator_duration_scale 0.5'));
      expect(steps.any((x) => x.command == 'settings put global zen_mode 0'), isTrue);
    });

    test('yeni alanlar JSON gidiş-dönüşünde korunur; eski kayıtta varsayılan', () {
      const c = GameModeConfig(autoRevert: false, animationsOff: true, dnd: true);
      final back = GameModeConfig.decode(c.encode());
      expect(back.autoRevert, isFalse);
      expect(back.animationsOff, isTrue);
      expect(back.dnd, isTrue);
      final old = GameModeConfig.decode('{"package":"a.b","targetFps":60,"scale":0.5}');
      expect(old.autoRevert, isTrue);
      expect(old.animationsOff, isFalse);
    });
  });

  group('parlaklık ve işlemci sınırı', () {
    const policies = [
      CpuPolicy('policy0', 2000000, 2000000),
      CpuPolicy('policy4', 2850000, 2850000),
      CpuPolicy('policy7', 3400000, 3400000),
    ];

    test('çıktı çözümü: geçersiz satırlar atlanır', () {
      final p = parseCpuPolicies('policy0 2000000 2000000\nçöp\npolicy7 3400000 3400000\npolicyX 1 2\npolicy4 0 5');
      expect(p.map((e) => e.name), ['policy0', 'policy7']);
    });

    test('en yüksek iki küme seçilir', () {
      expect(topPolicies(policies).map((e) => e.name), ['policy7', 'policy4']);
    });

    test('parlaklık mevcut değerin %60\'ına iner, mod elle yapılır', () {
      final steps = buildApplySteps(const GameModeConfig(dimScreen: true), brightness: 1000);
      final s = steps.firstWhere((x) => x.command.contains('screen_brightness '));
      expect(s.command, 'settings put system screen_brightness_mode 0; settings put system screen_brightness 600');
    });

    test('parlaklık okunamadıysa adım üretilmez', () {
      expect(buildApplySteps(const GameModeConfig(dimScreen: true)).any((x) => x.command.contains('brightness')), isFalse);
    });

    test('işlemci sınırı %70, yalnızca en yüksek iki küme', () {
      final steps = buildApplySteps(const GameModeConfig(cpuCap: true), cpuPolicies: policies);
      final cmd = steps.firstWhere((x) => x.command.contains('scaling_max_freq')).command;
      expect(cmd, contains('echo 2380000 > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq'));
      expect(cmd, contains('echo 1995000 > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq'));
      expect(cmd, isNot(contains('policy0')));
    });

    test('geri alma: parlaklık ve işlemci özgün değerlere döner', () {
      const s = GameSession(
        package: kDefaultGamePackage,
        settings: {'system:screen_brightness': '1000', 'system:screen_brightness_mode': '1'},
        touchedGameManager: false,
        cpuMax: {'policy7': '3400000', 'policy4': '2850000'},
        startedAtMs: 0,
      );
      final steps = buildRevertSteps(s);
      final b = steps.firstWhere((x) => x.command.contains('screen_brightness ')).command;
      expect(b, 'settings put system screen_brightness 1000; settings put system screen_brightness_mode 1');
      final c = steps.firstWhere((x) => x.command.contains('scaling_max_freq')).command;
      expect(c, contains('echo 3400000 > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq'));
      expect(c, contains('echo 2850000 > /sys/devices/system/cpu/cpufreq/policy4/scaling_max_freq'));
    });

    test('bozuk cpuMax kaydı komuta girmez', () {
      final s = GameSession.fromJson({
        'package': kDefaultGamePackage,
        'settings': <String, dynamic>{},
        'cpuMax': {'policy7; reboot': '3400000', 'policy4': '1; reboot'},
      });
      expect(s.cpuMax, isEmpty);
    });

    test('ısı koruması: işlemci %55, parlaklık özgün değerin %35\'i', () {
      const s = GameSession(
        package: kDefaultGamePackage,
        settings: {'system:screen_brightness': '1000'},
        touchedGameManager: false,
        cpuMax: {'policy7': '3400000'},
        startedAtMs: 0,
      );
      final cmds = buildGuardCommands(s).join('\n');
      expect(cmds, contains('echo 1870000 > /sys/devices/system/cpu/cpufreq/policy7/scaling_max_freq'));
      expect(cmds, contains('settings put system screen_brightness 350'));
    });

    test('sınırlama yapılmadıysa ısı koruması komut üretmez', () {
      const s = GameSession(package: kDefaultGamePackage, settings: {}, touchedGameManager: false, startedAtMs: 0);
      expect(buildGuardCommands(s), isEmpty);
    });
  });

  group('güç profili, pil tasarrufu ve ısı eşiği', () {
    test('serin güç profili komutlara yansır', () {
      final steps = buildApplySteps(const GameModeConfig(powerProfile: GamePower.battery));
      final cmds = steps.map((s) => s.command).toList();
      expect(cmds.any((c) => c.startsWith('cmd game set --mode battery ')), isTrue);
      expect(cmds.any((c) => c == 'cmd game mode battery $kDefaultGamePackage'), isTrue);
    });

    test('pil tasarrufu yalnızca açıkken yazılır ve geri alınır', () {
      expect(
        buildApplySteps(const GameModeConfig()).any((s) => s.command.contains('low_power')),
        isFalse,
      );
      final steps = buildApplySteps(const GameModeConfig(batterySaver: true));
      expect(steps.any((s) => s.command == 'settings put global low_power 1' && s.optional), isTrue);

      const session = GameSession(
        package: kDefaultGamePackage,
        settings: {'global:low_power': '0'},
        touchedGameManager: false,
        startedAtMs: 0,
      );
      expect(
        buildRevertSteps(session).any((s) => s.command == 'settings put global low_power 0'),
        isTrue,
      );
    });

    test('ısı koruması, pil tasarrufu kaydedildiyse onu da açar', () {
      const session = GameSession(
        package: kDefaultGamePackage,
        settings: {'global:low_power': null},
        touchedGameManager: false,
        startedAtMs: 0,
      );
      expect(buildGuardCommands(session), contains('settings put global low_power 1'));
    });

    test('yeni alanlar kaydedilir ve geçersiz eşik 40 olur', () {
      const c = GameModeConfig(powerProfile: GamePower.battery, batterySaver: true, guardTempC: 38);
      final back = GameModeConfig.decode(c.encode());
      expect(back.powerProfile, GamePower.battery);
      expect(back.batterySaver, isTrue);
      expect(back.guardTempC, 38);
      expect(GameModeConfig.fromJson({'guardTempC': 77}).guardTempC, 40);
    });

    test('hazır ayarlar: en serin olanın güç profili serin, eşiği düşük', () {
      final ice = kGamePresets.firstWhere((p) => p.id == 'ice');
      final cfg = ice.applyTo(const GameModeConfig());
      expect(cfg.powerProfile, GamePower.battery);
      expect(cfg.batterySaver, isTrue);
      expect(cfg.guardTempC, 38);
      expect(cfg.scale, 0.4);
      expect(ice.matches(cfg), isTrue);
      final ids = kGamePresets.map((p) => p.id).toSet();
      expect(ids.length, kGamePresets.length);
    });
  });
}
