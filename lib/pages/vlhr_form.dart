// lib/pages/vlhr_form.dart
//
// Formulaire VLHR — design identique CCF176/177 (Card + FormMatrix)
// Stockage: vehicle_checks_submissions
// Champs: formId, formTitle, vehicle, dateVerification, controleur, kilometrage, createdAt, createdBy, createdByEmail, answers[]
//
// ✅ Kilométrage obligatoire (comme date + contrôleur)

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../widgets/form_matrix.dart';

class VLHRFormPage extends StatefulWidget {
  const VLHRFormPage({super.key});

  static const String formId = 'VLHR_095';
  static const String formTitle = 'VLHR 095';
  static const String vehicle = 'VLHR 095';

  @override
  State<VLHRFormPage> createState() => _VLHRFormPageState();
}

class _VLHRFormPageState extends State<VLHRFormPage> {
  // ============================================================
  // LISTE CONTROLEURS (comme les autres)
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
  // EN-TÊTE
  // ============================================================
  DateTime? dateVerification;
  String? controleur;

  final TextEditingController kilometrageCtrl = TextEditingController();

  // ============================================================
  // HELPERS
  // ============================================================
  bool _validateMatrix(Map<String, String?> map) => !map.values.any((v) => v == null);
  bool _validateText(TextEditingController c) => c.text.trim().isNotEmpty;
  bool vehiculeRoule = false;

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

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

  // ============================================================
  // SECTIONS (captures)
  // ============================================================

  // NIVEAUX
  final Map<String, String?> niveaux = {
    "Huile moteur": null,
    "Carburant": null,
    "Liquide refroidissement": null,
    "Liquide de frein": null,
    "Lave glace": null,
    "AD Blue": null,
  };

  // SIGNALISATION
  final Map<String, String?> signalisation = {
    "Clignotant AVD": null,
    "Clignotants AVG": null,
    "Feu position AVD": null,
    "Feu position AVG": null,
    "Feu croissement AVD": null,
    "Feu croissement AVG": null,
    "Feu route AVD": null,
    "Feu route AVG": null,
    "Anti brouillard AVD": null,
    "Anti brouillard AVG": null,
    "Feux AV pénétrants": null,
    "Clignotant latéral G": null,
    "Feu stop ARD": null,
    "Feu stop ARG": null,
    "Eclairage plaque immat": null,
    "Clignotant latéral D": null,
    "Gyrophare": null,
    "Feu de recul": null,
    "Bip recul": null,
    "Anti brouillard AR": null,
    "2 tons": null,
  };

  // HABITACLE
  final Map<String, String?> habitacle = {
    "Carte gas-oil": null,
    "3 marqueurs effaçables": null,
    "Pochette FDF": null,
    "1 Atlas départemental": null,
    "Atlas N°1": null,
    "Atlas N°2": null,
    "Atlas N°3": null,
    "1 carte Onesse PF": null,
    "1 lampe": null,
    "3 triangles signalisation": null,
    "1 cric": null,
    "1 clé démontage roues": null,
    "3 rallonges clé": null,
    "4 Chasubles": null,
    "2 câbles téléphone": null,
    "Protections auditives": null,
    "1 Glacière": null,
    "1 Rouleau rubalise": null,
  };

  // COFFRE ARRIERE
  final Map<String, String?> coffreArriere = {
    "Mise en service tronço": null,
    "Chaine affûtée": null,
    "Contrôl visu pantal sécu": null,
    "Contrôle visuel guêtres": null,
    "Contrôle visuel du casque": null,
    "Niveau essence bidon": null,
    "Niveau huile chaîne bidon": null,
    "2 limes avec manches": null,
    "1 clé à bougie": null,
    "1 porte lime": null,
    "Présence 2 élingues": null,
    "Etat des 2 élingues": null,
    "1 commande": null,
    "Etat de la commande": null,
    "1 jeu câbles démarrage": null,
    "1 cale de roue": null,
    "5 tuyaux de 45": null,
    "3 tuyaux de 70": null,
    "1 division 65-2X65": null,
    "1 divs 40/40-2xGFRmâle": null,
    "1 polycoise": null,
    "2 tricoises grand modèle": null,
    "1 Extincteur poudre": null,
    "Extincteur avec goupille": null,
    "Kit fumée comprenant": null,
    "1 nettoy mains": null,
    "10 masques chirurgicaux": null,
    "7 masques FFP3": null,
    "Gants PVC": null,
    "1 Coupe boulon": null,
    "1 OFD": null,
    "1 Casque anti bruit": null,
    "1 Jerrican essence": null,
    "Niveau jerrican essence": null,
  };

