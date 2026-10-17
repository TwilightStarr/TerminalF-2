<p align="center">
  <img src="docs/logo.png" alt="TerminalF logosu" width="128" height="128">
</p>

<h1 align="center">TerminalF</h1>

<p align="center">
  Telefonu tek yerden yöneten, karmaşık kısımları kendisi halleden cihaz yönetim merkezi.
</p>

<p align="center">
  <a href="https://github.com/KULLANICI_ADI/TerminalF/actions/workflows/build.yml"><img alt="Build APK" src="https://github.com/KULLANICI_ADI/TerminalF/actions/workflows/build.yml/badge.svg"></a>
  <a href="LICENSE"><img alt="Lisans: MIT" src="https://img.shields.io/badge/lisans-MIT-2de2c0.svg"></a>
  <img alt="Platform: Android" src="https://img.shields.io/badge/platform-Android%207%2B-4d8bff.svg">
  <img alt="Flutter" src="https://img.shields.io/badge/Flutter-stable-02569B.svg?logo=flutter">
</p>

## Ne yapar?

| Sekme | Ne sunar |
|---|---|
| **Ana Sayfa** | Cihaz sağlığı puanı (0-100), "şimdi ne yapmalıyım?" önerileri, **gerçek** RAM / depolama / pil / sıcaklık durumu, tek dokunuşla *Akıllı Optimizasyon*, Hızlandır, Önbellek Temizle |
| **Optimize** | 4 hazır profil (Performans, Pil Tasarrufu, Gizlilik, Temizlik) + tüm ayarlar tek tek. Her ayarın AÇIK/KAPALI durumu cihazdan okunur |
| **Uygulamalar** | Ara, dokun, yönet: Aç · Durdur · Önbellek temizle · Dondur · Kaldır. Dondurulmuş uygulamalar tek yerden geri açılır |
| **Cihaz** | Model, sistem, ekran, IP, parlaklık, ekranı açık tut, izinler, **bildirim ve uyarı ayarları**, sistem kısayolları, önerilen açık kaynak uygulamalar |

## Bildirimler ve kolaylıklar

- **İşlem sonucu bildirimi:** Optimizasyon, Hızlandır, Önbellek Temizle ya da profil uygulaması bitince, uygulama arka plandaysa sonucu bildirir. Ön plandayken sonuç zaten ekranda olduğu için bildirim gönderilmez.
- **Sağlık uyarıları:** Isınma, düşük pil, dolu depolama ve yüksek bellek kullanımı için eşikleri siz belirlersiniz (Cihaz > Bildirimler ve Uyarılar). Her uyarı bir kez gelir; durum düzelmeden tekrar etmez. Ölçümler uygulama çalışırken yapılır; arka planda sürekli çalışan bir servis yoktur (pil dostu).
- **İlk açılış karşılaması:** Kısa tanıtım ve bildirim izni, nedeniyle birlikte istenir.
- **Geri tuşu:** Önce Ana Sayfa'ya döner, orada uygulamadan çıkar.
- **Dokunsal geri bildirim:** Sekme geçişi ve işlem sonuçlarında hafif titreşim (ayarlardan kapatılabilir).
- Hiçbir veri dışarı gönderilmez; uygulama internet izni bile istemez.

## "Tam kontrol" nasıl çalışır?

Android, üçüncü parti uygulamaların sistemi doğrudan yönetmesine izin vermez. TerminalF bu karmaşıklığı kullanıcıdan saklar:

1. Uygulama açılışta **kendisi** bulur: önce root, yoksa Shizuku.
2. Hazır değilse **Tam Kontrolü Etkinleştir** sihirbazı 3 adımı gösterir ve izin penceresini kendisi açar.
3. Hazır olduğu, gerçek bir `id` komutu çalıştırılarak **kanıtlanır**.
4. Bir komut hata verirse ya da cihaz ayarı gerçekten değişmediyse arayüz **başarı göstermez**.

Yetki yokken de çalışanlar: tüm ölçümler, öneriler, uygulama listesi, sistem kısayolları, uygulama önbelleği, sistem "Zorla Durdur/Kaldır" ekranlarına yönlendirme.

## Derleme

