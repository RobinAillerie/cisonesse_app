import 'package:flutter/material.dart';

class PdfItem {
  final String title;
  final String assetPath;
  const PdfItem({required this.title, required this.assetPath});
}

class DocNode {
  final String title;
  final IconData icon;
  final List<PdfItem> items;
  final List<DocNode> children;

  const DocNode._({
    required this.title,
    required this.icon,
    this.items = const [],
    this.children = const [],
  });

  const DocNode.category({
    required String title,
    required IconData icon,
    required List<PdfItem> items,
  }) : this._(title: title, icon: icon, items: items);

  const DocNode.folder({
    required String title,
    required IconData icon,
    required List<DocNode> children,
  }) : this._(title: title, icon: icon, children: children);

  bool get isFolder => children.isNotEmpty;
}

class DiversDocsData {
  static List<DocNode> buildCategories() {
    return [
      DocNode.category(
        title: "Matériel Véhicules",
        icon: Icons.fire_truck_rounded,
        items: const [
          PdfItem(
            title: "Engins spécifiques du SDIS 40",
            assetPath: "assets/pdfs/materiel_vehicules/Engins spécifiques du SDIS 40.pdf",
          ),
        ],
      ),
      DocNode.category(
        title: "Ascenseurs EPHAD",
        icon: Icons.elevator_rounded,
        items: const [
          // ⚠️ FIX: ton path n’avait pas "assets/pdfs/..."
          PdfItem(
            title: "Procédure ascenseurs EPHAD",
            assetPath: "assets/pdfs/ascenseurs_ephad/Procédure ascenseurs EPHAD.pptx",
          ),
        ],
      ),
      DocNode.category(
        title: "Supports Incendie",
        icon: Icons.local_fire_department_rounded,
        items: const [
          PdfItem(title: "Fiche mémo GAZ", assetPath: "assets/pdfs/supports_incendie/Fiche mémo GAZ.pdf"),
          PdfItem(title: "Rangement LSPCC", assetPath: "assets/pdfs/supports_incendie/Rangement LSPCC.pdf"),
                    PdfItem(title: "Fiche mémo GAZ", assetPath: "assets/pdfs/supports_incendie/ODFFEN 2026 SDIS 40.pdf"),

        ],
      ),
      DocNode.category(
        title: "Supports SUAP",
        icon: Icons.medical_services_rounded,
        items: const [
          PdfItem(title: "Brulures", assetPath: "assets/pdfs/supports_suap/Brulures.pdf"),
          PdfItem(title: "Catégorisation des victimes.docx", assetPath: "assets/pdfs/supports_suap/Catégorisation des victimes.docx.pdf"),
          PdfItem(title: "FDOD Notion de victimes", assetPath: "assets/pdfs/supports_suap/FDOD Notion de victimes.pdf"),
          PdfItem(title: "Fiche Bilan VSAV", assetPath: "assets/pdfs/supports_suap/Fiche Bilan VSAV.pdf"),
          PdfItem(title: "Message VSAV.docx", assetPath: "assets/pdfs/supports_suap/Message VSAV.docx.pdf"),
          PdfItem(title: "Prise en charge du NN à la naissance", assetPath: "assets/pdfs/supports_suap/Prise en charge du NN à la naissance.pdf"),
          PdfItem(title: "Rapport DSA 2021 VIERGE.docx", assetPath: "assets/pdfs/supports_suap/Rapport DSA 2021 VIERGE.docx.pdf"),
        ],
      ),
      DocNode.category(
        title: "Supports FDF",
        icon: Icons.forest_rounded,
        items: const [
          PdfItem(title: "FDOD FDF Memento VLHR", assetPath: "assets/pdfs/supports_fdf/FDOD FDF Memento VLHR.pdf"),
          PdfItem(title: "Fiche message FDF", assetPath: "assets/pdfs/supports_fdf/Fiche message FDF.pdf"),
          PdfItem(title: "ODFFEN 2025 SDIS40.docx", assetPath: "assets/pdfs/supports_fdf/ODFFEN 2025 SDIS40.docx.pdf"),
          PdfItem(title: "Prise en compte des moyens aériens.docx", assetPath: "assets/pdfs/supports_fdf/Prise en compte des moyens aériens.docx.pdf"),
        ],
      ),
      DocNode.category(
        title: "Procédure balisage",
        icon: Icons.traffic_rounded,
        items: const [
          PdfItem(title: "Protection et balisage sur les axes routiers", assetPath: "assets/pdfs/procedure_balisage/Protection et balisage sur les axes routiers.pdf"),
        ],
      ),
      DocNode.category(
        title: "Antares et THP 700",
        icon: Icons.settings_input_antenna_rounded,
        items: const [
          PdfItem(title: "ALPHABET PHONETIQUE.docx", assetPath: "assets/pdfs/antares_thp700/ALPHABET_PHONETIQUE.docx.pdf"),
          PdfItem(title: "Fréquences non programmées", assetPath: "assets/pdfs/antares_thp700/Fréquences_non_programmées.pdf"),
          PdfItem(title: "MEMO TPH 700", assetPath: "assets/pdfs/antares_thp700/MEMO_TPH_700.pdf"),
          PdfItem(title: "Statuts antares", assetPath: "assets/pdfs/antares_thp700/Statuts_antares.pdf"),
        ],
      ),

      // Plans batiments (folder)
      DocNode.folder(
        title: "Plans batiments",
        icon: Icons.map_rounded,
        children: const [
          DocNode.category(title: "EPHAD A NOSTE", icon: Icons.apartment_rounded, items: [
            PdfItem(title: "EPHAD A NOSTE", assetPath: "assets/pdfs/plans_batiments/batiment_01/EPHAD A NOSTE 01 2024.pdf"),
          ]),
          DocNode.category(title: "Foyer municipal", icon: Icons.apartment_rounded, items: [
            PdfItem(title: "Foyer municipal", assetPath: "assets/pdfs/plans_batiments/batiment_02/Foyer municipal.pptx.pdf"),
          ]),
          DocNode.category(title: "Maternelle et cantine", icon: Icons.apartment_rounded, items: [
            PdfItem(title: "Maternelle et cantine", assetPath: "assets/pdfs/plans_batiments/batiment_03/Maternelle et cantine.ppt.pdf"),
          ]),
          DocNode.category(title: "Tradilandes Jacquet", icon: Icons.apartment_rounded, items: [
            PdfItem(title: "Tradilandes Jacquet", assetPath: "assets/pdfs/plans_batiments/batiment_04/Tradilandes Jacquet.ppt.pdf"),
          ]),
          DocNode.category(title: "HUMULAND", icon: Icons.apartment_rounded, items: [
            PdfItem(title: "HUMULAND", assetPath: "assets/pdfs/plans_batiments/batiment_05/HUMULAND.pdf"),
          ]),
          DocNode.category(title: "Ateliers municipaux", icon: Icons.apartment_rounded, items: [
            PdfItem(title: "Ateliers municipaux", assetPath: "assets/pdfs/plans_batiments/batiment_06/Ateliers municipaux et hangar tables chaises.pptx.pdf"),
          ]),
          DocNode.category(title: "Médiathèque", icon: Icons.apartment_rounded, items: [
            PdfItem(title: "RDC", assetPath: "assets/pdfs/plans_batiments/batiment_07/RDC.pdf"),
            PdfItem(title: "Logement 2 étage", assetPath: "assets/pdfs/plans_batiments/batiment_07/Logement 2 étage.pdf"),
            PdfItem(title: "Logement 1 étage", assetPath: "assets/pdfs/plans_batiments/batiment_07/Logement 1 étage.pdf"),
            PdfItem(title: "Entête et descriptif", assetPath: "assets/pdfs/plans_batiments/batiment_07/Entête et descriptif.docx.pdf"),
          ]),
          DocNode.category(title: "STEP", icon: Icons.apartment_rounded, items: [
            PdfItem(title: "STEP", assetPath: "assets/pdfs/plans_batiments/batiment_08/Station d'épuration.ppt.pdf"),
          ]),
          DocNode.category(title: "COMPLEXE SPORTIF", icon: Icons.apartment_rounded, items: [
            PdfItem(title: "Plan", assetPath: "assets/pdfs/plans_batiments/batiment_09/PLAN.pdf"),
            PdfItem(title: "Entête et descriptif", assetPath: "assets/pdfs/plans_batiments/batiment_09/Entête et descriptif.pdf"),
          ]),
          DocNode.category(title: "MAIRIE", icon: Icons.apartment_rounded, items: [
            PdfItem(title: "Plan RDC & ETAGE", assetPath: "assets/pdfs/plans_batiments/batiment_10/Plan RDC et Etage.pdf"),
            PdfItem(title: "Plan Etage Mairie", assetPath: "assets/pdfs/plans_batiments/batiment_10/Plan Etage Mairie.pdf"),
          ]),
          DocNode.category(title: "CAMPING ONESSE", icon: Icons.apartment_rounded, items: [
            PdfItem(title: "Plan CAMPING ONESSE", assetPath: "assets/pdfs/plans_batiments/batiment_11/CAMPING ONESSE.ppt.pdf"),
          ]),
          DocNode.category(title: "EGLISE", icon: Icons.apartment_rounded, items: [
            PdfItem(title: "Plan EGLISE", assetPath: "assets/pdfs/plans_batiments/batiment_12/PLAN EGLISE.ppt.pdf"),
          ]),
          DocNode.category(title: "MALAGA", icon: Icons.apartment_rounded, items: [
            PdfItem(title: "Plan MALAGA", assetPath: "assets/pdfs/plans_batiments/batiment_13/Plan Malaga_pompiers.pdf"),
            PdfItem(title: "SERRES PHOTOVOLTAIQUES", assetPath: "assets/pdfs/plans_batiments/batiment_13/SERRES PHOTOVOLTAIQUES.pdf"),
            PdfItem(title: "fiches descriptives pompiers", assetPath: "assets/pdfs/plans_batiments/batiment_13/Fiche descriptive_pompiers.pdf"),
          ]),
        ],
      ),

      DocNode.category(
        title: "Contrôle PF et PEI",
        icon: Icons.plumbing_rounded,
        items: const [
          PdfItem(title: "Bilan contrôle PF 2024", assetPath: "assets/pdfs/controle_pf_pei/Bilan contrôle PF 2024 - Feuil1.pdf"),
          PdfItem(title: "Bilan contrôle PF 2025", assetPath: "assets/pdfs/controle_pf_pei/Bilan contrôle PF 2025.pdf"),
        ],
      ),
      DocNode.category(
        title: "Organigramme CIS",
        icon: Icons.account_tree_rounded,
        items: const [
          PdfItem(title: "Organigramme", assetPath: "assets/pdfs/organigramme_cis/Orga 01 2025.pdf"),
        ],
      ),
      DocNode.category(
        title: "Infos diverses",
        icon: Icons.info_rounded,
        items: const [
          PdfItem(title: "Synthèse_stats_SIS_V3", assetPath: "assets/pdfs/infos_diverses/2025.02.26_Synthèse_stats_SIS_V3.pdf"),
          PdfItem(title: "Bilan d'activité 2024", assetPath: "assets/pdfs/infos_diverses/Bilan d'activité 2024.pdf"),
          PdfItem(title: "Plan d'équipement 2025.pptx", assetPath: "assets/pdfs/infos_diverses/Plan d'équipement 2025.pptx.pdf"),
          PdfItem(title: "Statistiques CIS Onesse 2024", assetPath: "assets/pdfs/infos_diverses/Statistiques CIS Onesse 2024.pdf"),
          PdfItem(title: "StatsSDIS24BD (1)", assetPath: "assets/pdfs/infos_diverses/StatsSDIS24BD (1).pdf"),
        ],
      ),
      DocNode.category(
        title: "Habillement",
        icon: Icons.checkroom_rounded,
        items: const [
          PdfItem(title: "Attribution habillement par personnel - Casques F1", assetPath: "assets/pdfs/habillement/Attribution habillement par personnel - Casques F1.pdf"),
          PdfItem(title: "Vestes textiles", assetPath: "assets/pdfs/habillement/Vestes textiles.pdf"),
          PdfItem(title: "Vestes TSI", assetPath: "assets/pdfs/habillement/Vestes TSI.pdf"),
          PdfItem(title: "Pantalons TSI", assetPath: "assets/pdfs/habillement/Pantalons TSI.pdf"),
          PdfItem(title: "Pantalons textiles", assetPath: "assets/pdfs/habillement/Pantalons textiles.pdf"),
          PdfItem(title: "Casques F2", assetPath: "assets/pdfs/habillement/Casques F2.pdf"),
          PdfItem(title: "Casques F1", assetPath: "assets/pdfs/habillement/Casques F1.pdf"),
        ],
      ),
    ];
  }

  static DocNode? findCategoryByTitle(String title) {
    final cats = buildCategories();
    for (final c in cats) {
      if (c.title == title) return c;
    }
    return null;
  }

  static DocNode? findPlanByTitle(String planTitle) {
    final cats = buildCategories();
    final plansFolder = cats.where((e) => e.title == "Plans batiments").cast<DocNode?>().firstOrNull;
    if (plansFolder == null) return null;
    for (final child in plansFolder.children) {
      if (child.title == planTitle) return child;
    }
    return null;
  }
}

extension _FirstOrNullExt<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}