import 'package:flutter/material.dart';

import '../../services/pdf_asset_opener.dart';
import 'divers_docs_data.dart'; // <-- ton fichier où il y a DiversDocsData / DocNode / PdfItem

class DiversPage extends StatelessWidget {
  const DiversPage({super.key});

  @override
  Widget build(BuildContext context) {
    final roots = DiversDocsData.buildCategories();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text("Divers")),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final node in roots) _NodeCard(node: node),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  final DocNode node;
  const _NodeCard({required this.node});

  @override
  Widget build(BuildContext context) {
    if (node.isFolder) {
      return Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: ExpansionTile(
          leading: Icon(node.icon),
          title: Text(
            node.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          children: [
            for (final child in node.children) _NodeCard(node: child),
          ],
        ),
      );
    }

    // Category
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ExpansionTile(
        leading: Icon(node.icon),
        title: Text(
          node.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        children: [
          if (node.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text("Aucun document."),
            )
          else
            for (final pdf in node.items)
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded),
                title: Text(pdf.title),
                subtitle: Text(pdf.assetPath, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.download_rounded),
                onTap: () async {
                  try {
                    await PdfAssetOpener.open(pdf.assetPath);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Impossible d'ouvrir le PDF : $e")),
                      );
                    }
                  }
                },
              ),
        ],
      ),
    );
  }
}