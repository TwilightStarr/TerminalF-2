# Katkı rehberi

Katkılarınız için teşekkürler!

## Geliştirme ortamı

```bash
flutter pub get
flutter create . --platforms=android --project-name terminal_flutter --org com.example   # android/ yoksa
cp -r branding/android/res/. android/app/src/main/res/                                     # logo
flutter analyze
flutter test
flutter run
```

Manifest izinleri ve `minSdk 24` ayarı CI iş akışında (`.github/workflows/build.yml`) otomatik eklenir; yerelde elle eklemeniz gerekir (bkz. README).

Logoyu değiştirmek için `branding/generate_logo.py` dosyasını düzenleyip `pip install pillow && python3 branding/generate_logo.py` çalıştırın; SVG, Android ikonları, bildirim ikonu ve `docs/` görselleri yeniden üretilir. Uygulama içi logo `lib/widgets/app_logo.dart` içinde aynı geometriyle çizilir.

## Kurallar

- Tek tırnak kullanın (`prefer_single_quotes`); `flutter analyze` hatasız olmalı.
- Saf mantığı (`lib/utils/`) platformdan bağımsız tutun ve test yazın.
- Kabuğa giden her paket adı `package_safety.dart` ve `shell_utils.dart` üzerinden doğrulanmalıdır; ham string birleştirmeyin.
- Arayüz, işlem gerçekten başarılı olmadıkça başarı göstermemelidir.
- Yeni ayar: `assets/config/tweaks.json`'a kayıt ekleyin (geri alma ve kontrol komutu ile), profile eklemek için `lib/models/profile.dart`.

## Sürümleme

`main`'e her birleştirmede CI sürümü otomatik artırır ve Release yayınlar (ilk sürüm 2.0.0). Commit mesajında `[minor]` ya da `[major]` yazarak daha büyük artış isteyebilirsiniz. `pubspec.yaml` içindeki `version` yalnızca yerel geliştirme içindir; CI APK'yı hesaplanan sürümle derler.

## Pull request

Küçük, tek amaçlı PR'lar tercih edilir. Şablondaki kontrol listesini doldurun.
