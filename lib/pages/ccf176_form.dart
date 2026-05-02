import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart'; // ✅ AJOUT (digitsOnly)

import '../widgets/form_matrix.dart';

class CCF176FormPage extends StatefulWidget {
  const CCF176FormPage({super.key});

  @override
  State<CCF176FormPage> createState() => _CCF176FormPageState();
}

class _CCF176FormPageState extends State<CCF176FormPage> {
  // ============================================================
  // LISTE CONTROLEURS (à compléter)
  // ============================================================
  static const List<String> CONTROLEURS = [
    "Aillerie Robin",
    "Bellegarde Nathalie",
    "Condro Alexis",
    "Dahan Stéphane",
    "Dubourg Sylvie",
    "Duvignac Julien",
    "Ducout Margaux",
    "Etcheverry Jérôme",
    "Fernandez Nicolas",
    "Fournié Benjamin",
    "Fournié Julien",
    "Gauthé David",
    "Geffroy Audrey",
    "Guyou Laurent",
    "Laborde M.Pierre",
    "Lapié Rémy",
    "Lasserre Jérémy",
    "Limouzi Rémy",
    "Marsan Sylvain",
    "Moussu Mathilde",
    "Paillou Frédéric",
    "Sanguina Dominique",
    "Sanguina Thierry",
    "Tallon Nicolas",
    // Exemple:
    // "DOMINIQUE SANGUINA",
  ];

  // ============================================================
  // Champs entête
  // ============================================================
  DateTime? dateVerification;
  String? controleur;

  // ✅ AJOUT : kilométrage (numérique)
  final TextEditingController kilometrageCtrl = TextEditingController();

  // ============================================================
  // Helpers
  // ============================================================
  bool _validateMatrix(Map<String, String?> map) => !map.values.any((v) => v == null);
  bool _validateText(TextEditingController c) => c.text.trim().isNotEmpty;
  bool vehiculeRoule = false;

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  // ============================================================
  // MATRICES
  // ============================================================

  final Map<String, String?> carburant = {
    "Niveau réservoir": null,
  };

  final Map<String, String?> niveauxCCF = {
    "Tonne": null,
    "Huile moteur": null,
    "Liquide de refroidissement": null,
    "Huile direction": null,
    "Liquide de frein": null,
    "Lave glace": null,
    "Mouillant": null,
  };

  final Map<String, String?> niveauxMoteurAux = {
    "Huile moteur": null,
    "Liquide de refroidissement": null,
  };

  final Map<String, String?> signalisation = {
    "Clignotant AVD": null,
    "Clignotant AVG": null,
    "Feu position AVD": null,
    "Feu position AVG": null,
    "Feu croissement AVD": null,
    "Feu croissement AVG": null,
    "Feu de route AVD": null,
    "Feu de route AVG": null,
    "Feu détresse AVG": null,
    "Feu détresse AVD": null,
    "Phare de travail AVD": null,
    "Phare de travail AVG": null,
    "Feux de gabarit G": null,
    "Feux de gabarit D": null,
    "Feu de recul D": null,
    "Feu de recul G": null,
    "Feu STOP G": null,
    "Eclairage plaque immat": null,
    "Feu STOP D": null,
    "Gyrophare": null,
    "Deux ton": null,
    "Phare travail moteur aux": null,
  };

  final Map<String, String?> chassis = {
    "Suspension / Ressorts": null,
    "Etat barre d'accouplement": null,
    "Etat Barre de direction": null,
    "Etat Barre Panhard": null,
    "Etat barres de tirant AR": null,
    "Etat Carrosserie": null,
  };

  final Map<String, String?> bouteilleAirCabine = {
    "Pression bouteille air": null,
  };

