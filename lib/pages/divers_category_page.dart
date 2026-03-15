import 'package:flutter/material.dart';
import 'divers_docs_data.dart';
import 'divers_docs_page.dart' show CategoryCardWrapper; // on va te donner juste après

class DiversCategoryPage extends StatelessWidget {
  final DocNode node;
  final String appBarTitle;

  const DiversCategoryPage({
    super.key,
    required this.node,
    required this.appBarTitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        CategoryCardWrapper(category: node),
        const SizedBox(height: 12),
      ],
    );
  }
}