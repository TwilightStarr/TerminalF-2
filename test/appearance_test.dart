import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terminal_flutter/core/theme.dart';
import 'package:terminal_flutter/state/app_settings.dart';
import 'package:terminal_flutter/utils/motion.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppColors.apply(palette: AppPalettes.monoDark, logo: LogoStyle.auto);
  });

  test('Varsayılan tema siyah-beyaz, logo tema renklerini izler', () async {
    final s = AppSettings();
    await s.load();
    expect(s.themeId, 'mono_dark');
    expect(AppColors.palette.id, 'mono_dark');
    expect(AppColors.bg, const Color(0xFF000000));
    expect(AppColors.primary, const Color(0xFFFFFFFF));
    expect(AppColors.logoStyle.id, LogoStyle.autoId);
  });

  test('Tema ve logo rengi kaydedilir, yeniden açılışta geri yüklenir', () async {
    final s = AppSettings();
    await s.load();
    await s.setTheme('violet');
    await s.setLogo('red');
    expect(AppColors.palette.id, 'violet');
    expect(AppColors.logoColors.first, const Color(0xFFFF5C5C));

    AppColors.apply(palette: AppPalettes.monoDark, logo: LogoStyle.auto);
    final again = AppSettings();
    await again.load();
    expect(again.themeId, 'violet');
    expect(again.logoId, 'red');
    expect(AppColors.palette.id, 'violet');
  });

  test('Özel logo rengi seçilir ve bilinmeyen tema kimliği varsayılana düşer', () async {
    final s = AppSettings();
    await s.load();
    await s.setLogoCustom(const Color(0xFF123456));
    expect(s.logoId, LogoStyle.customId);
    expect(AppColors.logoColors.first, const Color(0xFF123456));

    await s.setTheme('yok_boyle_bir_tema');
    expect(s.themeId, AppPalettes.defaultId);
  });

  test('Animasyonlar varsayılan açık, kapatma kaydedilir', () async {
    final s = AppSettings();
    await s.load();
    expect(s.animations, isTrue);
    await s.setAnimations(false);
    expect(Motion.enabled, isFalse);

    final again = AppSettings();
    await again.load();
    expect(again.animations, isFalse);
    await again.setAnimations(true);
  });

  test('Tüm temaların kimliği benzersiz, en az 15 tema var', () {
    final ids = AppPalettes.all.map((p) => p.id).toSet();
    expect(ids.length, AppPalettes.all.length);
    expect(AppPalettes.all.length, greaterThanOrEqualTo(15));
  });
}
