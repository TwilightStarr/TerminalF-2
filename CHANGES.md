# Genel Oyun Modu geri geldi + ayrı 9Kings modu

- **Genel Oyun Modu** eski haline döndü (paket adı düzenleme, kare hızı, çözünürlük, anahtarlar, hazır ayarlar Serin/Akıcı). Gelişmiş bölümü artık kapalı değil.
- **9Kings** (sayfanın en üstünde, ayrı kart): tek tuşla oyunu açar ve yalnızca 9Kings'e özeldir (paket sabit).
  - **Görüntü ayrıntısı:** Hafif / Orta / Çok bulanık (%70 / %50 / %40 çözünürlük). Piksel sanatta bulanıklık az fark edilir, ısı belirgin düşer.
  - **Kare hızı:** Serin 30 ya da Akıcı 60 FPS.
  - **Güçlü yöntem:** oyun-başına küçültme işe yaramazsa tüm ekranı geçici küçültür.
  - Hep açık: ekran 60 Hz kilidi, parlaklık kısma, animasyon/bildirim kısma, arka plan temizliği, işlemci sınırı (root), ısı koruması, otomatik geri alma.
  - **Akıllı öneri:** son 9Kings oturumunda ısındıysanız (ya da ısı koruması devreye girdiyse) bir kademe daha bulanık; ısınmadıysanız ve hedef FPS tutulduysa bir kademe daha net önerir. Tek dokunuşla uygulanır.
  - **Oyun içi ipuçları:** hızlandırma/auto düğmeleri, mola, şarj, kılıf.
- İki mod aynı anda açık olamaz; birini başlatmak önce diğerinin değişikliklerini geri alır. Oturum hangi modun başlattığını kaydeder.
- Yeni testler: `test/nine_kings_test.dart` ve `game_mode_controller_test.dart` içinde 9Kings grubu. Dart kodu bu ortamda derlenemedi.

---

# 9Kings Modu (ana mod) ve ısı önlemleri

