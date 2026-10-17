import 'shell_utils.dart';

/// Bir tweak'in cihazdaki durumu.
enum TweakState { on, off, unknown }

extension TweakStateX on TweakState {
  String get label {
    switch (this) {
      case TweakState.on:
        return 'AÇIK';
      case TweakState.off:
        return 'KAPALI';
      case TweakState.unknown:
        return 'BİLİNMİYOR';
    }
  }
}

/// Durum + bu durumun nasıl elde edildiği.
///
/// [estimated] `true` ise durum cihazdan OKUNMADI; kontrol komutu yoktu ya
/// da çalıştırılamadı ve değer uygulamanın kendi kaydından (`_appliedIds`,
/// bkz. `winutil_tab.dart`) tahmin edildi.
class TweakStatus {
  const TweakStatus(this.state, {this.estimated = false});

  final TweakState state;
  final bool estimated;

  /// Cihazdan gerçekten okunmuş (kesin) bir durum mu?
  bool get isLive => !estimated && state != TweakState.unknown;
}

/// İki çıktıyı satır satır karşılaştırır. Boşluklar kırpılır, boş satırlar
/// yok sayılır ve iki değer de sayıysa sayısal olarak karşılaştırılır
/// (`settings get` bazı cihazlarda `0`, bazılarında `0.0` döndürür).
bool outputsMatch(String expected, String actual) {
  final e = outputLines(expected);
  final a = outputLines(actual);
  if (e.length != a.length) return false;
  for (var i = 0; i < e.length; i++) {
    if (!_valueEquals(e[i], a[i])) return false;
  }
  return true;
}

bool _valueEquals(String a, String b) {
  if (a == b) return true;
  final x = double.tryParse(a);
  final y = double.tryParse(b);
  return x != null && y != null && x == y;
}

/// Bir `checkCommand` sonucundan durumu çıkarır:
/// - komut başarısız / çıktı hata içeriyor -> [TweakState.unknown]
///   (durum OKUNAMADI, bilinmiyor),
/// - çıktı [expected] ile eşleşiyor -> [TweakState.on],
/// - aksi halde -> [TweakState.off].
TweakState stateFromCheckResult({
  required String expected,
  required ShellResult result,
}) {
  if (failureReason(result) != null) return TweakState.unknown;
  return outputsMatch(expected, result.output) ? TweakState.on : TweakState.off;
}
