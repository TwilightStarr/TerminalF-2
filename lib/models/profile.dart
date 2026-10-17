import 'package:flutter/material.dart';

/// Tek dokunuşla uygulanan hazır optimizasyon paketi. Her profil,
/// `assets/config/tweaks.json` içindeki tweak kimliklerinden oluşur.
class OptimizationProfile {
  const OptimizationProfile({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.tweakIds,
    this.reversible = true,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<String> tweakIds;

  /// `false` ise profil tek seferlik eylemlerden oluşur (geri alınacak bir şey yok).
  final bool reversible;
}

const List<OptimizationProfile> kProfiles = [
  OptimizationProfile(
    id: 'performance',
    title: 'Performans',
    description: 'Animasyonları kapatır, GPU ve yüksek yenileme hızını zorlar, arka planı temizler.',
    icon: Icons.bolt_rounded,
    tweakIds: [
      'performance_disable_animations',
      'performance_force_gpu_rendering',
      'performance_disable_adaptive_battery',
      'performance_force_peak_refresh_rate',
      'performance_kill_background',
    ],
  ),
  OptimizationProfile(
    id: 'battery',
    title: 'Pil Tasarrufu',
    description: 'Yenileme hızını 60 Hz\'e sabitler, pil tasarrufu modunu ve arka plan taramasını kısar.',
    icon: Icons.battery_saver_rounded,
    tweakIds: [
      'performance_cap_refresh_rate_battery',
      'battery_saver_mode',
      'privacy_disable_always_scanning',
    ],
  ),
  OptimizationProfile(
    id: 'privacy',
    title: 'Gizlilik',
    description: 'Reklam takibini ve otomatik hata raporlarını kapatır.',
    icon: Icons.shield_moon_rounded,
    tweakIds: [
      'privacy_limit_ad_tracking',
      'privacy_disable_error_reports',
      'privacy_disable_always_scanning',
    ],
  ),
  OptimizationProfile(
    id: 'cleanup',
    title: 'Temizlik',
    description: 'Önbellekleri ve arka plan uygulamalarını temizler, gereksiz Google/yazdırma bileşenlerini kapatır.',
    icon: Icons.cleaning_services_rounded,
    reversible: false,
    tweakIds: [
      'cleanup_trim_caches',
      'performance_kill_background',
      'debloat_google_feedback',
      'debloat_onetime_initializer',
      'debloat_print_recommendation',
    ],
  ),
];

OptimizationProfile? profileById(String id) {
  for (final p in kProfiles) {
    if (p.id == id) return p;
  }
  return null;
}
