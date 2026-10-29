# Finans — Gelir / Gider ve Nakit Akışı Yönetimi

Gelirleri, giderleri, banka hesaplarını, cari hesapları, yaklaşan ödeme ve tahsilatları tek yerden
yöneten; finansal rapor üreten ve nakit akışını anlık izleyen **Android ve iOS** uygulaması (Flutter).
Telefon ve tablet uyumludur; açık / koyu tema destekler.

## Özellikler

| Alan | Ayrıntı |
|---|---|
| **Özet** | Toplam nakit varlık, bu ayın gelir/gider/net sonucu, carilerden alacak ve carilere borç, 30 günlük beklenen tahsilat/ödeme, gecikmiş kalem ve **nakit açığı riski** uyarıları, son 30 gün + 60 günlük tahmini nakit akışı grafiği, hesap kartları, yaklaşan kalemler, son işlemler |
| **İşlemler** | Gelir, gider ve hesaplar arası transfer. Ay ay gezinme, tür / hesap filtresi, metin arama, güne göre gruplama ve günlük net |
| **Banka & kasa** | Vadesiz hesap, nakit kasa, kredi kartı, birikim/vadeli hesap. IBAN, banka, renk, açılış bakiyesi; işlem geçmişi olan hesap silinmez, arşivlenir |
| **Cari hesaplar** | Müşteri / tedarikçi kartı, vergi no, iletişim. Satış/alış faturası (cari borçlandırma/alacaklandırma), tahsilat/ödeme, **yürüyen bakiyeli cari ekstresi** (CSV kopyalama), fatura vadesine otomatik planlı kalem |
| **Yaklaşan ödeme & tahsilatlar** | Tek seferlik veya haftalık / aylık / 3 aylık / yıllık tekrar, son vade. Gecikmiş / bugün / bu hafta / 30 gün / sonra grupları. "Ödendi / Tahsil edildi" ile tek dokunuşta işleme dönüşür, tekrarlıysa vade ilerler; "Bu vadeyi atla" |
| **Raporlar** | Bu ay, geçen ay, son 3 ay, bu yıl, geçen yıl veya özel tarih aralığı. Gelir, gider, net, tasarruf oranı ve önceki döneme göre değişim; son 12 ay gelir-gider grafiği; gelir ve gider kategori dağılımı; dönem içi bakiye geçmişi; 90 günlük nakit akışı tahmini (en düşük nokta); cari özeti; dönem sonu hesap bakiyeleri. Özet metni veya işlemler CSV olarak panoya kopyalanır |
| **Ayarlar** | Sistem / açık / koyu tema, tema rengi, **tutarları gizle**, kategori yönetimi (ikon + renk), JSON yedek alma / geri yükleme, örnek veri, tüm veriyi silme |

### Hesap mantığı

- Tutarlar kuruş cinsinden tam sayı olarak saklanır; toplamalarda yuvarlama hatası olmaz.
- **Hesap bakiyesi** = açılış + gelirler − giderler ± transferler. Arşivlenen hesaplar toplama girmez.
- **Cari bakiyesi** (pozitif = cari bize borçlu) = açılış + satış faturaları − alış faturaları
  − cariden tahsilatlar + cariye ödemeler. Faturalar kasa/banka bakiyesini değiştirmez.
- **Nakit akışı tahmini**: güncel toplam bakiyeden başlar, planlı kalemlerin (tekrarlar dahil)
  vadelerini günlük olarak uygular. Vadesi geçmiş kalemler bugüne sayılır.
- Aylık tekrarlarda her vade ilk tarihten hesaplanır (31 Ocak → 28 Şubat → 31 Mart).

## Proje yapısı

```
lib/
  models/models.dart            Account, Contact, Category, Txn, ContactEntry, PlannedItem (JSON)
  logic/finance_math.dart       Bakiye, cari ekstresi, tekrar/vade, projeksiyon, rapor, tutar ayrıştırma
  data/
    finance_store.dart          Tek veri kaynağı (ChangeNotifier) + kalıcılık (shared_preferences)
    app_prefs.dart              Tema, tutar gizleme
    default_categories.dart     Varsayılan gelir / gider kategorileri
    demo_data.dart              Son 6 aya yayılmış örnek veri
  ui/
    home_shell.dart             Telefonda alt menü, genişte (≥ 840 px) yan menü
    screens/                    Özet, işlemler, planlı, hesaplar (+detaylar), raporlar, ayarlar
    forms/                      İşlem, planlı kalem, hesap, cari, cari faturası formları
    widgets/                    Ortak bileşenler, grafikler (fl_chart)
test/                           Hesap mantığı, veri deposu ve arayüz testleri
```

## Çalıştırma

```bash
flutter pub get
flutter run              # bağlı cihaz / emülatör
flutter test             # birim + arayüz testleri
flutter build apk        # Android
flutter build ipa        # iOS (macOS + Xcode gerekir)
```

İlk açılışta **Örnek veriyle dene** ile tüm ekranlar gerçek veri girmeden denenebilir.

## Notlar / sonraki adımlar

- Veriler yalnızca cihazda saklanır. Cihaz değiştirirken **Ayarlar → Yedeği kopyala** ile alınan
  JSON, yeni cihazda **Yedekten geri yükle** ile içe aktarılır.
- Tek para birimi (₺) desteklenir. Döviz hesapları için hesap bazında para birimi ve kur eklenebilir.
- Çok sayıda kayıt (on binlerce işlem) için depolama `sqflite`/`drift` ile değiştirilebilir;
  `FinanceStore` arayüzü aynı kalır.
- PDF rapor ve dosya paylaşımı için `pdf` + `share_plus` paketleri eklenebilir.
