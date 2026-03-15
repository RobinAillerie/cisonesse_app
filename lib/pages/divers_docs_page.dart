import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'package:cisonesse_app/pages/divers_docs_data.dart';

class DiversDocsPage extends StatelessWidget {
  const DiversDocsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ on prend les catégories depuis le fichier data (source unique)
    final categories = DiversDocsData.buildCategories();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text("Divers")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final cat in categories) _CategoryCard(category: cat),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// ✅ petit wrapper PUBLIC (pour réutiliser le même design dans les sous-sections du drawer)
class CategoryCardWrapper extends StatelessWidget {
  final DocNode category;
  const CategoryCardWrapper({super.key, required this.category});

  @override
  Widget build(BuildContext context) => _CategoryCard(category: category);
}

// -------------------- UI (design conservé) --------------------

class _CategoryCard extends StatelessWidget {
  final DocNode category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        leading: Icon(category.icon),
        title: Text(category.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (category.isFolder)
            for (final child in category.children) _SubFolderCard(node: child)
          else if (category.items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text("Aucun document pour le moment."),
            )
          else
            for (final doc in category.items) _PdfTile(item: doc),
        ],
      ),
    );
  }
}

class _SubFolderCard extends StatelessWidget {
  final DocNode node;
  const _SubFolderCard({required this.node});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(top: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        leading: Icon(node.icon),
        title: Text(node.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (node.items.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text("Aucun document pour le moment."),
            )
          else
            for (final doc in node.items) _PdfTile(item: doc),
        ],
      ),
    );
  }
}

class _PdfTile extends StatelessWidget {
  final PdfItem item;
  const _PdfTile({required this.item});

  Future<File> _assetToFile(String assetPath) async {
    final bytes = await rootBundle.load(assetPath);
    final dir = await getTemporaryDirectory();
    final fileName = assetPath.split('/').last;
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file;
  }

  Future<void> _open(BuildContext context) async {
    try {
      final f = await _assetToFile(item.assetPath);
      await OpenFilex.open(f.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible d'ouvrir le PDF : $e")),
      );
    }
  }

  Future<void> _share(BuildContext context) async {
    try {
      final f = await _assetToFile(item.assetPath);
      await Share.shareXFiles([XFile(f.path)], text: item.title);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible de partager/télécharger : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.picture_as_pdf_rounded),
      title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(item.assetPath, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Wrap(
        spacing: 8,
        children: [
          IconButton(
            tooltip: "Ouvrir",
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () => _open(context),
          ),
          IconButton(
            tooltip: "Télécharger / Partager",
            icon: const Icon(Icons.download_rounded),
            onPressed: () => _share(context),
          ),
        ],
      ),
    );
  }
}