- Oyun sekmesinin tepesinde tek **9Kings Modu** kartı: 30 FPS, %50 çözünürlük, ekran 60 Hz, parlaklık kısık, animasyonlar kapalı, bildirimler sessiz, ısı koruması. Diğer her şey "Gelişmiş ayarlar" altında.
- **Ekran parlaklığını kıs:** oyun boyunca mevcut parlaklığın %60'ı (özgün değer + otomatik parlaklık modu kaydedilir, geri alınır).
- **İşlemci hızını sınırla (yalnızca root):** en güçlü iki küme `scaling_max_freq` %70; özgün değerler kaydedilir ve geri yazılır. Shizuku ile yapılamaz; yapılamadığı sonuç listesinde dürüstçe yazar.
- **Isı koruması:** izleyici, ısıl durum art arda iki örnekte "Orta" ya da üstüyse bir kez daha sıkılaştırır (işlemci %55, parlaklık özgün değerin %35'i). Rapor "Isı koruması devreye girdi" der.
- 30 FPS hedefinde ekran artık 60 Hz'e kilitlenir (önceden kilitlenmiyordu).
- Yeni testler: parlaklık, işlemci sınırı, geri alma, bozuk kayıt reddi, ısı koruması, izleyici betiği. Betik yerel `sh` ile ısı koruması dahil sahte komutlarla çalıştırıldı; Dart kodu derlenemedi.

---

# Oyun Modu sadeleştirme

- Sayfada tek karar: **Serin (önerilen)** ya da **Akıcı**. Diğer tüm ayarlar "Gelişmiş ayarlar" altında kapalı durur.
- Paket adı düzenleme kaldırıldı; arayüzdeki oyun adı geçen metinler silindi.
- İlk açılışta Serin modu otomatik seçilir. "En yüksek akıcılık" ön ayarı kaldırıldı (gelişmiş ayarlardan 90 FPS yine seçilebilir).

---

# Oyun Modu 2 — ölçüm, teşhis ve otomatik geri alma

- **Cihazda izleyici:** Oyun Modu açılınca telefonda küçük bir betik başlar (Terminal kapansa da çalışır). Oyun ön plandayken 10 sn'de bir **gerçek FPS** (SurfaceFlinger kare zamanları), **ısıl durum** ve **büyük çekirdek hızını** kaydeder; oyun ~40 sn ön planda olmazsa tüm ayarları **kendiliğinden geri alır**. Geri alma başarılıysa/başarısızsa işaret dosyasına yazar; Terminal açılınca okunur (başarısızsa oturum saklanır, "Geri Al" kalır).
- **Son oyun oturumu raporu:** süre, ortalama/en düşük FPS, en yüksek ısıl durum, büyük çekirdek hızı ve **olası darboğaz teşhisi** (ısıl kısıtlama / işlemci sınırlı / GPU-bekleme). Teşhis sezgiseldir ve "olası" der; okunamayan değer "okunamadı" yazar.
- **Hazır ayarlar:** Serin ve uzun pil (30 FPS, %50), Dengeli (60 FPS, %60), En yüksek akıcılık (90 FPS, %75).
- **Yeni seçenekler (hepsi eski değer kaydedilip geri alınır):** sistem animasyonlarını kapat, bildirimleri sustur (Rahatsız Etme), oyun kapanınca otomatik geri al.
- **Ön plan algılama denetimi:** Durum kartı, `dumpsys window` çıktısının bu cihazda okunabildiğini gösterir.
- Güvenlik: betiğe yalnızca doğrulanmış paket adı ve doğrulanmış eski değerler girer; sonlandırmadan önce PID'in gerçekten izleyici olduğu doğrulanır; oyun hiç ön plana gelmezse izleyici GERİ ALMADAN çıkar (ön plan algılanamıyorsa mod oyun sırasında kendiliğinden kapanmasın).
- Yeni bağımlılık YOK (`pubspec.yaml` değişmedi). Yeni testler: `test/game_probe_test.dart`, `test/game_watchdog_test.dart`; `game_mode_test.dart` ve `game_mode_controller_test.dart` genişletildi.
- Doğrulama notu: Flutter SDK bu ortamda yok; Dart kodu `flutter analyze/test` ile ÇALIŞTIRILAMADI. İzleyici betiği ise gerçek bir `sh` ile sahte Android komutları kullanılarak çalıştırıldı (örnekleme, geri alma, "hiç görülmedi" ve "geri alma başarısız" yolları). İlk CI çıktısına bakın.

---

# Oyun Modu

- Yeni **Oyun** sekmesi (varsayılan oyun: 9Kings, `com.playdigious.ninekings`; paket adı değiştirilebilir).
- Kare hızı üst sınırı (30/60/90), oyun çözünürlüğü (Tam/%75/%60/%50), ekranı 60/90 Hz'e kilitleme, arka plan temizliği.
- Çözünürlük iki yolla: **Yalnız oyun** (Android GameManager, `cmd game set`) ve **Tüm ekran** (`wm size` + `wm density`).
- Güvenlik: değişiklikten ÖNCE eski değerler diske yazılır; **Geri Al** her şeyi eski haline getirir (uygulama kapansa bile). Geri alma başarısızsa kayıt silinmez, tekrar denenebilir.
- Dürüst raporlama: cihazın desteklemediği adımlar "desteklenmiyor" diye işaretlenir, başarı uydurulmaz. Etkin ekran Hz'i okunup gösterilir.
- Yeni testler: `test/game_mode_test.dart`, `test/game_mode_controller_test.dart`.

---

# Görünüm güncellemesi

- Yeni **Görünüm** sayfası (Cihaz > Ayarlar > Görünüm): 18 hazır tema. Koyu: Siyah & Beyaz, Neon Turkuaz, Okyanus, Gün Batımı, Orman, Mor, Kızıl, Altın, Buz, Gül, Nord, Drakula, Matrix. Açık: Beyaz & Siyah, Gökyüzü, Nane, Krem, Lavanta.
- **Animasyonlar:** sekme geçişi, ana sayfa kartlarının kademeli belirmesi, tema değişiminde yumuşak geçiş, seçim efektleri. Görünüm sayfasındaki anahtarla kapatılır; sistemin "animasyonları kaldır" ayarına da uyar.
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
