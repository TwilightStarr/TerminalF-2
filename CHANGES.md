# Görünüm güncellemesi

- Yeni **Görünüm** sayfası (Cihaz > Ayarlar > Görünüm): 7 hazır tema (Siyah & Beyaz, Beyaz & Siyah, Neon Turkuaz, Okyanus, Gün Batımı, Orman, Mor).
- **Varsayılan tema artık siyah-beyaz**; karşılama ekranı ve logo da buna uyar. Eski turkuaz görünüm "Neon Turkuaz" olarak duruyor.
- **Logo rengi** değiştirilebilir: tema rengi, 11 düz/gradyan hazır renk veya ton + açıklık çubuklarıyla özel renk. Ana ekran, Cihaz sayfası ve karşılamadaki logo birlikte değişir.
- Seçimler kaydedilir ve uygulama açılırken ilk kareden itibaren uygulanır.
- Teknik: `AppColors` artık sabit (const) değil, seçili palette bağlı; tema değişince arayüz durumu bozulmadan yeniden çizilir. Yeni testler: `test/appearance_test.dart`.

---

# CHANGES — 0.2.0

## Verim
- Her saniye **tüm ekranı** yeniden çizen döngü kaldırıldı. Ölçümler `LiveStats` ile 4 sn'de bir okunur, yalnızca ilgili parçalar çizilir, uygulama arka plandayken **durur**.
- Okumalar üst üste binmez; sayfalar ilk açılışta oluşturulur ve bellekte tutulur (uygulama listesi her sekme geçişinde yeniden taranmaz).
- Uygulama listesi `itemExtent` ile sanallaştırıldı, ikonlar küçük çözünürlükte çözülür.
- Gereksiz bileşenler silindi: FPS sayacı/grafiği, uygulamanın kendi RSS'i, 2. tema, `http` bağımlılığı, kopya dosyalar (`services/`, `tabs/` kök klasörleri).

## Kullanıcının gördüğü
- Uygulamanın kendi RSS'i yerine **gerçek** cihaz RAM'i (`/proc/meminfo`), **gerçek** depolama (`df`) ve açık kalma süresi.
- Cihaz sağlığı puanı ve duruma göre öneriler (bellek dolu, depolama dolmak üzere, pil azalıyor, cihaz ısınıyor).
- Tek dokunuşla *Akıllı Optimizasyon*, *Hızlandır*, *Önbellek Temizle*.

## Yönetim
- `ControlController`: root/Shizuku seçimi otomatik, "hazır" durumu gerçek komutla doğrulanır, tweak durumu cihazdan okunur, değişmeyen ayar başarı sayılmaz.
- 4 hazır profil, 3 yeni ayar (pil tasarrufu modu, tüm önbellekleri temizle, arka plan dexopt).
- Uygulama başına gerçek *Zorla Durdur*, *Önbellek Temizle*, *Dondur*, *Kaldır*; dondurulmuşları geri açma.
- Güvenlik: paket adları kabuğa verilmeden doğrulanır (komut enjeksiyonu engeli); sistem için kritik paketler ve uygulamanın kendisi dondurulamaz/kaldırılamaz.

## Arayüz
- Eski monospace "terminal" görünümü ve 2 tema kaldırıldı; tek, sade, koyu tasarım (`core/theme.dart`).
- Alt gezinme çubuğu: Ana Sayfa · Optimize · Uygulamalar · Cihaz. İşlem günlüğü ayrı alt sayfada.
- Yeni logo ve Android ikonları (uyarlanabilir + tek renkli).

## Doğrulama durumu (dürüstlük notu)
Bu ortamda Flutter/Dart SDK'sı yok; kod `flutter analyze/test/build` ile **çalıştırılamadı**. Yapılanlar: import/parantez denetimi, API kullanımının önceki derlenen koddaki desenlerle birebir tutulması, testlerin elle yazılması. İlk CI çalışmasında *Statik analiz* ve *Testler* adımlarının çıktısına bakın (hata verirse APK üretimini engellemez, log'da görünür).

---

# 0.2.1 — Temizlik ve yayına hazırlık

- `flutter analyze` hataları giderildi: depoya yanlışlıkla geri karışan eski dosyalar (`lib/screens/`, `lib/tabs/`, `lib/core/theme/`, kök `services/` ve `tabs/`, kullanılmayan eski widget'lar, `winutil_service`, `memory_service`, `fps_counter` + testi) silindi. 0.2.0 mimarisi (`pages/`, `state/`, `core/theme.dart`) tek kaynak oldu.
- Kalan lint bilgileri giderildi (`library;` yönergeleri, gereksiz import, gereksiz `${}`).
- Bayat dokümantasyon referansları güncellendi.
- README'ye logo, rozetler, güvenlik/lisans bölümleri eklendi; `LICENSE` (MIT), `CONTRIBUTING.md`, `SECURITY.md`, issue/PR şablonları, Dependabot eklendi.
- CI: analiz artık hatada derlemeyi durdurur; PR'lar için `ci.yml`.
- **Otomatik sürüm ve Release:** `main`'e her push yeni sürüm etiketi + GitHub Release üretir. Numaralandırma **2.0.0**'dan başlar; `[minor]`/`[major]` commit etiketleriyle büyütülür.

## Yeni logo, bildirimler ve kullanım kolaylıkları
- **Yeni logo:** F harfi ve halka kaldırıldı; komut istemi (`>`) + imleç işaretine dayanan sade, modern bir marka. Tüm ikonlar (uyarlanabilir, tek renkli, yuvarlak), SVG, uygulama içi logo ve README görselleri yeniden üretildi. Durum çubuğu için ayrı tek renk bildirim ikonu eklendi.
- **Bildirimler** (`flutter_local_notifications`): işlem sonucu bildirimi (arka planda) ve sağlık uyarıları (ısınma, düşük pil, dolu depolama, yüksek RAM). Eşikler ayarlanabilir, histerezisli (tekrar eden bildirim yok), `lib/utils/alert_rules.dart` birim testli.
- **Ayarlar sayfası:** Cihaz > Bildirimler ve Uyarılar (izin durumu, anahtarlar, eşik kaydırıcıları, test bildirimi, titreşim).
- **İlk açılış karşılaması** ve bağlamlı bildirim izni.
- **Geri tuşu** önce Ana Sayfa'ya döner; sekme geçişi ve işlem sonuçlarında **dokunsal geri bildirim**.
- Sürüm numarası artık gerçek uygulama sürümünden okunur (`package_info_plus`).
- Beklenmeyen hatalar uygulamayı çökertmez, yalnızca yerelde günlüğe yazılır.
- **Android/CI:** gereksiz `INTERNET` izni kaldırıldı; `allowBackup=false`; öngörülü geri hareketi; https bağlantıları için `queries`; bildirim eklentisi için core library desugaring; isteğe bağlı kalıcı imza (GitHub Secrets); Gradle/manifest doğrulama adımları.