  final Map<String, String?> coffreConducteur = {
    "1 Contrôleur pression pneus": null,
    "1 Gerp": null,
    "1 Quadrafog": null,
    "1 Sangle": null,
    "1 Cordage": null,
    "1 Moufle": null,
    "1 Crépine avec flotteur": null,
    "1 Elingue": null,
    "1 Tronçonneuse": null,
    "Mise en service tronçonneuse": null,
    "1 Bidon huile et mélange": null,
    "Niveaux huile et mélange bidon": null,
    "1 Casque et protections auditives": null,
    "1 Pantalons de sécurité": null,
    "1 Paire de guêtres": null,
    "1 Raccord de 40 à vis": null,
    "1 Cric": null,
    "1 Clé de poteaux": null,
    "1 Réduction 70/40": null,
    "1 Réduction 100/70": null,
    "1 Commande": null,
    "1 Extincteur": null,
    "Goupille extincteur en place": null,
  };

  final Map<String, String?> coffrePassager = {
    "3 tuyaux prolongation Ldt": null,
    "5 tuyaux de 70": null,
    "2 tuyaux de 45": null,
  };

  final Map<String, String?> trousseOutils = {
    "1 Pince bec plat": null,
    "1 Tournevis plat": null,
    "1 Tournevis cruciforme": null,
    "1 Tournevis étoile": null,
    "1 Marteau": null,
    "2 Clés oeil 10/12": null,
    "1 Clé oeil coudée 16/18": null,
    "1 Clé oeil coudée 22/24": null,
    "1 Clé plate 36": null,
    "1 Clé plate 32/37": null,
    "1 Clé plate 30": null,
    "1 Clé plate 24/22": null,
    "1 Clé plate 16/18": null,
    "1 Clé plate 12/14": null,
    "1 Clé plate 13/15": null,
    "1 Clé plate 13/11": null,
    "1 Clé plate 19/17": null,
    "1 Clé plate 24/21": null,
    "1 Clé plate oeil de 17": null,
  };

  final Map<String, String?> dessusCCF = {
    "2 cales en bois": null,
  };

  final Map<String, String?> branchementLances = {
    "Vérifier branchement": null,
    "Lance 40/7": null,
    "Lance 40/10": null,
    "LDV": null,
    "Canon": null,
  };

  final Map<String, String?> lances = {
    "Lance 40/7": null,
    "Lance 40/10": null,
    "LDV": null,
    "Canon": null,
  };

  final Map<String, String?> arriereCCF = {
    "4 Aspiros": null,
    "1 Pelle": null,
    "1 Pioche": null,
    "1 Dévidoir tuyaux 27": null,
    "1 LdV 125": null,
    "1 Barre de remorquage": null,
    "1 Dévidoir tuyaux 45": null,
    "1 Division 45X45 2XGFR": null,
  };

  final Map<String, String?> interieurCabine = {
    "3 Masques araignée": null,
    "2 Chasubles": null,
    "2 Tricoises": null,
    "2 Cales en fer": null,
    "1 Commande treuil": null,
    "1 filtre dosatron": null,
    "1 Boîte ampoules comprenant": null,
    "2 ampoules 24V/21W": null,
    "1 Ampoule 24V/10W": null,
    "1 Ampoule T4": null,
    "1 Ampoule 24V/5W": null,
    "1 Ampoule H4": null,
    "1 petit pied de biche": null,
  };

  final Map<String, String?> divers = {
    "Pression pneu AVD": null,
    "Pression pneu AVG": null,
    "Pression pneu ARD": null,
    "Pression pneu ARG": null,
    "Essai des freins": null,
    "Nettoyage vitres": null,
    "Nettoyage pare-brise": null,
    "Nettoyage rétroviseur D": null,
    "Nettoyage rétroviseur G": null,
    "Nettoyage véhicule": null,
  };

  final Map<String, String?> verificationAutoprotection = {
    "Auto protection châssis": null,
    "Auto protection cabine": null,
    "Inscrit sur main courante": null,
  };

