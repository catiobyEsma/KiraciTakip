# Kiracı Ödeme Takip Sistemi (Flutter — Masaüstü)

Ekran görüntülerindeki tasarımın birebir + geliştirilmiş bir Flutter masaüstü
uygulaması. Tüm veriler (kiracılar, ödeme takvimi, yapılan ödemeler,
dekont fotoğrafları) **tamamen cihazınızın yerel hafızasında** saklanır;
hiçbir veri internete/buluta gönderilmez.

## Özellikler

- **Takvim**: Ödenmesi gereken ve ödenen günleri işaretler; bir güne
  tıklayınca "kiracı ismi, hangi tarihte ödedi, ne kadar attı, ne kadar
  atması gerektiği" bilgisini gösterir.
- **Kiracı Oluştur**: Ad-soyad, sözleşme başlangıç/bitiş tarihi, aylık kira,
  ödeme günü, telefon, adres, notlar. Kaydedildiğinde aylık ödeme takvimi
  (Yapılması Gereken Ödemeler) otomatik oluşturulur.
- **Kiracı Sorgula**: Dropdown'dan kiracı seçilir; "Yeni Ödeme Gir",
  "Kayıtlar / Ödeme Durumu", "Ödemeleri Düzenle", "Kiracıyı Düzenle",
  "Kiracıyı Sil" işlemleri yapılabilir.
- **Kiracı Detay Ekranı**: Sorgulama yapılacak tarih aralığı seçilebilir;
  Yapılması Gereken Ödemeler / Yapılan Ödemeler yan yana listelenir,
  her satır için Ödendi / Kısmen Ödendi / Ödeme bilgisi bulunamadı
  durumu ve kalan borç gösterilir. Altta toplam yapılan ödeme, toplam
  yapılması gereken ödeme ve kalan borç özeti bulunur.
- **Ödemeleri Düzenle**: Ekran görüntüsündeki gibi elle satır ekleme/silme/
  kaydetme tablosu (Ödemesi Gereken Tutar / Tarih / Açıklama).
- **Dekont Ekle**: Kiracı seçip cihazdan fotoğraf veya PDF seçilir, dosya
  uygulamanın kalıcı klasörüne kopyalanır ve kiracıyla ilişkilendirilir.
- **Dekontları Görüntüle**: Kiracı seçilince o kiracıya ait tüm dekontlar
  galeri (thumbnail) görünümünde listelenir; büyütülebilir, PDF ise
  sistemin varsayılan görüntüleyicisiyle açılabilir, silinebilir.
- Tüm veriler yerel **SQLite** veritabanında (`sqflite_common_ffi`) tutulur.

## Kurulum ve Çalıştırma

Bu proje kaynak kodu olarak teslim edilmiştir; platforma özgü klasörler
(`windows/`, `macos/`, `linux/`) Flutter tarafından otomatik üretilir.

1. [Flutter SDK](https://docs.flutter.dev/get-started/install)'ı kurun
   (masaüstü desteğini etkinleştirin: `flutter config --enable-windows-desktop`,
   `--enable-macos-desktop` veya `--enable-linux-desktop`).
2. Proje klasörüne girin:
   ```bash
   cd kiraci_takip
   ```
3. Platform klasörlerini oluşturun (bu proje sadece `lib/` ve
   `pubspec.yaml` içerir; `flutter create .` mevcut dosyaları koruyarak
   eksik platform klasörlerini ekler):
   ```bash
   flutter create .
   ```
4. Paketleri indirin:
   ```bash
   flutter pub get
   ```
5. Çalıştırın (işletim sisteminize göre):
   ```bash
   flutter run -d windows
   flutter run -d macos
   flutter run -d linux
   ```
6. Dağıtılabilir masaüstü uygulaması oluşturmak için:
   ```bash
   flutter build windows   # veya macos / linux
   ```

## ⚠️ Dekont (fotoğraf/PDF) ekleme sorunu — macOS

macOS'ta "Dekont Ekle" ile dosya seçerken hata alıyorsanız veya seçim
penceresi bir şey yapmıyorsa, sebebi neredeyse her zaman şudur: macOS
uygulamaları varsayılan olarak **App Sandbox** içinde çalışır ve kullanıcının
seçtiği dosyalara erişebilmek için özel bir izin (entitlement) gerekir.
`flutter create .` komutu bu izni otomatik eklemez, elle eklemeniz gerekir:

1. Proje klasöründe `macos/Runner/DebugProfile.entitlements` ve
   `macos/Runner/Release.entitlements` dosyalarını bir metin editörüyle açın.
2. Her ikisine de, `</dict>` kapanışından hemen önce şu satırları ekleyin:
   ```xml
   <key>com.apple.security.files.user-selected.read-only</key>
   <true/>
   ```
3. Dosyayı kaydedin ve uygulamayı tamamen kapatıp `flutter run -d macos`
   ile yeniden başlatın (hot reload yetmez, uygulamayı yeniden başlatın).

Alternatif (daha basit ama sandbox korumasını tamamen kapatır — bu App
Store'a yüklenmeyecek özel/şirket içi bir araç olduğu için genellikle
sorun teşkil etmez): aynı iki dosyada
```xml
<key>com.apple.security.app-sandbox</key>
<true/>
```
satırındaki `true` değerini `false` yapabilirsiniz. Bu durumda entitlement
eklemenize gerek kalmaz.

Bu düzeltmeden sonra "Fotoğraf Seç" / "PDF Seç" düğmeleri normal şekilde
çalışmalı ve seçilen dosya kalıcı olarak kopyalanmalıdır.

## Veri Konumu

- Veritabanı ve dekont dosyaları, işletim sisteminin uygulama verileri
  klasöründeki `KiraciTakip` alt klasöründe saklanır (Windows'ta
  `%APPDATA%\...`, macOS'ta `~/Library/Application Support/...`,
  Linux'ta `~/.local/share/...` benzeri konumlar — `path_provider`
  paketi tarafından otomatik yönetilir).
- Uygulamayı kaldırsanız bile bu klasörü elle silmediğiniz sürece
  verileriniz kalır; yedeklemek isterseniz bu klasörü kopyalamanız
  yeterlidir.

## Klasör Yapısı

```
lib/
  main.dart
  models/          -> Tenant, DuePayment, PaymentRecord, Receipt
  db/              -> DatabaseHelper (SQLite CRUD)
  utils/           -> para/tarih formatlama, ödeme hesaplama mantığı
  widgets/         -> CalendarPanel
  screens/         -> HomeScreen, TenantFormScreen, TenantDetailScreen,
                       EditDuePaymentsScreen, AddPaymentDialog,
                       ReceiptsAddScreen, ReceiptsViewScreen
```
