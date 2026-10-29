# Finans — Gelir / Gider ve Nakit Akışı Yönetimi

Gelirleri, giderleri, banka hesaplarını, cari hesapları, yaklaşan ödeme ve tahsilatları tek yerden
yöneten; finansal rapor üreten ve nakit akışını anlık izleyen **Android, iOS ve web** uygulaması (Flutter).
Telefon, tablet ve masaüstü tarayıcı uyumludur; açık / koyu tema destekler.

## Özellikler

| Alan | Ayrıntı |
|---|---|
| **Özet** | Toplam nakit varlık, bu ayın gelir/gider/net sonucu, carilerden alacak ve carilere borç, 30 günlük beklenen tahsilat/ödeme, gecikmiş kalem ve **nakit açığı riski** uyarıları, son 30 gün + 60 günlük tahmini nakit akışı grafiği, hesap kartları, yaklaşan kalemler, son işlemler |
| **İşlemler** | Gelir, gider ve hesaplar arası transfer. Ay ay gezinme, tür / hesap filtresi, metin arama, güne göre gruplama ve günlük net |
| **Banka & kasa** | Vadesiz hesap, nakit kasa, kredi kartı, birikim/vadeli hesap. IBAN, banka, renk, açılış bakiyesi; işlem geçmişi olan hesap silinmez, arşivlenir |
| **Cari hesaplar** | Müşteri / tedarikçi kartı, vergi no, iletişim. Satış/alış faturası (cari borçlandırma/alacaklandırma), tahsilat/ödeme, **yürüyen bakiyeli cari ekstresi** (CSV kopyalama), fatura vadesine otomatik planlı kalem |
| **Yaklaşan ödeme & tahsilatlar** | Tek seferlik veya haftalık / aylık / 3 aylık / yıllık tekrar, son vade. Gecikmiş / bugün / bu hafta / 30 gün / sonra grupları. "Ödendi / Tahsil edildi" ile tek dokunuşta işleme dönüşür, tekrarlıysa vade ilerler; "Bu vadeyi atla" |
| **Raporlar** | Bu ay, geçen ay, son 3 ay, bu yıl, geçen yıl veya özel tarih aralığı. Gelir, gider, net, tasarruf oranı ve önceki döneme göre değişim; son 12 ay gelir-gider grafiği; gelir ve gider kategori dağılımı; dönem içi bakiye geçmişi; 90 günlük nakit akışı tahmini (en düşük nokta); cari özeti; dönem sonu hesap bakiyeleri. Özet metni veya işlemler CSV olarak panoya kopyalanır |
| **Döviz (USD / EUR)** | Hesap bazında para birimi (₺, $, €). Kurlar **otomatik** çekilir: açılışta (2 saatten eskiyse) ve uygulama açıkken 30 dakikada bir. Döviz işlemlerinde işlem anındaki kur saklanır (elle değiştirilebilir); farklı birimli hesaplar arası transferde karşı tutar kurla hesaplanır. Toplam bakiye, raporlar ve nakit akışı tahmini ₺'ye çevrilir; döviz bakiyelerinin altında ≈ ₺ karşılığı görünür. Kurlar elle de girilebilir |
| **PDF ve paylaşım** | Dönem **PDF finansal raporu** (özet, 12 aylık grafik ve tablo, kategori dağılımı, hesap bakiyeleri, cari özeti, 30 günlük vade listesi, 90 günlük tahmin) ve **PDF cari ekstresi**; paylaş / indir veya yazdır / önizle. İşlemler ve ekstre **CSV dosyası** (Excel uyumlu) olarak paylaşılır. Yedek **JSON dosyası** olarak paylaşılır, **dosyadan geri yüklenir**. Mobilde sistem paylaşım menüsü (WhatsApp, e-posta, Drive…), web'de indirme |
| **Ayarlar** | Sistem / açık / koyu tema, tema rengi, **tutarları gizle**, döviz kurları (güncelle / elle gir), kategori yönetimi (ikon + renk), yedek dosyası / pano ile yedekleme ve geri yükleme, örnek veri, tüm veriyi silme |

### Hesap mantığı

- Tutarlar kuruş cinsinden tam sayı olarak saklanır; toplamalarda yuvarlama hatası olmaz.
- **Hesap bakiyesi** = açılış + gelirler − giderler ± transferler, hesabın kendi para biriminde.
  Toplam bakiye döviz hesaplarını **güncel kurla** ₺'ye çevirir. Arşivlenen hesaplar toplama girmez.
- **Raporlar ve cari bakiyeleri** döviz işlemlerini **işlem tarihindeki kurla** ₺'ye çevirir; böylece
  kur değişse de geçmiş dönem gelir/gider rakamları değişmez.
- **Cari bakiyesi** (pozitif = cari bize borçlu) = açılış + satış faturaları − alış faturaları
  − cariden tahsilatlar + cariye ödemeler. Faturalar kasa/banka bakiyesini değiştirmez.
- **Nakit akışı tahmini**: güncel toplam bakiyeden başlar, planlı kalemlerin (tekrarlar dahil)
  vadelerini günlük olarak uygular. Vadesi geçmiş kalemler bugüne sayılır.