Depoya `push` edince `.github/workflows/build.yml` APK üretir (Actions > son çalışma > `app-release-apk`). her `main` push'unda sürüm otomatik hesaplanır (ilk sürüm **v2.0.0**) ve APK **Releases** sayfasına eklenir. Varsayılan olarak yama sürümü artar (2.0.0 → 2.0.1); commit mesajına `[minor]` yazarsanız 2.1.0, `[major]` yazarsanız 3.0.0 olur. Yalnızca `.md`/`docs` değişikliklerinde sürüm çıkmaz. Yerelde:

```bash
flutter pub get
flutter create . --platforms=android --project-name terminal_flutter --org com.example
cp -r branding/android/res/. android/app/src/main/res/   # logo
flutter run
```

Manifest izinleri (VIBRATE, QUERY_ALL_PACKAGES, Shizuku provider vb.) ve `minSdk 24` ayarı CI iş akışında otomatik eklenir.

## Proje yapısı

```
lib/
  app.dart                  # Alt gezinme + sayfaların tembel yüklenmesi
  core/theme.dart           # TEK renk/tema kaynağı
  models/                   # Tweak, Profil
  utils/alert_rules.dart    # uyarı eşikleri (saf, testli)
  services/notification_service.dart  # bildirim katmanı
  pages/                    # home, optimize, apps, device
  state/
    live_stats.dart         # canlı ölçümler (arka planda durur)
    control_controller.dart # root/Shizuku seçimi, tweak/profil/uygulama eylemleri
  services/                 # pil, sistem istatistikleri, root, Shizuku, uygulamalar...
  utils/                    # saf, testli mantık: advisor, parser'lar, shell, paket güvenliği
  widgets/                  # logo, ortak bileşenler, kurulum ve günlük sayfaları
test/                       # advisor, parser, shell, controller vb. birim testleri
assets/config/              # tweaks.json, features.json, applications.json
branding/                   # logo üreticisi + Android ikon kaynakları
```

Yeni bir ayar eklemek için yalnızca `assets/config/tweaks.json`'a bir kayıt ekleyin; bir profile dahil etmek için `lib/models/profile.dart`'taki `tweakIds` listesine kimliğini yazın.

## Logo

`assets/icon/icon.svg` ve `branding/android/res/` aynı geometriden üretilir (`python3 branding/generate_logo.py`). `>` komut istemi, alttaki blok terminal imleci. Gradyan marka renkleridir (turkuaz → mavi). Durum çubuğu bildirim ikonu da aynı işaretten türetilmiştir. Üretmek için `pip install pillow` gerekir; `docs/banner.png` depo için sosyal önizleme görselidir (Settings > Social preview). Android 8+ uyarlanabilir ve Android 13+ tek renkli (themed) ikon dahildir.

## Kalıcı imza (isteğe bağlı)

Varsayılan olarak APK, debug anahtarıyla imzalanır. Güncellemelerin üst üste kurulabilmesi için kendi anahtarınızı kullanmak istiyorsanız depoda **Settings > Secrets and variables > Actions** altına şunları ekleyin; iş akışı otomatik algılar:

| Secret | İçerik |
|---|---|
| `KEYSTORE_BASE64` | `base64 -w0 anahtar.jks` çıktısı |
| `KEYSTORE_PASSWORD` | keystore parolası |
| `KEY_ALIAS` | anahtar takma adı |
| `KEY_PASSWORD` | anahtar parolası |

Anahtar dosyasını **asla** depoya eklemeyin (`.gitignore` zaten `*.jks`/`*.keystore` dosyalarını dışlar).

## Güvenlik ve gizlilik

- Uygulama hiçbir veriyi dışarı göndermez; analiz/telemetri yoktur. Tüm ölçümler cihazda okunur.
- Sistem için kritik paketler (arayüz, telefon, ayarlar vb.) ve uygulamanın kendisi dondurulamaz/kaldırılamaz.
- Paket adları kabuğa verilmeden doğrulanır. Ayrıntı için [SECURITY.md](SECURITY.md).
- Root/Shizuku ile sistem ayarlarını değiştirmek risklidir; ne yaptığınızı bilmiyorsanız profilleri ve açıklamaları okuyun. Yazılım **olduğu gibi**, garanti verilmeden sunulur (bkz. [LICENSE](LICENSE)).

## Katkı

Hata bildirimi ve çekme istekleri (PR) için [CONTRIBUTING.md](CONTRIBUTING.md) dosyasına bakın.

## Lisans

[MIT](LICENSE)
