import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Dosya paylaşma, yazdırma ve dosya seçme işlemleri.
///
/// Mobilde sistem paylaşım menüsü açılır (WhatsApp, e-posta, Drive, Dosyalar…);
/// web'de dosya indirilir.
class ShareService {
  /// Dosya adında kullanılacak tarih: 2026-10-29.
  static String stamp([DateTime? d]) {
    final t = d ?? DateTime.now();
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  /// Dosya adı için güvenli metin: "Akdeniz Lojistik A.Ş." → "Akdeniz_Lojistik_A.S."
  static String safeName(String s) {
    const map = {'ç': 'c', 'Ç': 'C', 'ğ': 'g', 'Ğ': 'G', 'ı': 'i', 'İ': 'I', 'ö': 'o', 'Ö': 'O', 'ş': 's', 'Ş': 'S', 'ü': 'u', 'Ü': 'U'};
    final b = StringBuffer();
    for (final ch in s.characters) {
      b.write(map[ch] ?? ch);
    }
    return b.toString().replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_').replaceAll(RegExp(r'_+'), '_');
  }

  static Future<void> shareBytes(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
    String? subject,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
        fileNameOverrides: [fileName],
        subject: subject,
        title: subject,
      ),
    );
  }

  /// CSV dosyası paylaşır. Excel'in Türkçe karakterleri doğru açması için
  /// UTF-8 BOM eklenir.
  static Future<void> shareCsv(String csv, String fileName, {String? subject}) => shareBytes(
    Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]),
    fileName: fileName,
    mimeType: 'text/csv',
    subject: subject,
  );

  static Future<void> shareJson(String json, String fileName) => shareBytes(
    Uint8List.fromList(utf8.encode(json)),
    fileName: fileName,
    mimeType: 'application/json',
    subject: 'Finans yedeği',
  );

  static Future<void> sharePdf(Uint8List bytes, String fileName) =>
      Printing.sharePdf(bytes: bytes, filename: fileName);

  /// Yazdırma / PDF önizleme penceresi.
  static Future<void> printPdf(Future<Uint8List> Function() build, String name) =>
      Printing.layoutPdf(onLayout: (PdfPageFormat _) => build(), name: name);

  /// Kullanıcıya bir JSON dosyası seçtirir ve içeriğini döndürür.
  static Future<String?> pickJsonFile() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (files.isEmpty) return null;
    return utf8.decode(await files.first.readAsBytes());
  }
}

extension on String {
  Iterable<String> get characters => runes.map(String.fromCharCode);
}
