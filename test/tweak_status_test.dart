import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_flutter/models/tweak_model.dart';
import 'package:terminal_flutter/utils/shell_utils.dart';
import 'package:terminal_flutter/utils/tweak_status.dart';

void main() {
  group('outputsMatch', () {
    test('birebir eşleşme', () {
      expect(outputsMatch('1', '1'), isTrue);
      expect(outputsMatch('1', '0'), isFalse);
    });

    test('boşluk ve boş satırlar yok sayılır', () {
      expect(outputsMatch('0\n0', ' 0 \n\n0\n'), isTrue);
    });

    test('sayılar sayısal karşılaştırılır (0 == 0.0)', () {
      expect(outputsMatch('0\n0\n0', '0.0\n0\n0.0'), isTrue);
      expect(outputsMatch('120.0', '120'), isTrue);
      expect(outputsMatch('60.0', '120.0'), isFalse);
    });

    test('satır sayısı farklıysa eşleşmez', () {
      expect(outputsMatch('a\nb', 'a'), isFalse);
      expect(outputsMatch('package:x', ''), isFalse);
    });
  });

  group('stateFromCheckResult', () {
    test('beklenen çıktı -> AÇIK', () {
      final state = stateFromCheckResult(
        expected: '1',
        result: const ShellResult(output: '1', exitCode: 0),
      );
      expect(state, TweakState.on);
    });

    test('farklı çıktı ("null" dahil) -> KAPALI', () {
      final state = stateFromCheckResult(
        expected: '1',
        result: const ShellResult(output: 'null', exitCode: 0),
      );
      expect(state, TweakState.off);
    });

    test('boş çıktı başarılıysa (paket devre dışı değil) -> KAPALI', () {
      final state = stateFromCheckResult(
        expected: 'package:com.x',
        result: const ShellResult(output: '', exitCode: 0),
      );
      expect(state, TweakState.off);
    });

    test('komut başarısızsa -> BİLİNMİYOR', () {
      final state = stateFromCheckResult(
        expected: '1',
        result: const ShellResult(output: '', exitCode: 127),
      );
      expect(state, TweakState.unknown);
    });

    test('çıktı hata içeriyorsa -> BİLİNMİYOR', () {
      final state = stateFromCheckResult(
        expected: '1',
        result: const ShellResult(output: 'java.lang.SecurityException: denied'),
      );
      expect(state, TweakState.unknown);
    });
  });

  test('TweakStatus.isLive: yalnızca tahmini olmayan ve bilinen durum', () {
    expect(const TweakStatus(TweakState.on).isLive, isTrue);
    expect(const TweakStatus(TweakState.on, estimated: true).isLive, isFalse);
    expect(const TweakStatus(TweakState.unknown).isLive, isFalse);
  });

  group('Tweak modeli', () {
    test('checkCommand/expectedOutput opsiyoneldir', () {
      final tweak = Tweak.fromJson({
        'id': 'x',
        'title': 'X',
        'applyCommand': 'a',
      });
      expect(tweak.checkCommand, isNull);
      expect(tweak.hasCheck, isFalse);
      expect(tweak.isToggle, isFalse);
    });

    test('checkCommand + expectedOutput okunur', () {
      final tweak = Tweak.fromJson({
        'id': 'x',
        'title': 'X',
        'applyCommand': 'a',
        'revertCommand': 'b',
        'checkCommand': 'settings get global foo',
        'expectedOutput': '1',
      });
      expect(tweak.hasCheck, isTrue);
      expect(tweak.isToggle, isTrue);
    });

    test('paketle gelen tweaks.json: her anahtar (toggle) tweak kontrol komutuna sahip', () {
      final raw = File('assets/config/tweaks.json').readAsStringSync();
      final tweaks = tweaksFromJsonString(raw);
      expect(tweaks, isNotEmpty);
      for (final tweak in tweaks.where((t) => t.isToggle)) {
        expect(tweak.hasCheck, isTrue, reason: '${tweak.id} için checkCommand/expectedOutput eksik');
      }
    });
  });
}