  // ============================================================
  // COMMENTAIRES (obligatoires)
  // ============================================================
  final TextEditingController comNiveauxCCF = TextEditingController();
  final TextEditingController comNiveauxAux = TextEditingController();
  final TextEditingController comSignalisation = TextEditingController();
  final TextEditingController comChassis = TextEditingController();
  final TextEditingController comCoffreConducteur = TextEditingController();
  final TextEditingController comCoffrePassager = TextEditingController();
  final TextEditingController comTrousseOutils = TextEditingController();
  final TextEditingController comDessusCCF = TextEditingController();
  final TextEditingController comDivers = TextEditingController();
  final TextEditingController comAutoprotection = TextEditingController();

  final TextEditingController faireRouler = TextEditingController();

  @override
  void dispose() {
    comNiveauxCCF.dispose();
    comNiveauxAux.dispose();
    comSignalisation.dispose();
    comChassis.dispose();
    comCoffreConducteur.dispose();
    comCoffrePassager.dispose();
    comTrousseOutils.dispose();
    comDessusCCF.dispose();
    comDivers.dispose();
    comAutoprotection.dispose();
    faireRouler.dispose();
    kilometrageCtrl.dispose(); // ✅ AJOUT
    super.dispose();
  }

  bool _validateAll() {
    // ✅ AJOUT : km obligatoire + numérique
    final km = int.tryParse(kilometrageCtrl.text.trim());
    final headerOk = dateVerification != null &&
        (controleur != null && controleur!.trim().isNotEmpty) &&
        km != null;

    final matricesOk =
        _validateMatrix(carburant) &&
        _validateMatrix(niveauxCCF) &&
        _validateMatrix(niveauxMoteurAux) &&
        _validateMatrix(signalisation) &&
        _validateMatrix(chassis) &&
        _validateMatrix(bouteilleAirCabine) &&
        _validateMatrix(coffreConducteur) &&
        _validateMatrix(coffrePassager) &&
        _validateMatrix(trousseOutils) &&
        _validateMatrix(dessusCCF) &&
        _validateMatrix(branchementLances) &&
        _validateMatrix(lances) &&
        _validateMatrix(arriereCCF) &&
        _validateMatrix(interieurCabine) &&
        _validateMatrix(divers) &&
        _validateMatrix(verificationAutoprotection);

    final commentsOk =
        _validateText(comNiveauxCCF) &&
        _validateText(comNiveauxAux) &&
        _validateText(comSignalisation) &&
        _validateText(comChassis) &&
        _validateText(comCoffreConducteur) &&
        _validateText(comCoffrePassager) &&
        _validateText(comTrousseOutils) &&
        _validateText(comDessusCCF) &&
        _validateText(comDivers) &&
        _validateText(comAutoprotection);

    return headerOk && matricesOk && commentsOk;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDate: dateVerification ?? now,
    );
    if (!mounted) return;
    if (picked != null) setState(() => dateVerification = picked);
  }

  void _showIncomplete() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Formulaire incomplet : merci de répondre à toutes les questions obligatoires."),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_validateAll()) {
      _showIncomplete();
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final List<Map<String, dynamic>> answers = [];

      void addSection(String section, Map<String, String?> map) {
        map.forEach((question, value) {
          answers.add({
            'section': section,
            'question': question,
            'answer': value ?? '',
          });
        });
      }

      // ✅ AJOUT : section kilométrage (enregistrée dans answers)
      answers.add({
        'section': "KILOMÉTRAGE",
        'question': "Kilométrage",
        'answer': int.parse(kilometrageCtrl.text.trim()),
      });

      // === SECTIONS ===
      addSection("CARBURANT", carburant);
      addSection("NIVEAUX CCF", niveauxCCF);
      addSection("NIVEAUX MOTEURS AUXILIAIRES", niveauxMoteurAux);
      addSection("SIGNALISATION", signalisation);
      addSection("CHÂSSIS", chassis);
      addSection("BOUTEILLE AIR CABINE", bouteilleAirCabine);
      addSection("COFFRE CÔTÉ CONDUCTEUR", coffreConducteur);
      addSection("COFFRE CÔTÉ PASSAGER", coffrePassager);
      addSection("TROUSSE À OUTILS", trousseOutils);
      addSection("DESSUS CCF", dessusCCF);
      addSection("DESSUS DU CCF : BRANCHEMENT LANCES", branchementLances);
      addSection("LANCES", lances);
      addSection("ARRIÈRE DU CCF", arriereCCF);
      addSection("INTÉRIEUR CABINE", interieurCabine);
      addSection("DIVERS", divers);
      addSection("VÉRIFICATION AUTOPROTECTION", verificationAutoprotection);

      // === COMMENTAIRES ===
      answers.add({'section': "Commentaires", 'question': "Commentaire niveaux CCF", 'answer': comNiveauxCCF.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaire niveaux auxiliaires", 'answer': comNiveauxAux.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaire signalisation", 'answer': comSignalisation.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaire châssis", 'answer': comChassis.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaire coffre conducteur", 'answer': comCoffreConducteur.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaire coffre passager", 'answer': comCoffrePassager.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaire trousse à outils", 'answer': comTrousseOutils.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaire dessus CCF", 'answer': comDessusCCF.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaire divers", 'answer': comDivers.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaire autoprotection", 'answer': comAutoprotection.text.trim()});

      // Optionnel : enregistrer aussi date/controleur clairement (utile pour PDF/admin)
      await FirebaseFirestore.instance.collection('vehicle_checks_submissions').add({
        'formId': 'CCF_176',
        'formTitle': 'CCF 176',
        'vehicle': 'CCF 176',
        'dateVerification': dateVerification == null ? null : Timestamp.fromDate(dateVerification!),
        'controleur': controleur ?? '',
        'kilometrage': int.parse(kilometrageCtrl.text.trim()), // ✅ AJOUT (champ direct)
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'createdByEmail': user.email ?? '',
        'answers': answers,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("CCF 176 enregistré ✅")),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text("CCF 176")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // ================================
            // EN-TÊTE
            // ================================
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("DATE DE LA VÉRIFICATION *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: _pickDate,
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text(
                        dateVerification == null ? "Choisir la date" : _fmtDate(dateVerification!),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text("NOM(S) CONTRÔLEUR(S) *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: (controleur != null && controleur!.isNotEmpty) ? controleur : null,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: CONTROLEURS.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => controleur = v),
                  ),
                  if (CONTROLEURS.isEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      "Sélectionner votre Nom/Prénom",
                      style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
                    ),
                  ],

                  // ✅ AJOUT : kilométrage dans l'entête
                  const SizedBox(height: 16),
                  const Text("KILOMÉTRAGE *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: kilometrageCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Ex: 45231",
                    ),
                  ),
                ]),
              ),
            ),

            // ================================
            // FORMULAIRES
            // ================================

            FormMatrix(
              title: "CARBURANT",
              columns: const ["+3/4", "-3/4"],
              values: carburant,
              onChanged: (r, v) => setState(() => carburant[r] = v),
            ),

            FormMatrix(
              title: "NIVEAUX CCF",
              columns: const ["OK", "Niveau bas", "Complément fait"],
              values: niveauxCCF,
              onChanged: (r, v) => setState(() => niveauxCCF[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur les niveaux *", controller: comNiveauxCCF),

            FormMatrix(
              title: "NIVEAUX MOTEURS AUXILIAIRES",
              columns: const ["OK", "Niveau bas", "Complément fait"],
              values: niveauxMoteurAux,
              onChanged: (r, v) => setState(() => niveauxMoteurAux[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur les niveaux moteur auxiliaire *", controller: comNiveauxAux),

            FormMatrix(
              title: "SIGNALISATION",
              columns: const ["Fonctionne", "Ne fonctionne pas", "Ampoule remplacée"],
              values: signalisation,
              onChanged: (r, v) => setState(() => signalisation[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur la signalisation *", controller: comSignalisation),

            FormMatrix(
              title: "CHÂSSIS",
              columns: const ["OK", "HS"],
              values: chassis,
              onChanged: (r, v) => setState(() => chassis[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur le châssis *", controller: comChassis),

            FormMatrix(
              title: "BOUTEILLE AIR CABINE",
              columns: const ["Supérieur à 270 bars", "Inférieur à 270 bars"],
              values: bouteilleAirCabine,
              onChanged: (r, v) => setState(() => bouteilleAirCabine[r] = v),
            ),

            FormMatrix(
              title: "COFFRE CÔTÉ CONDUCTEUR",
              columns: const ["OK", "Manque"],
              values: coffreConducteur,
              onChanged: (r, v) => setState(() => coffreConducteur[r] = v),
            ),
            _TextCommentCard(label: "Commentaire coffre côté conducteur *", controller: comCoffreConducteur),

            FormMatrix(
              title: "COFFRE CÔTÉ PASSAGER",
              columns: const ["OK", "Manque"],
              values: coffrePassager,
              onChanged: (r, v) => setState(() => coffrePassager[r] = v),
            ),
            _TextCommentCard(label: "Commentaire coffre côté passager *", controller: comCoffrePassager),

            FormMatrix(
              title: "TROUSSE À OUTILS",
              columns: const ["OK", "Manque"],
              values: trousseOutils,
              onChanged: (r, v) => setState(() => trousseOutils[r] = v),
            ),
            _TextCommentCard(label: "Commentaire trousse à outils *", controller: comTrousseOutils),

            FormMatrix(
              title: "DESSUS CCF",
              columns: const ["OK", "Manque 1", "Manque 2"],
              values: dessusCCF,
              onChanged: (r, v) => setState(() => dessusCCF[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur dessus CCF *", controller: comDessusCCF),

            FormMatrix(
              title: "DESSUS DU CCF : BRANCHEMENT LANCES",
              columns: const ["OK", "HS"],
              values: branchementLances,
              onChanged: (r, v) => setState(() => branchementLances[r] = v),
            ),

            FormMatrix(
              title: "LANCES",
              columns: const ["OK", "HS"],
              values: lances,
              onChanged: (r, v) => setState(() => lances[r] = v),
            ),

            FormMatrix(
              title: "ARRIÈRE DU CCF",
              columns: const ["OK", "Manque"],
              values: arriereCCF,
              onChanged: (r, v) => setState(() => arriereCCF[r] = v),
            ),

            FormMatrix(
              title: "INTÉRIEUR CABINE",
              columns: const ["OK", "Manque"],
              values: interieurCabine,
              onChanged: (r, v) => setState(() => interieurCabine[r] = v),
            ),

            FormMatrix(
              title: "DIVERS",
              columns: const ["OK", "Manque"],
              values: divers,
              onChanged: (r, v) => setState(() => divers[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur divers *", controller: comDivers),

            FormMatrix(
              title: "VÉRIFICATION AUTOPROTECTION",
              columns: const ["OK", "HS"],
              values: verificationAutoprotection,
              onChanged: (r, v) => setState(() => verificationAutoprotection[r] = v),
            ),
            _TextCommentCard(label: "Commentaire autoprotection *", controller: comAutoprotection),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: CheckboxListTile(
                value: vehiculeRoule,
                onChanged: (v) => setState(() => vehiculeRoule = v ?? false),
                title: const Text(
                  "Faire rouler VLHR 10/15 minutes",
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text("Cocher si le véhicule a tourné lors de la vérification"),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text("VALIDER"),
                onPressed: _submit, // ✅ UN SEUL onPressed
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TextCommentCard extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _TextCommentCard({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}