import 'package:package_info_plus/package_info_plus.dart';

String? _cachedVersion;

/// Yüklü uygulamanın sürümü (`pubspec`/derleme parametresinden). Okunamazsa
/// `—` döner; uydurma değer üretilmez.
Future<String> appVersion() async {
  if (_cachedVersion != null) return _cachedVersion!;
  try {
    final info = await PackageInfo.fromPlatform();
    _cachedVersion = info.version;
    return info.version;
  } catch (_) {
    return '—';
  }
}
