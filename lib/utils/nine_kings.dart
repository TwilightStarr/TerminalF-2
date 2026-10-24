/// 9Kings'e özel mod: tek tuşla oyunu açar. Oyun, sırf piksel sanat ve çok
/// sayıda birim çizdiği için ısınmanın büyük kısmı CPU'dan gelir; bu mod
/// ayrıntı düzeyini ("bulanıklık") kademeli düşürür, kare hızını sınırlar ve
/// her oturumdan sonra ölçüme bakarak bir sonraki kademeyi önerir.
///
/// DÜRÜST SINIR: Oyunun kendi dosyalarına/ayarlarına dokunulmaz (anahtarları
/// doğrulanamaz); yalnızca sistemin sunduğu kaldıraçlar kullanılır.
library;

import 'dart:convert';

import 'game_mode.dart';
import 'game_probe.dart';

/// Görüntü ayrıntı düzeyi: düşük ayrıntı = daha bulanık ama daha serin.
enum DetailLevel { light, medium, strong }

extension DetailLevelInfo on DetailLevel {
  /// Oyunun çizildiği çözünürlük oranı.
  double get scale {
    switch (this) {
      case DetailLevel.light:
        return 0.7;
      case DetailLevel.medium:
        return 0.5;
      case DetailLevel.strong:
        return 0.4;
    }
  }

  String get label {
    switch (this) {
      case DetailLevel.light:
        return 'Hafif bulanık';
      case DetailLevel.medium:
        return 'Orta bulanık';
      case DetailLevel.strong:
        return 'Çok bulanık';
    }
  }

  String get hint {
    switch (this) {
      case DetailLevel.light:
        return '%70 çözünürlük · görüntü neredeyse net, ısı biraz düşer';
      case DetailLevel.medium:
        return '%50 çözünürlük · piksel sanatta fark az, ısı belirgin düşer';
      case DetailLevel.strong:
        return '%40 çözünürlük · belirgin bulanık, en serin';
    }
  }

  DetailLevel? get stronger {
    switch (this) {
      case DetailLevel.light:
        return DetailLevel.medium;
      case DetailLevel.medium:
        return DetailLevel.strong;
      case DetailLevel.strong:
        return null;
    }
  }

  DetailLevel? get lighter {
    switch (this) {
      case DetailLevel.light:
        return null;
      case DetailLevel.medium:
        return DetailLevel.light;
      case DetailLevel.strong:
        return DetailLevel.medium;
    }
  }
}

/// 9Kings modunun kullanıcı seçimleri (kasıtlı olarak az).
class NineKingsProfile {
  const NineKingsProfile({
    this.detail = DetailLevel.medium,
    this.fps = 30,
    this.wholeScreen = false,
  });

  final DetailLevel detail;

  /// 30 (serin) ya da 60 (akıcı).
  final int fps;

  /// Oyun-başına yöntem çalışmazsa kullanılan güçlü yöntem: telefonun tamamı
  /// geçici olarak düşük çözünürlüğe geçer.
  final bool wholeScreen;

  NineKingsProfile copyWith({DetailLevel? detail, int? fps, bool? wholeScreen}) {
    return NineKingsProfile(
      detail: detail ?? this.detail,
      fps: fps ?? this.fps,
      wholeScreen: wholeScreen ?? this.wholeScreen,
    );
  }

  /// Oyun Modu motorunun anladığı yapılandırma. Paket SABİTTİR.
  GameModeConfig toConfig() => GameModeConfig(
        package: kNineKingsPackage,
        targetFps: fps,
        scale: detail.scale,
        method: wholeScreen ? ResolutionMethod.wholeScreen : ResolutionMethod.perGame,
        lockRefreshRate: true,
        killBackground: true,
        autoRevert: true,
        animationsOff: true,
        dnd: true,
        dimScreen: true,
        cpuCap: true,
      );

  Map<String, dynamic> toJson() => {
        'detail': detail.name,
        'fps': fps,
        'wholeScreen': wholeScreen,
      };

  factory NineKingsProfile.fromJson(Map<String, dynamic> json) {
    final name = json['detail'] as String?;
    final detail = DetailLevel.values.firstWhere(
      (d) => d.name == name,
      orElse: () => DetailLevel.medium,
    );
    final fps = (json['fps'] as num?)?.toInt() ?? 30;
    return NineKingsProfile(
      detail: detail,
      fps: fps == 60 ? 60 : 30,
      wholeScreen: json['wholeScreen'] as bool? ?? false,
    );
  }

  static NineKingsProfile decode(String raw) {
    if (raw.isEmpty) return const NineKingsProfile();
    try {
      return NineKingsProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const NineKingsProfile();
    }
  }

  String encode() => jsonEncode(toJson());
}

/// Bir sonraki oturum için ayrıntı önerisi.
class DetailSuggestion {
  const DetailSuggestion(this.level, this.reason);
  final DetailLevel level;
  final String reason;
}

/// Son oturumun ölçümüne bakarak ayrıntı kademesi önerir; veri yetersizse
/// ya da değişiklik gerekmiyorsa `null`.
///
/// - Isındıysa (ısıl durum ≥ 2 ya da ısı koruması devreye girdiyse) bir kademe
///   daha bulanık.
/// - Isınmadıysa ve hedef FPS'e ulaşıldıysa bir kademe daha net.
DetailSuggestion? suggestDetail(SessionStats? stats, NineKingsProfile profile) {
  if (stats == null || stats.avgFps == null || stats.samples < 3) return null;
  final hot = (stats.maxThermal ?? 0) >= 2 || stats.guardTriggered;
  if (hot) {
    final next = profile.detail.stronger;
    if (next == null) return null;
    return DetailSuggestion(
      next,
      'Son oyunda telefon ısındı. Bir kademe daha bulanık denemek ısıyı düşürür.',
    );
  }
  if (stats.avgFps! >= profile.fps * 0.9) {
    final next = profile.detail.lighter;
    if (next == null) return null;
    return DetailSuggestion(
      next,
      'Son oyunda ısınma olmadı ve hedef FPS tutuldu. Bir kademe daha net görüntü deneyebilirsiniz.',
    );
  }
  return null;
}

/// Oyun içinde yapılabilecekler (cihaz ayarı değil; kullanıcıya öneri).
const List<String> kNineKingsTips = [
  'Ağır savaşlarda sağ üstteki hızlandırma (>>) ve auto düğmelerini kapatın: oyun aynı anda '
      'çok daha fazla hesap yapar, CPU ve ısı artar.',
  'Savaş bitince duraklatıp (⏸) telefonu 1–2 dakika dinlendirmek ısıl kısıtlamayı kaldırır.',
  'Şarj olurken oynamayın; şarj ısısı üstüne biner.',
  'Kılıfı çıkarın ya da telefonu sert, soğuk bir yüzeye koyun.',
];
