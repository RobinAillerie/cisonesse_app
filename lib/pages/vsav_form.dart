// lib/pages/vsav_form.dart
//
// VSAV — design identique CCF176 + validation stricte
// Stockage: vehicle_checks_submissions
// Champs: formId, formTitle, vehicle, dateVerification(Timestamp), controleur,
// kilometrage(int), createdAt, createdBy, createdByEmail,
// answers: [{section, question, answer}]

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../widgets/form_matrix.dart';

class VSAVFormPage extends StatefulWidget {
  const VSAVFormPage({super.key});

  static const String formId = 'VSAV_065';
  static const String formTitle = 'VSAV 065';
  static const String vehicle = 'VSAV 065';

  @override
  State<VSAVFormPage> createState() => _VSAVFormPageState();
}

class _VSAVFormPageState extends State<VSAVFormPage> {
  // ============================================================
  // LISTE CONTROLEURS (comme tes autres formulaires)
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
  ];
  
  // ============================================================
  // Champs entête
  // ============================================================
  DateTime? dateVerification;
  String? controleur;

  final TextEditingController kilometrageCtrl = TextEditingController();

  // ============================================================
  // Helpers
  // ============================================================
  bool _validateMatrix(Map<String, String?> map) => !map.values.any((v) => v == null);
  bool _validateText(TextEditingController c) => c.text.trim().isNotEmpty;
  
  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  // ============================================================
  // MATRICES (contenu = questions Google Forms)
  // ============================================================

  // NIVEAUX *
  final Map<String, String?> niveaux = {
    "Huile moteur": null,
    "Carburant": null,
    "Liquide de refroidissement": null,
    "Liquide de frein": null,
    "Lave glace": null,
    "Huile de direction": null,
  };

  // Signalisation *
  final Map<String, String?> signalisation = {
    "Feu position AVD": null,
    "Feu position AVG": null,
    "Feu croisement AVD": null,
    "Feu croissement AVG": null,
    "Feu de route AVD": null,
    "Feu de route AVG": null,
    "Clignotant AVD": null,
    "Clignotant AVG": null,
    "Clignotant ARD": null,
    "Clignotant ARG": null,
    "Anti brouillard AVG": null,
    "Antibrouillard AVD": null,
    "Feux de détresse AV": null,
    "Feux bleus de pénétration": null,
    "Rampe gyrophare AV": null,
    "Eclairage latéral D": null,
    "Deux tons": null,
    "Feux porte latérale G": null,
    "Feux stop": null,
    "Feux rouge portes arrière": null,
    "Rampe arrière": null,
    "Feux de recul": null,
    "Eclairage latéral G": null,
    "Feux orange rampe arrière": null,
    "Rampe gyrophare AR": null,
  };

  // Ecran tactile Cabine *
  final Map<String, String?> ecranTactileCabine = {
    "Ecran tactile : Partie giro/2 tons": null,
    "Voyant + essai gyrophare": null,
    "Voyant + essai 2 tons": null,
    "Voyant + essai klaxon de recul": null,
    "Voyant + essai feux latéraux blancs": null,
    "Ecran tactile : Partie chauffage": null,
    "Voyant + mise en route": null,
    "Voyant + essai baisse T°": null,
    "Voyant + essai monter T°": null,
    "Voyant entrée air": null,
    "Voyant extraction air": null,
    "Voyant allumage complet": null,
    "Voyant phares blancs latéraux": null,
    "Voyant projecteur cabine": null,
    "Voyant projecteur cellule": null,
  };

  // Sacoche bleue dans cabine *
  final Map<String, String?> sacocheBleueCabine = {
    "Fiches bilan": null,
    "Fiches refus de transport": null,
    "Plan Atlantic village": null,
    "Plan photovoltaïque RION": null,
  };

  // Divers cabine *
  final Map<String, String?> diversCabine = {
    "Essai lampes torches.": null,
    "Radio : s'allume.": null,
    "GPS : écran s'allume.": null,
    "Clé A63": null,
    "Pochette plan NOVI": null,
    "Boîtes gants ( L - XL)": null,
    "2 Gilets signalisation": null,
    "Boîte ampoules complète": null,
    "Essai climatisation": null,
    "Kit tuerie de masse": null,
  };

  // Brancard. Le sortir pour essais *
  final Map<String, String?> brancard = {
    "Roues vertes se déplient / s'enclenchent": null,
    "Roues rouges se déplient et s'enclenchent": null,
    "Côté pieds se relève et baisse": null,
    "Côté tête se relève et baisse": null,
    "Barrière gauche se lève et se replie": null,
    "Barrière droite se lève et se replie": null,
  };

  // Matériel Cellule *
  final Map<String, String?> materielCellule = {
    "Essai/contrôle charge tensiomètre": null,
    "Dsa voir si voyant vert clignote": null,
    "Essai et contrôle charge Oxymètre": null,
    "Essai aspirateur de mucosité": null,
    "2 Gilets de signalisation": null,
    "Détecteur monoxyde de carbone": null,
  };

  // Eclairage cellule *
  final Map<String, String?> eclairageCellule = {
    "Eclairage écran tactile \"brancard\" s'allume": null,
    "Voyant + essai monté auto": null,
    "Voyant + essai descente auto": null,
    "Voyant + essai monté tête": null,
    "Voyant + essai monté pieds": null,
    "Voyant + essai descente pieds": null,
    "Voyant + essai stop brancard": null,
    "Eclairage écran tactile \"éclairage\" s'allume": null,
    "Voyant éclairage côté gauche": null,
    "Voyant éclairage côté droit": null,
    "Voyant éclairage central": null,
    "Voyant éclairage traumas": null,
    "Voyant projecteur travail AR": null,
    "Voyant et essai sonette": null,
  };

  // Porte latérale *
  final Map<String, String?> porteLaterale = {
    "1 Corde à lancer": null,
    "Kit voiture élec 1 paire de gants": null,
    "Kit voiture élec 1 boîte de talc": null,
    "1 Pied de biche": null,
    "3 Cônes de Lubec": null,
    "1 Veste cuir": null,
    "1 paire gants type C": null,
    "1 Casque F1": null,
  };

  // Divers *
  final Map<String, String?> divers = {
    "Pression pneu AVD": null,
    "Etat pneu AVD": null,
    "Pression pneu AVG": null,
    "Etat pneu AVG": null,
    "Pression pneu ARD": null,
    "Etat pneu ARD": null,
    "Pression pneu ARG": null,
    "Etat pneu ARG": null,
    "Vérification des lames de ressort": null,
    "Nettoyage pare-brise": null,
    "Nettoyage rétroviseurs": null,
    "Nettoyage vitres AR": null,
    "Nettoyage vitre latérale D": null,
    "Nettoyage extérieur véhicule": null,
  };

  final Map<String, String?> verificationAutoprotection1 = {
    "Auto protection châssis": null,
    "Auto protection cabine": null,
    "Inscrit sur main courante": null,
    "Vérification Bouteille d'air >270 Bars": null,
  };

  final Map<String, String?> verificationAutoprotection2 = {
    "Auto protection châssis": null,
    "Auto protection cabine": null,
    "Inscrit sur main courante": null,
    "Vérification Bouteille d'air >270 Bars": null,
  };

  // ============================================================
  // COMMENTAIRES (obligatoires)
  // ============================================================
  final TextEditingController comNiveaux = TextEditingController();
  final TextEditingController comSignalisation = TextEditingController();
  final TextEditingController comEcranTactile = TextEditingController();
  final TextEditingController comSacocheBleue = TextEditingController();
  final TextEditingController comCabine = TextEditingController();
  final TextEditingController comBrancard = TextEditingController();
  final TextEditingController comMaterielCabine = TextEditingController();
  final TextEditingController comEclairageCellule = TextEditingController();
  final TextEditingController comPorteLaterale = TextEditingController();
  final TextEditingController comDivers = TextEditingController();
  final TextEditingController comAutoprotection = TextEditingController();

  // Champ final requis
  final TextEditingController faireRouler = TextEditingController();

  bool vehiculeRoule = false;

  @override
  void dispose() {
    kilometrageCtrl.dispose();

    comNiveaux.dispose();
    comSignalisation.dispose();
    comEcranTactile.dispose();
    comSacocheBleue.dispose();
    comCabine.dispose();
    comBrancard.dispose();
    comMaterielCabine.dispose();
    comEclairageCellule.dispose();
    comPorteLaterale.dispose();
    comDivers.dispose();
    comAutoprotection.dispose();

    faireRouler.dispose();
    super.dispose();
  }

  bool _validateAll() {
    final km = int.tryParse(kilometrageCtrl.text.trim());
    final headerOk = dateVerification != null &&
        (controleur != null && controleur!.trim().isNotEmpty) &&
        km != null;

    final matricesOk =
        _validateMatrix(niveaux) &&
        _validateMatrix(signalisation) &&
        _validateMatrix(ecranTactileCabine) &&
        _validateMatrix(sacocheBleueCabine) &&
        _validateMatrix(diversCabine) &&
        _validateMatrix(brancard) &&
        _validateMatrix(materielCellule) &&
        _validateMatrix(eclairageCellule) &&
        _validateMatrix(porteLaterale) &&
        _validateMatrix(verificationAutoprotection1) &&
        _validateMatrix(verificationAutoprotection2) &&
        _validateMatrix(divers);

    final commentsOk =
        _validateText(comNiveaux) &&
        _validateText(comSignalisation) &&
        _validateText(comEcranTactile) &&
        _validateText(comSacocheBleue) &&
        _validateText(comCabine) &&
        _validateText(comBrancard) &&
        _validateText(comMaterielCabine) &&
        _validateText(comEclairageCellule) &&
        _validateText(comPorteLaterale) &&
        _validateText(comDivers);
        

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
          answers.add({'section': section, 'question': question, 'answer': value ?? ''});
        });
      }

      // Kilométrage aussi dans answers (comme tes autres forms)
      answers.add({
        'section': "KILOMÉTRAGE",
        'question': "Kilométrage",
        'answer': int.parse(kilometrageCtrl.text.trim()),
      });

      // Sections
      addSection("NIVEAUX", niveaux);
      addSection("Signalisation", signalisation);
      addSection("Ecran tactile Cabine", ecranTactileCabine);
      addSection("Sacoche bleue dans cabine", sacocheBleueCabine);
      addSection("Divers cabine", diversCabine);
      addSection("Brancard. Le sortir pour essais", brancard);
      addSection("Matériel Cellule", materielCellule);
      addSection("Eclairage cellule", eclairageCellule);
      addSection("Porte latérale", porteLaterale);
      addSection("Divers", divers);
      addSection("VÉRIFICATION AUTOPROTECTION 176", verificationAutoprotection1);
      addSection("VÉRIFICATION AUTOPROTECTION 177", verificationAutoprotection2);


      // Commentaires (section "Commentaires")
      answers.add({'section': "Commentaires", 'question': "Commentaires sur les niveaux.", 'answer': comNiveaux.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur la signalisation.", 'answer': comSignalisation.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur l'écran tactile.", 'answer': comEcranTactile.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur sacoche bleue.", 'answer': comSacocheBleue.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur la cabine.", 'answer': comCabine.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur le brancard.", 'answer': comBrancard.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur le matériel de la cabine.", 'answer': comMaterielCabine.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur l'éclairage de la cellule.", 'answer': comEclairageCellule.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur porte latérale.", 'answer': comPorteLaterale.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires divers.", 'answer': comDivers.text.trim()});
      answers.add({'section': "Commentaires", 'question': "FAIRE ROULER VLHR 10/15 minutes.", 'answer': faireRouler.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur l'autoprotection", 'answer': comAutoprotection.text.trim()});

      await FirebaseFirestore.instance.collection('vehicle_checks_submissions').add({
        'formId': VSAVFormPage.formId,
        'formTitle': VSAVFormPage.formTitle,
        'vehicle': VSAVFormPage.vehicle,
        'dateVerification': Timestamp.fromDate(dateVerification!),
        'controleur': controleur ?? '',
        'kilometrage': int.parse(kilometrageCtrl.text.trim()),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'createdByEmail': user.email ?? '',
        'answers': answers,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("VSAV enregistré ✅")),
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
      appBar: AppBar(title: const Text("VSAV")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // ================================
            // EN-TÊTE (même design que CCF176)
            // ================================
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("DATE DE LA VÉRIFICATION *",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
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

                  const Text("NOM(S) CONTRÔLEUR(S) *",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
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

                  const SizedBox(height: 16),

                  const Text("KILOMÉTRAGE *",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: kilometrageCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Ex: 110000",
                    ),
                  ),
                ]),
              ),
            ),

            // ================================
            // FORMULAIRES (même design CCF176)
            // ================================
            FormMatrix(
              title: "NIVEAUX",
              columns: const ["OK", "Niveau bas", "Complément fait"],
              values: niveaux,
              onChanged: (r, v) => setState(() => niveaux[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur les niveaux. *", controller: comNiveaux),

            FormMatrix(
              title: "Signalisation",
              columns: const ["Fonctionne", "Ne fonctionne pas", "Ampoule remplacée"],
              values: signalisation,
              onChanged: (r, v) => setState(() => signalisation[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur la signalisation. *", controller: comSignalisation),

            FormMatrix(
              title: "Ecran tactile Cabine",
              columns: const ["OK", "Ne fonctionne pas"],
              values: ecranTactileCabine,
              onChanged: (r, v) => setState(() => ecranTactileCabine[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur l'écran tactile. *", controller: comEcranTactile),

            FormMatrix(
              title: "Sacoche bleue dans cabine",
              columns: const ["OK", "Complément fait"],
              values: sacocheBleueCabine,
              onChanged: (r, v) => setState(() => sacocheBleueCabine[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur sacoche bleue. *", controller: comSacocheBleue),

            FormMatrix(
              title: "Divers cabine",
              columns: const ["OK", "Ne fonctionne pas"],
              values: diversCabine,
              onChanged: (r, v) => setState(() => diversCabine[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur la cabine. *", controller: comCabine),

            FormMatrix(
              title: "Brancard. Le sortir pour essais",
              columns: const ["OK", "Ne fonctionne pas"],
              values: brancard,
              onChanged: (r, v) => setState(() => brancard[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur le brancard. *", controller: comBrancard),

            FormMatrix(
              title: "Matériel Cellule",
              columns: const ["OK", "Ne fonctionne pas"],
              values: materielCellule,
              onChanged: (r, v) => setState(() => materielCellule[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur le matériel de la cabine. *", controller: comMaterielCabine),

            FormMatrix(
              title: "Eclairage cellule",
              columns: const ["Ok", "Ne fonctionne pas"],
              values: eclairageCellule,
              onChanged: (r, v) => setState(() => eclairageCellule[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur l'éclairage de la cellule. *", controller: comEclairageCellule),

            FormMatrix(
              title: "Porte latérale",
              columns: const ["OK", "Absence"],
              values: porteLaterale,
              onChanged: (r, v) => setState(() => porteLaterale[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur porte latérale. *", controller: comPorteLaterale),

            FormMatrix(
              title: "Divers",
              columns: const ["OK", "Mauvais état"],
              values: divers,
              onChanged: (r, v) => setState(() => divers[r] = v),
            ),
            _TextCommentCard(label: "Commentaires divers. *", controller: comDivers),

            FormMatrix(
              title: "VÉRIFICATION AUTOPROTECTION 176",
              columns: const ["OK", "HS"],
              values: verificationAutoprotection1,
              onChanged: (r, v) => setState(() => verificationAutoprotection1[r] = v),
            ),

            FormMatrix(
              title: "VÉRIFICATION AUTOPROTECTION 177",
              columns: const ["OK", "HS"],
              values: verificationAutoprotection2,
              onChanged: (r, v) => setState(() => verificationAutoprotection2[r] = v),
            ),
            _TextCommentCard(label: "Commentaire autoprotection *", controller: comAutoprotection),

            // Champ final requis (comme les autres)
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
                onPressed: _submit,
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