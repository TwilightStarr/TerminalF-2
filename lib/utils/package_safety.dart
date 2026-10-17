/// Dondurma / kaldırma gibi geri dönüşü zahmetli eylemlerde, telefonu
/// kullanılmaz hale getirebilecek paketleri korur.
library;

const Set<String> _neverTouch = {
  'android',
  'com.android.systemui',
  'com.android.settings',
  'com.android.phone',
  'com.android.providers.telephony',
  'com.android.providers.settings',
  'com.android.inputmethod.latin',
  'com.android.packageinstaller',
  'com.google.android.packageinstaller',
  'com.android.permissioncontroller',
  'com.google.android.permissioncontroller',
  'moe.shizuku.privileged.api',
};

/// Bu uygulamanın kendi paketi (derleme sırasında `com.example` önekiyle üretilir).
const String _selfPrefix = 'com.example.terminal_flutter';

/// `true` ise bu paket asla dondurulmamalı/kaldırılmamalıdır.
bool isProtectedPackage(String packageName) {
  if (packageName.startsWith(_selfPrefix)) return true;
  return _neverTouch.contains(packageName);
}

/// `pm list packages -d` çıktısından paket adlarını okur.
List<String> parsePackageList(String output) {
  final out = <String>[];
  for (final raw in output.replaceAll('\r', '').split('\n')) {
    final line = raw.trim();
    if (line.startsWith('package:')) {
      final name = line.substring('package:'.length).trim();
      if (name.isNotEmpty) out.add(name);
    }
  }
  out.sort();
  return out;
}
