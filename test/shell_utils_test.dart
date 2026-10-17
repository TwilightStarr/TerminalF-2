import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_flutter/utils/shell_utils.dart';

void main() {
  group('parseIdOutput', () {
    test('shell kimliğini okur', () {
      final id = parseIdOutput('uid=2000(shell) gid=2000(shell) groups=2000(shell)');
      expect(id, isNotNull);
      expect(id!.uid, 2000);
      expect(id.name, 'shell');
      expect(id.isRoot, isFalse);
      expect(id.label, 'shell');
    });

    test('root kimliğini okur', () {
      final id = parseIdOutput('uid=0(root) gid=0(root) groups=0(root)');
      expect(id!.isRoot, isTrue);
      expect(id.label, 'root');
    });

    test('uid yoksa null döner', () {
      expect(parseIdOutput(''), isNull);
      expect(parseIdOutput('Permission denied'), isNull);
    });
  });

  group('wrapForShell / parseWrappedOutput', () {
    test('komutu sh -c ile sarar ve çıkış kodu satırı ekler', () {
      final wrapped = wrapForShell('a; b');
      expect(wrapped.startsWith('sh -c '), isTrue);
      expect(wrapped.contains('( a; b ) 2>&1'), isTrue);
      expect(wrapped.contains(exitMarker), isTrue);
    });

    test('shellQuote tek tırnakları kaçırır', () {
      expect(shellQuote("it's"), r"'it'\''s'");
    });

    test('çıkış kodu satırını ayıklar', () {
      final result = parseWrappedOutput('merhaba\n$exitMarker:0\n');
      expect(result.output, 'merhaba');
      expect(result.exitCode, 0);
      expect(result.exitCodeKnown, isTrue);
      expect(result.failedByExitCode, isFalse);
    });

    test('sıfırdan farklı çıkış kodunu başarısız sayar', () {
      final result = parseWrappedOutput('hata metni\n$exitMarker:1');
      expect(result.exitCode, 1);
      expect(result.failedByExitCode, isTrue);
    });

    test('işaret satırı yoksa çıkış kodu bilinmez', () {
      final result = parseWrappedOutput('sadece çıktı');
      expect(result.exitCode, isNull);
      expect(result.exitCodeKnown, isFalse);
      expect(result.failedByExitCode, isFalse);
    });
  });

  group('failureReason', () {
    test('çıkış kodu 0 ve temiz çıktı: başarılı', () {
      expect(failureReason(const ShellResult(output: '', exitCode: 0)), isNull);
      expect(
        failureReason(const ShellResult(
          output: 'Package com.x new state: disabled-user',
          exitCode: 0,
        )),
        isNull,
      );
    });

    test('sıfırdan farklı çıkış kodu: başarısız', () {
      expect(failureReason(const ShellResult(output: '', exitCode: 1)), isNotNull);
    });

    test('çıkış kodu 0 olsa da çıktıdaki hata izi yakalanır', () {
      expect(
        failureReason(const ShellResult(
          output: "Exception occurred while executing 'disable-user': "
              'java.lang.IllegalArgumentException: Unknown package: com.x',
          exitCode: 0,
        )),
        isNotNull,
      );
    });

    test('çıkış kodu bilinmiyorsa yalnızca çıktıya bakılır', () {
      expect(failureReason(const ShellResult(output: '')), isNull);
      expect(failureReason(const ShellResult(output: 'Permission denied')), isNotNull);
    });
  });

  test('splitCommandChain ; ile zinciri böler', () {
    expect(splitCommandChain('a b; c ;; d'), ['a b', 'c', 'd']);
  });
}
