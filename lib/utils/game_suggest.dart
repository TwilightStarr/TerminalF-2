/// Son oyun oturumunun ölçümüne bakarak bir sonraki oturum için ayar önerir.
/// Her oyun için aynı mantık çalışır.
library;

import 'game_mode.dart';
import 'game_probe.dart';

/// Isındıysa çözünürlüğü (gerekirse kare hızını) düşürmeyi, ısınmadıysa ve hedef
/// FPS tutulduysa bir kademe daha net görüntüyü önerir. Veri yetersizse ya da
/// değişiklik gerekmiyorsa `null`.
ScaleSuggestion? suggestSettings(SessionStats? stats, GameModeConfig config) {
  if (stats == null || stats.avgFps == null || stats.samples < 3) return null;
  final hot = (stats.maxThermal ?? 0) >= 2 || stats.guardTriggered;
  final i = scaleIndex(config.scale);
  if (hot) {
    if (i < kScaleSteps.length - 1) {
      return ScaleSuggestion(
        kScaleSteps[i + 1],
        'Son oyunda telefon ısındı. Bir kademe daha düşük çözünürlük ısıyı düşürür.',
      );
    }
    if (config.targetFps > 30) {
      return const ScaleSuggestion(
        0.4,
        'Son oyunda telefon ısındı ve çözünürlük zaten en düşükte. Kare hızını 30 FPS\'e '
        'çekmek ısıyı daha çok düşürür.',
        fps: 30,
      );
    }
    return null;
  }
  if (stats.avgFps! >= config.targetFps * 0.9 && i > 0) {
    return ScaleSuggestion(
      kScaleSteps[i - 1],
      'Son oyunda ısınma olmadı ve hedef FPS tutuldu. Bir kademe daha net görüntü deneyebilirsiniz.',
    );
  }
  return null;
}
