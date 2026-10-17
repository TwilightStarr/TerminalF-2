import 'package:app_settings/app_settings.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import '../models/tweak_model.dart';

/// Paketle gelen yapılandırma dosyalarını (tweak'ler, önerilen uygulamalar,
/// sistem kısayolları) okur ve kısayolları/bağlantıları açar. Kök ya da
/// Shizuku GEREKTİRMEZ.
class CatalogService {
  Future<List<Tweak>> loadTweaks() async =>
      tweaksFromJsonString(await rootBundle.loadString('assets/config/tweaks.json'));

  Future<List<RecommendedApp>> loadApplications() async =>
      appsFromJsonString(await rootBundle.loadString('assets/config/applications.json'));

  Future<List<FeatureShortcut>> loadFeatures() async =>
      featuresFromJsonString(await rootBundle.loadString('assets/config/features.json'));

  Future<void> openFeatureSettings(FeatureShortcut feature) async {
    try {
      await AppSettings.openAppSettings(type: _typeOf(feature.settingsType));
    } catch (_) {
      // Cihaz bu ekranı desteklemiyorsa sessizce yok say.
    }
  }

  AppSettingsType _typeOf(String value) {
    switch (value) {
      case 'developer':
        return AppSettingsType.developer;
      case 'batteryOptimization':
        return AppSettingsType.batteryOptimization;
      case 'location':
        return AppSettingsType.location;
      case 'internalStorage':
        return AppSettingsType.internalStorage;
      case 'accessibility':
        return AppSettingsType.accessibility;
      case 'security':
        return AppSettingsType.security;
      case 'display':
        return AppSettingsType.display;
      default:
        return AppSettingsType.settings;
    }
  }

  /// Bir bağlantıyı (mağaza, GitHub, Shizuku sayfası) tarayıcıda açar.
  Future<bool> openUrl(String url) async {
    try {
      return await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