  // TROUSSE DE SECOURS
  final Map<String, String?> trousseSecours = {
    "2 CHUT": null,
    "4 compresses stériles": null,
    "1 triangle pour faire écharpe": null,
    "1 ciseau": null,
    "2 bandes de gaze extensible": null,
    "1 bande de crêpe": null,
    "2 paires de gants": null,
    "1 rouleau sparadrap": null,
    "1 pansement Américain": null,
  };

  // DIVERS
  final Map<String, String?> divers = {
    "Nettoyage pare-brise": null,
    "Nettoyage vitres latérales": null,
    "Nettoyage vitre AR": null,
    "Nettoyage rétroviseurs": null,
    "Nettoyage extérieur véhicule": null,
    "Essai radio Antarès": null,
    "Essai radio 80MHZ": null,
    "Lames suspension AR": null,
    "Ressorts suspension AV": null,
    "Amortisseurs (Voir si fuite)": null,
    "Fuite liquide de frein": null,
    "Fuite liquide refroidissement": null,
    "Fuite huile moteur": null,
    "Etat de la carrosserie": null,
    "Fuite huile de pont": null,
    "Fuite boite transfert": null,
    "Pression pneu AVD: 2,6B": null,
    "Etat pneu AVD": null,
    "Pression pneu AVG: 2,6B": null,
    "Etat pneu AVG": null,
    "Pression pneu ARD: 3B": null,
    "Etat pneu ARD: 3B": null,
    "Pression pneu ARG: 3B": null,
    "Etat pneu ARG": null,
    "Pression roue secours 3,5B": null,
    "Etat roue de secours": null,
  };

  // MPF
  final Map<String, String?> mpf = {
    "Niveau huile moteur": null,
    "Niveau carburant": null,
    "Mise en service ruisseau": null,
  };

  // STATION POMPAGE ATELIERS MUNICIPAUX
  final Map<String, String?> stationPompage = {
    "Mise en service pompe": null,
    "Nettoyage intérieur station": null,
  };

  // auto protection
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
  final TextEditingController comHabitacle = TextEditingController();
  final TextEditingController comCoffreAr = TextEditingController();
  final TextEditingController comTrousseSecours = TextEditingController();
  final TextEditingController comDivers = TextEditingController();
  final TextEditingController comMpf = TextEditingController();
  final TextEditingController comStationPompage = TextEditingController();
  final TextEditingController comAutoprotection = TextEditingController();

  final TextEditingController faireRoulerVlhr = TextEditingController(); // champ texte requis

