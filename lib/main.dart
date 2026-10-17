import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/theme.dart';
import 'state/app_settings.dart';

export 'app.dart' show TerminalApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Beklenmeyen hatalar uygulamayı çökertmesin; yalnızca yerelde günlüğe
  // yazılır (hiçbir veri dışarı gönderilmez).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter hatası: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Beklenmeyen hata: $error');
    return true;
  };

  // Kayıtlı tema ilk karede doğru görünsün (yanıp sönme olmasın) diye
  // tercihler uygulama çizilmeden önce okunur.
  final settings = AppSettings();
  try {
    await settings.load();
  } catch (_) {
    // Okunamazsa varsayılan (siyah-beyaz) tema ile devam edilir.
  }
  AppTheme.applySystemChrome();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(TerminalApp(settings: settings));
}
