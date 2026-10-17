# Güvenlik politikası

## Açık bildirme

Bir güvenlik açığı bulduysanız lütfen herkese açık issue **açmayın**. GitHub'da bu deponun **Security > Report a vulnerability** (özel güvenlik bildirimi) özelliğini kullanın.

## Tasarım ilkeleri

- Ağa veri gönderilmez; telemetri yoktur.
- Kabuğa verilen paket adları doğrulanır (komut enjeksiyonu engeli).
- Sistem için kritik paketler ve uygulamanın kendisi dondurulamaz/kaldırılamaz.
- Yetki (root/Shizuku) kullanıcı tarafından açıkça verilir; hazır olma gerçek bir komutla doğrulanır.
