import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class PdfAssetOpener {
  /// Copie l'asset PDF dans le cache du téléphone puis l'ouvre
  static Future<void> open(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final dir = await getTemporaryDirectory();

    // Nom de fichier safe
    final fileName = assetPath.split('/').last;
    final file = File('${dir.path}/$fileName');

    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );

    await OpenFilex.open(file.path);
  }
}