  @override
  void dispose() {
    kilometrageCtrl.dispose();
    comNiveaux.dispose();
    comSignalisation.dispose();
    comHabitacle.dispose();
    comCoffreAr.dispose();
    comTrousseSecours.dispose();
    comDivers.dispose();
    comMpf.dispose();
    comStationPompage.dispose();
    comAutoprotection.dispose();
    faireRoulerVlhr.dispose();
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
        _validateMatrix(habitacle) &&
        _validateMatrix(coffreArriere) &&
        _validateMatrix(trousseSecours) &&
        _validateMatrix(divers) &&
        _validateMatrix(mpf) &&
        _validateMatrix(verificationAutoprotection1) &&
        _validateMatrix(verificationAutoprotection2) &&
        _validateMatrix(stationPompage);

    final commentsOk =
        _validateText(comNiveaux) &&
        _validateText(comSignalisation) &&
        _validateText(comHabitacle) &&
        _validateText(comCoffreAr) &&
        _validateText(comTrousseSecours) &&
        _validateText(comDivers) &&
        _validateText(comMpf) &&
        _validateText(comStationPompage) &&
        _validateText(comAutoprotection);

    return headerOk && matricesOk && commentsOk;
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

      // ✅ kilométrage dans answers + champ direct
      answers.add({
        'section': "KILOMETRAGE",
        'question': "KILOMETRAGE",
        'answer': int.parse(kilometrageCtrl.text.trim()),
      });

      // === SECTIONS ===
      addSection("NIVEAUX", niveaux);
      addSection("SIGNALISATION", signalisation);
      addSection("HABITACLE", habitacle);
      addSection("COFFRE ARRIERE", coffreArriere);
      addSection("TROUSSE DE SECOURS", trousseSecours);
      addSection("DIVERS", divers);
      addSection("MPF", mpf);
      addSection("STATION POMPAGE ATELIERS MUNICIPAUX", stationPompage);
      addSection("VÉRIFICATION AUTOPROTECTION 176", verificationAutoprotection1);
      addSection("VÉRIFICATION AUTOPROTECTION 177", verificationAutoprotection2);


      // === COMMENTAIRES ===
      answers.add({'section': "Commentaires", 'question': "Commentaires sur les niveaux.", 'answer': comNiveaux.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur la signalisation.", 'answer': comSignalisation.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur l'habitacle", 'answer': comHabitacle.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur le coffre AR.", 'answer': comCoffreAr.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur la trousse de secours", 'answer': comTrousseSecours.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires divers.", 'answer': comDivers.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur la MPF.", 'answer': comMpf.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur la station de pompage", 'answer': comStationPompage.text.trim()});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur l'autoprotection", 'answer': comAutoprotection.text.trim()});
      // Champ final
      answers.add({
        'section': "FAIRE ROULER VLHR 10/15 minutes.",
        'question': "FAIRE ROULER VLHR 10/15 minutes.",
        'answer': faireRoulerVlhr.text.trim(),
      });

      await FirebaseFirestore.instance.collection('vehicle_checks_submissions').add({
        'formId': VLHRFormPage.formId,
        'formTitle': VLHRFormPage.formTitle,
        'vehicle': VLHRFormPage.vehicle,
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
        const SnackBar(content: Text("VLHR enregistré ✅")),
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
      appBar: AppBar(title: const Text("VLHR")),
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
                  const Text("DATE DE LA VERIFICATION *",
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
                  const Text("NOM(S) CONTROLEUR(S) *",
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
                  const Text("KILOMETRAGE *",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: kilometrageCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Votre réponse",
                    ),
                  ),
                ]),
              ),
            ),

            // ================================
            // FORMULAIRES (même style que 176)
            // ================================
            FormMatrix(
              title: "NIVEAUX",
              columns: const ["OK", "Niveau bas", "Complément fait"],
              values: niveaux,
              onChanged: (r, v) => setState(() => niveaux[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur les niveaux.", controller: comNiveaux),

            FormMatrix(
              title: "SIGNALISATION",
              columns: const ["Fonctionne", "Ne fonctionne pas", "Ampoule remplacée"],
              values: signalisation,
              onChanged: (r, v) => setState(() => signalisation[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur la signalisation.", controller: comSignalisation),

            FormMatrix(
              title: "HABITACLE",
              columns: const ["OK", "Absent", "A faire"],
              values: habitacle,
              onChanged: (r, v) => setState(() => habitacle[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur l'habitacle", controller: comHabitacle),

            FormMatrix(
              title: "COFFRE ARRIERE",
              columns: const ["OK", "Ne fonctionne pas", "Mauvais état"],
              values: coffreArriere,
              onChanged: (r, v) => setState(() => coffreArriere[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur le coffre AR.", controller: comCoffreAr),

            FormMatrix(
              title: "TROUSSE DE SECOURS",
              columns: const ["OK", "Absent", "Périmé"],
              values: trousseSecours,
              onChanged: (r, v) => setState(() => trousseSecours[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur la trousse de secours", controller: comTrousseSecours),

            FormMatrix(
              title: "DIVERS",
              columns: const ["Fait", "Ne fonctionne pas", "OK"],
              values: divers,
              onChanged: (r, v) => setState(() => divers[r] = v),
            ),
            _TextCommentCard(label: "Commentaires divers.", controller: comDivers),

            FormMatrix(
              title: "MPF",
              columns: const ["OK", "Niveau bas", "Complément fait"],
              values: mpf,
              onChanged: (r, v) => setState(() => mpf[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur la MPF.", controller: comMpf),

            FormMatrix(
              title: "STATION POMPAGE ATELIERS MUNICIPAUX",
              columns: const ["OK", "Ne fonctionne pas"],
              values: stationPompage,
              onChanged: (r, v) => setState(() => stationPompage[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur la station de pompage", controller: comStationPompage),

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
            labelText: "$label *",
            border: const OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}