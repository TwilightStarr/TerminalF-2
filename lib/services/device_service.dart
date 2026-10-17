import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// Uygulama acilisinda bir kez okunan, degismeyen cihaz bilgileri.
///
/// Godot'taki `_refresh_static_info()` icindeki cihaz/ekran blogunun
/// "cihaz" kismina karsilik gelir.
class DeviceStaticInfo {
  const DeviceStaticInfo({
    required this.model,
    required this.os,
    required this.cpuArch,
    required this.coreCount,
    required this.locale,
  });

  final String model;
  final String os;
  final String cpuArch;
  final int coreCount;
  final String locale;

  static const DeviceStaticInfo unknown = DeviceStaticInfo(
    model: 'Bilinmiyor',
    os: 'Bilinmiyor',
    cpuArch: 'Bilinmiyor',
    coreCount: 0,
    locale: 'Bilinmiyor',
  );
}

/// Godot'taki `OS.get_model_name()`, `OS.get_name()`, `OS.get_version()`,
/// `OS.get_processor_name()`, `OS.get_processor_count()`,
/// `OS.get_locale()` cagrilarinin Flutter karsiligi.
///
/// NOT: Godot'un `OS.get_processor_name()` fonksiyonuna dogrudan
/// karsilik gelen, tum platformlarda calisan resmi bir Flutter API'si
/// yok; bu yuzden desteklenen islemci mimarisi (`supportedAbis` /
/// `utsname.machine`) gosteriliyor. Tam islemci modeli adi icin
/// platform kanali gerekir (bkz. README > YGL).
class DeviceService {
  final DeviceInfoPlugin _plugin = DeviceInfoPlugin();

  Future<DeviceStaticInfo> read() async {
    var model = 'Bilinmiyor';
    var os = 'Bilinmiyor';
    var cpuArch = 'Bilinmiyor';

    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        model = '${info.manufacturer} ${info.model}';
        os = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
        cpuArch = info.supportedAbis.isNotEmpty ? info.supportedAbis.first : 'Bilinmiyor';
      } else if (Platform.isIOS) {
        final info = await _plugin.iosInfo;
        model = info.utsname.machine;
        os = '${info.systemName} ${info.systemVersion}';
        cpuArch = info.utsname.machine;
      } else {
        // Masaustu (gelistirme/test) icin genel bilgi.
        model = Platform.operatingSystem;
        os = Platform.operatingSystemVersion;
        cpuArch = Platform.version.split(' ').first;
      }
    } catch (_) {
      // Okuma basarisiz olursa varsayilan "Bilinmiyor" degerleriyle devam et.
    }

    return DeviceStaticInfo(
      model: model,
      os: os,
      cpuArch: cpuArch,
      coreCount: Platform.numberOfProcessors,
      locale: Platform.localeName,
    );
  }
}
