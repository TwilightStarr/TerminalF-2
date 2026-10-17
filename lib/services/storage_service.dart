import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Tek bir depolama okumasi.
class StorageReading {
  const StorageReading({required this.totalBytes, required this.cacheBytes, required this.path});

  final int totalBytes;

  /// Gecici (temizlenebilir) klasordeki toplam bayt - bkz. [StorageService.clearCache].
  final int cacheBytes;
  final String path;

  static const StorageReading empty = StorageReading(totalBytes: 0, cacheBytes: 0, path: '-');
}

/// Godot'taki `OS.get_user_data_dir()` + `_dir_size_recursive()`
/// ikilisinin Flutter karsiligi. Uygulamanin belge klasorunu bulur ve
/// icindeki tum dosyalarin boyutunu topluyarak toplam kullanim
/// alanini hesaplar. Yalnizca **izlemekle** kalmiyor; [clearCache] ile
/// gercek bir yonetim (temizleme) eylemi de sunuyor.
class StorageService {
  Future<StorageReading> read() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final bytes = await _dirSizeRecursive(dir);

      var cacheBytes = 0;
      try {
        final cacheDir = await getTemporaryDirectory();
        cacheBytes = await _dirSizeRecursive(cacheDir);
      } catch (_) {
        // Gecici klasor okunamazsa 0 olarak birak, toplam okumayi bozma.
      }

      return StorageReading(totalBytes: bytes, cacheBytes: cacheBytes, path: dir.path);
    } catch (_) {
      return StorageReading.empty;
    }
  }

  /// Uygulamanin gecici (temizlenebilir) klasorundeki tum dosya ve alt
  /// klasorleri siler. Kalici uygulama verilerine (belge klasoru,
  /// `shared_preferences` tercihleri) **dokunmaz** - yalnizca yeniden
  /// uretilebilir onbellek verisi kaldirilir. Silinen toplam bayt
  /// miktarini dondurur, boylece cagiran taraf kullaniciya "X MB
  /// temizlendi" gibi somut bir sonuc gosterebilir.
  Future<int> clearCache() async {
    var freed = 0;
    try {
      final cacheDir = await getTemporaryDirectory();
      await for (final entity in cacheDir.list(recursive: false, followLinks: false)) {
        try {
          if (entity is File) {
            freed += await entity.length();
            await entity.delete();
          } else if (entity is Directory) {
            freed += await _dirSizeRecursive(entity);
            await entity.delete(recursive: true);
          }
        } catch (_) {
          // Tek bir dosya/klasor kilitliyse veya silinemiyorsa atla,
          // digerlerini temizlemeye devam et.
        }
      }
    } catch (_) {
      // Gecici klasore hic erisilemedi; 0 bayt temizlendi olarak dondur.
    }
    return freed;
  }

  Future<int> _dirSizeRecursive(Directory dir) async {
    var total = 0;
    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {
            // Tek bir dosya okunamazsa toplami bozmadan atla.
          }
        }
      }
    } catch (_) {
      // Klasor listelenemedi; elde ne varsa onu dondur.
    }
    return total;
  }
}
