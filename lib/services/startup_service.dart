import 'package:wakelock_plus/wakelock_plus.dart';

import 'brightness_service.dart';
import 'settings_service.dart';

/// Uygulama açılırken kayıtlı tercihleri (ekranı açık tut, parlaklık)
/// uygular. Cihaz sayfası hiç açılmasa bile geçerli olur.
Future<void> applySavedPreferences() async {
  final settings = SettingsService();
  try {
    if (await settings.getKeepScreenOn()) {
      await WakelockPlus.enable();
    }
  } catch (_) {
    // Platform desteklemiyorsa sessizce yok say.
  }
  try {
    final saved = await settings.getBrightness();
    if (saved != null) {
      await BrightnessService().setBrightness(saved);
    }
  } catch (_) {
    // Sessizce yok say.
  }
}
