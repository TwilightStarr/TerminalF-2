import 'package:flutter/services.dart';

/// Küçük dokunsal geri bildirimler. Ayarlardan kapatılabilir; cihaz
/// desteklemiyorsa sessizce yok sayılır.
class Haptics {
  Haptics._();

  static bool enabled = true;

  static void tap() => _run(HapticFeedback.selectionClick);
  static void success() => _run(HapticFeedback.lightImpact);
  static void warning() => _run(HapticFeedback.heavyImpact);

  static void _run(Future<void> Function() feedback) {
    if (!enabled) return;
    try {
      feedback().catchError((Object _) {});
    } catch (_) {
      // Donanım yoksa sessizce yok say.
    }
  }
}
