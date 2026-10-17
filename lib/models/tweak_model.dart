import 'dart:convert';

/// winutil'deki "Debloat / Performance" bölümlerinin Android karşılığı.
/// Üçüncü kategori olarak "Gizlilik" eklendi çünkü Android'de debloat ve
/// gizlilik ayarları (reklam takibi, hata raporları vb.) birbirinden
/// ayrı, kendi başına anlamlı bir grup oluşturuyor.
enum TweakCategory { debloat, performance, privacy }

extension TweakCategoryX on TweakCategory {
  String get label {
    switch (this) {
      case TweakCategory.debloat:
        return 'Debloat';
      case TweakCategory.performance:
        return 'Performans';
      case TweakCategory.privacy:
        return 'Gizlilik';
    }
  }

  static TweakCategory fromJson(String value) {
    switch (value) {
      case 'debloat':
        return TweakCategory.debloat;
      case 'privacy':
        return TweakCategory.privacy;
      case 'performance':
      default:
        return TweakCategory.performance;
    }
  }
}

/// Tek bir sistem ayarı/optimizasyonu (winutil'deki bir "tweak" satırının
/// Android karşılığı).
///
/// ÖNEMLİ PLATFORM GERÇEĞİ: Android, Windows'un aksine üçüncü parti bir
/// uygulamanın `pm disable-user`, `settings put global` gibi komutları
/// KENDİ BAŞINA çalıştırmasına izin vermez — bu yalnızca `adb shell`
/// (kabuk kullanıcısı) veya kök (root) erişimiyle mümkündür. Bu yüzden
/// [ControlController], yetki yoksa komutu sessizce atlamaz/uydurmaz;
/// arayüz durumu dürüstçe gösterir (bkz. `lib/state/control_controller.dart`).
class Tweak {
  const Tweak({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.applyCommand,
    this.revertCommand,
    this.checkCommand,
    this.expectedOutput,
    this.requiresRoot = true,
    this.dangerous = false,
  });

  final String id;
  final String title;
  final String description;
  final TweakCategory category;

  /// Root yolunda `su -c` altında, Shizuku yolunda `sh -c` sarmalayıcısıyla
  /// (bkz. `ShizukuService`) çalıştırılacak kabuk komutu.
  final String applyCommand;

  /// Varsa, tweak'i geri almak için çalıştırılacak komut. `null`/boş ise
  /// bu tweak bir anahtar (toggle) değil, tek seferlik bir eylemdir
  /// (örn. "Arka Plan Uygulamalarını Temizle") — arayüzde switch yerine
  /// tek bir "Çalıştır" düğmesi gösterilir.
  final String? revertCommand;

  /// Tweak'in cihazda gerçekten AÇIK olup olmadığını okuyan, yan etkisiz
  /// (salt okunur) komut - örn. `settings get global window_animation_scale`
  /// ya da `pm list packages -d <paket>`. Opsiyoneldir; yoksa durum cihazdan
  /// okunamaz (bkz. `OptimizePage` durum rozetleri).
  final String? checkCommand;

  /// [checkCommand] çıktısının, tweak AÇIKKEN alması beklenen değeri
  /// (satır satır, boşluklar kırpılarak ve sayılar sayısal olarak
  /// karşılaştırılır - bkz. `utils/tweak_status.dart` > `outputsMatch`).
  /// Çıktı eşleşmezse tweak KAPALI sayılır.
  final String? expectedOutput;

  /// Cihazdan durum okumaya yetecek bilgi var mı? İki alan da dolu olmalı.
  bool get hasCheck =>
      checkCommand != null &&
      checkCommand!.isNotEmpty &&
      expectedOutput != null;

  /// `revertCommand` varsa anahtar (toggle), yoksa tek seferlik eylem.
  bool get isToggle => revertCommand != null && revertCommand!.isNotEmpty;

  /// Şu an için tüm tweak'lerde `true` olmalı: bu ilk sürümde tek çalıştırma
  /// yolu köktür (bkz. sınıf yorumu). Alan, ileride kök gerektirmeyen bir
  /// çalıştırma yolu eklenirse (örn. ADB üzerinden kalıcı izin) kullanılmak
  /// üzere şemada tutuluyor; bugün için yük taşımıyor.
  final bool requiresRoot;

  /// `true` ise uygulanmadan önce ekstra bir onay diyaloğu gösterilir
  /// (bkz. `winutil_tab.dart` > `_confirmDangerous`).
  final bool dangerous;

  factory Tweak.fromJson(Map<String, dynamic> json) {
    return Tweak(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: TweakCategoryX.fromJson(json['category'] as String? ?? ''),
      applyCommand: json['applyCommand'] as String,
      revertCommand: json['revertCommand'] as String?,
      checkCommand: json['checkCommand'] as String?,
      expectedOutput: json['expectedOutput'] as String?,
      requiresRoot: json['requiresRoot'] as bool? ?? true,
      dangerous: json['dangerous'] as bool? ?? false,
    );
  }
}

/// `applications.json`'daki tek bir önerilen (açık kaynak) uygulama girdisi.
class RecommendedApp {
  const RecommendedApp({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.sourceLabel,
    required this.url,
  });

  final String id;
  final String name;
  final String description;
  final String category;

  /// "F-Droid", "GitHub" vb. — kullanıcıya nereye yönlendirildiğini gösterir.
  final String sourceLabel;
  final String url;

  factory RecommendedApp.fromJson(Map<String, dynamic> json) {
    return RecommendedApp(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Genel',
      sourceLabel: json['sourceLabel'] as String? ?? 'Bağlantı',
      url: json['url'] as String,
    );
  }
}

/// `features.json`'daki hızlı ayar kısayolu — KÖK GEREKTİRMEZ, doğrudan
/// gerçek bir Android sistem ayarları ekranını açar (bkz. `app_settings`
/// paketi ve `WinUtilService.openFeatureSettings`).
class FeatureShortcut {
  const FeatureShortcut({
    required this.id,
    required this.title,
    required this.description,
    required this.settingsType,
  });

  final String id;
  final String title;
  final String description;

  /// `AppSettingsType` enum değerinin düz metin karşılığı (örn.
  /// "developer", "location") — `WinUtilService` bunu gerçek enum'a çevirir.
  final String settingsType;

  factory FeatureShortcut.fromJson(Map<String, dynamic> json) {
    return FeatureShortcut(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      settingsType: json['settingsType'] as String,
    );
  }
}

List<Tweak> tweaksFromJsonString(String source) {
  final data = jsonDecode(source) as List<dynamic>;
  return data.map((e) => Tweak.fromJson(e as Map<String, dynamic>)).toList();
}

List<RecommendedApp> appsFromJsonString(String source) {
  final data = jsonDecode(source) as List<dynamic>;
  return data.map((e) => RecommendedApp.fromJson(e as Map<String, dynamic>)).toList();
}

List<FeatureShortcut> featuresFromJsonString(String source) {
  final data = jsonDecode(source) as List<dynamic>;
  return data.map((e) => FeatureShortcut.fromJson(e as Map<String, dynamic>)).toList();
}