- Aylık tekrarlarda her vade ilk tarihten hesaplanır (31 Ocak → 28 Şubat → 31 Mart).

### Kur kaynakları

Sırayla denenir, ilk başarılı olan kullanılır:

1. **TCMB** günlük kurları (döviz satış) — `tcmb.gov.tr/kurlar/today.xml`. Tarayıcı güvenlik kuralları
   (CORS) nedeniyle yalnızca mobil uygulamada kullanılır.
2. **Frankfurter** — Avrupa Merkez Bankası referans kurları (`api.frankfurter.dev`).
3. **ExchangeRate-API** — `open.er-api.com`.

İnternet yoksa son alınan kur kullanılır; hiç alınmamışsa yaklaşık bir varsayılan kur gösterilir ve
özet ekranındaki kur şeridi kırmızıyla uyarır.

## Proje yapısı

```
lib/
  models/models.dart            Account, Contact, Category, Txn, ContactEntry, PlannedItem (JSON)
  logic/finance_math.dart       Bakiye, cari ekstresi, tekrar/vade, projeksiyon, rapor, tutar ayrıştırma
  logic/currency.dart           Para birimleri, kurlar ve çevirme
  data/
    finance_store.dart          Tek veri kaynağı (ChangeNotifier) + kalıcılık (shared_preferences)
    app_prefs.dart              Tema, tutar gizleme
    default_categories.dart     Varsayılan gelir / gider kategorileri
    demo_data.dart              Son 6 aya yayılmış örnek veri (döviz hesapları dahil)
    rate_service.dart           Otomatik kur çekme (TCMB / Frankfurter / ExchangeRate-API)
  services/
    pdf_reports.dart            PDF finansal rapor ve cari ekstresi
    share_service.dart          Dosya paylaşma, yazdırma, dosya seçme
  ui/
    home_shell.dart             Telefonda alt menü, genişte (≥ 840 px) yan menü
    screens/                    Özet, işlemler, planlı, hesaplar (+detaylar), raporlar, ayarlar
    forms/                      İşlem, planlı kalem, hesap, cari, cari faturası formları
    widgets/                    Ortak bileşenler, grafikler (fl_chart)
test/                           Hesap mantığı, veri deposu ve arayüz testleri
```

## Çalıştırma

Gereken: [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable kanal).

```bash
flutter pub get
flutter run              # bağlı cihaz / emülatör
flutter test             # birim + arayüz testleri
flutter build apk        # Android
flutter build ipa        # iOS (macOS + Xcode gerekir)
```

### Son kullanıcıya dağıtım (kurulumsuz, çift tıkla çalışır)

```bash
./tools/package_web.sh     # Flutter, Go ve zip gerekir
```

`dist/` klasöründe üç paket oluşur: `Finans-Windows.zip`, `Finans-macOS.zip`, `Finans-Linux.zip`.
Her biri web sürümünü içinde taşıyan tek dosyalık bir başlatıcı (`tools/launcher`, Go) ve
`KULLANIM.txt` içerir. Kullanıcı ZIP'i açıp `Finans.exe` (macOS'ta `.command`) dosyasına çift tıklar;
bilgisayarda `http://127.0.0.1:8642` adresinde yerel bir sunucu açılır ve tarayıcı kendiliğinden
gelir. Flutter, Python veya başka bir kurulum gerekmez; kurlar dışında internet de gerekmez.

Veriler tarayıcıda bu adrese bağlı saklandığından port sabittir (8642). Yeni sürümde klasörü
değiştirmek yeterlidir, veriler korunur.

### Web tarayıcıda (geliştirici)

```bash
flutter run -d chrome    # geliştirme: Chrome'da açar (yoksa: flutter run -d web-server)
flutter build web        # yayın: çıktı build/web klasöründe
```

`build/web` klasörü herhangi bir statik barındırmada yayınlanabilir (GitHub Pages, Netlify,
Firebase Hosting, kendi sunucunuz). Yerelde denemek için:

```bash
cd build/web && python3 -m http.server 8080   # http://localhost:8080
```

Alt klasörde yayınlanacaksa (ör. GitHub Pages `https://kullanici.github.io/GelirGiderHesap/`):
`flutter build web --base-href /GelirGiderHesap/`.

Web'de veriler tarayıcının yerel deposunda (localStorage) tutulur; tarayıcı verisi silinirse
kaybolur, düzenli yedek dosyası alın.

İlk açılışta **Örnek veriyle dene** ile tüm ekranlar gerçek veri girmeden denenebilir.

## Notlar / sonraki adımlar

- Veriler yalnızca cihazda saklanır. Cihaz değiştirirken **Ayarlar → Yedeği kopyala** ile alınan
  JSON, yeni cihazda **Yedekten geri yükle** ile içe aktarılır.
- Çok sayıda kayıt (on binlerce işlem) için depolama `sqflite`/`drift` ile değiştirilebilir;
  `FinanceStore` arayüzü aynı kalır.
- Yeni para birimi eklemek için `logic/currency.dart` içindeki `currencyCodes` listesine ve `Rates`
  sınıfına alan eklenir, `rate_service.dart` ayrıştırıcıları genişletilir.
