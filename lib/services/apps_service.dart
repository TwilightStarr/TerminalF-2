import 'package:installed_apps/installed_apps.dart';

/// Yüklü uygulamaları listeleyen ve (yetki gerektirmeyen) temel eylemleri
/// yapan servis. Yetki gerektiren eylemler (zorla durdur, dondur, kaldır)
/// `ControlController` üzerinden çalışır.
class AppsService {
  Future<List<AppInfo>> list({required bool includeSystemApps}) async {
    try {
      final apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: !includeSystemApps,
        excludeNonLaunchableApps: true,
        withIcon: true,
      );
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return apps;
    } catch (_) {
      return const [];
    }
  }

  Future<void> launch(String packageName) async {
    try {
      await InstalledApps.startApp(packageName);
    } catch (_) {
      // Uygulama yoksa ya da başlatılamıyorsa sessizce yok say.
    }
  }

  /// Sistemin "Uygulama Bilgisi" ekranı (Zorla Durdur düğmesi burada).
  Future<void> openSystemSettings(String packageName) async {
    try {
      InstalledApps.openSettings(packageName);
    } catch (_) {
      // Sessizce yok say.
    }
  }

  /// Sistem onay diyaloğuyla kaldırır (yetki gerekmez).
  Future<bool> uninstall(String packageName) async {
    try {
      return await InstalledApps.uninstallApp(packageName) == true;
    } catch (_) {
      return false;
    }
  }
}
