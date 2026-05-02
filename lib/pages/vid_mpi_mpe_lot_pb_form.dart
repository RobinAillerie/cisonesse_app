// lib/pages/vid_mpi_mpe_lot_pb_form.dart
//
// Formulaire : VID + MPI + MPE + LOT + PB
// Design identique à CCF176 (Card header + FormMatrix + cartes commentaires)
// Stockage: vehicle_checks_submissions
//
// Champs Firestore:
// formId, formTitle, vehicle, dateVerification(Timestamp), controleur,
// kilometrage (int), createdAt, createdBy, createdByEmail,
// answers: [{section, question, answer}]

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import '../widgets/form_matrix.dart';

class VidMpiMpeLotPbFormPage extends StatefulWidget {
  const VidMpiMpeLotPbFormPage({super.key});

  static const String formId = 'VID_MPI_MPE_LOT_PB';
  static const String formTitle = 'VID / MPI / MPE / LOT / PB';
  static const String vehicle = 'VID / MPI / MPE / LOT / PB';

  @override
  State<VidMpiMpeLotPbFormPage> createState() => _VidMpiMpeLotPbFormPageState();
}

class _VidMpiMpeLotPbFormPageState extends State<VidMpiMpeLotPbFormPage> {
  // ============================================================
  // LISTE CONTROLEURS (identique aux autres)
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
  // ENTÊTE (obligatoire)
  // ============================================================
  DateTime? dateVerification;
  String? controleur;

  // Kilométrage (obligatoire) -> numérique
  final TextEditingController kilometrageCtrl = TextEditingController();

  // ============================================================
  // Helpers validation
  // ============================================================
  bool _validateMatrix(Map<String, String?> map) => !map.values.any((v) => v == null);
  bool _validateText(TextEditingController c) => c.text.trim().isNotEmpty;
  bool vehiculeRoule = false;

  int? _parseKm() => int.tryParse(kilometrageCtrl.text.trim());

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  // ============================================================
  // MATRICES (questions = identiques aux captures)
  // ============================================================

  final Map<String, String?> niveaux = {
    "Carburant": null,
    "Huile moteur": null,
    "Liquide de refroidissement": null,
    "Lave glace": null,
    "Liquide de freins": null,
  };

  final Map<String, String?> signalisationVehicule = {
    "Clignotant AVG": null,
    "Clignotant latéral G": null,
    "Clignotant AVD": null,
    "Clignotants latéral D": null,
    "Feux de position AV": null,
    "Feux de croissement": null,
    "Feux de route": null,
    "Clignotants ARD": null,
    "Clignotant ARG": null,
    "Feu de position ARG": null,
    "Feu de position ARD": null,
    "Feux stop": null,
    "Feux de détresse": null,
    "Antibrouillard ARG": null,
    "Gyrophare": null,
    "2 Tons": null,
  };

  final Map<String, String?> trousseSecours = {
    "Des paires de gants": null,
    "4 Compresses stériles": null,
    "2 Bandes extensibles": null,
    "1 CHUT": null,
    "1 Sparadrap": null,
    "Sacs poubelle": null,
    "1 Couverture de survie": null,
    "1 pansement absorbant": null,
    "1 Chlorure de sodium": null,
  };

  final Map<String, String?> divers = {
    "Pression pneu AVG": null,
    "Etat pneu AVG": null,
    "Pression pneu AVD": null,
    "Etat pneus AVD": null,
    "Pression pneu ARD": null,
    "Etat pneu ARD": null,
    "Pression pneu ARG": null,
    "Etat du pneu ARG": null,
    "Pression roue secours": null,
    "Etat pneu roue secours": null,
    "Etat carrosserie": null,
    "Carte carburant": null,
    "5 Gilets signalisation": null,
    "2 Triangles de signalisation": null,
    "1 Lampe": null,
    "1 Extincteur poudre": null,
    "Nettoyage vitres": null,
    "Nettoyage rétroviseurs": null,
    "Nettoyage pare-brise": null,
    "Nettoyage extérieur véhicule": null,
  };

  final Map<String, String?> mpi = {
    "Niveau carburant": null,
    "Niveau huile moteur": null,
    "Niveau jerrican": null,
    "Essai moteur": null,
    "Allumer halogène": null,
    "1 Piquet terre": null,
    "Etat câble de terre": null,
    "Pression pneu AVG 3B": null,
    "Etat pneu G": null,
    "Pression pneu AVD 3B": null,
    "Etat pneu D": null,
    "Pression roue secours": null,
    "Etat pneu secours": null,
    "Clé de démarrage": null,
    "1 division 70 x 2 x 70": null,
    "2 tricoises": null,
    "2 cales bois": null,
    "3 tuyaux souples 70": null,
    "1 Marteau": null,
    "1 pelle": null,
    "2 tuyaux rigides 70": null,
    "1 Carré ouverture PF": null,
  };

  final Map<String, String?> mpeElectrique = {
    "Etat du câble électrique": null,
    "Etat de la corde": null,
    "Faire mise en service": null,
  };

  final Map<String, String?> mpeSdis039 = {
    "Niveau huile moteur": null,
    "Niveau carburant": null,
    "Etat filtre à air": null,
    "Mise en service": null,
  };

  final Map<String, String?> mpeCommune = {
    "Niveau huile moteur": null,
    "Niveau carburant": null,
    "Etat filtre à air": null,
    "Mise en service": null,
  };

  final Map<String, String?> lotBalisage = {
    "Mise en service 2 tri flash": null,
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
  // "FAIRE ROULER VLHR 10/15 minutes." (case FAIT)
  bool faireRoulerFait = false;

  // ============================================================
  // COMMENTAIRES (obligatoires)
  // ============================================================
  final TextEditingController comKilometrageObs = TextEditingController(); // champ KM (ta zone "Votre réponse" sous obs)
  final TextEditingController comNiveaux = TextEditingController();
  final TextEditingController comSignalisation = TextEditingController();
  final TextEditingController comTrousse = TextEditingController();
  final TextEditingController comDivers = TextEditingController();
  final TextEditingController comMpi = TextEditingController();
  final TextEditingController comMpeElec = TextEditingController();
  final TextEditingController comMpe039 = TextEditingController();
  final TextEditingController comMpeCommune = TextEditingController();
  final TextEditingController comLotBalisage = TextEditingController();
  final TextEditingController comAutoprotection = TextEditingController();

  final TextEditingController comEnsembleVerifs = TextEditingController();

  // deuxième question "FAIRE ROULER VLHR 10/15 minutes." (réponse texte)
  final TextEditingController faireRoulerTexte = TextEditingController();

  @override
  void dispose() {
    kilometrageCtrl.dispose();
    comKilometrageObs.dispose();
    comNiveaux.dispose();
    comSignalisation.dispose();
    comTrousse.dispose();
    comDivers.dispose();
    comMpi.dispose();
    comMpeElec.dispose();
    comMpe039.dispose();
    comMpeCommune.dispose();
    comLotBalisage.dispose();
    comEnsembleVerifs.dispose();
    comAutoprotection.dispose();
    faireRoulerTexte.dispose();
    super.dispose();
  }

  // ============================================================
  // Date picker
  // ============================================================
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
  // Validation globale
  // ============================================================
  bool _validateAll() {
    final km = _parseKm();

    final headerOk = dateVerification != null &&
        (controleur != null && controleur!.trim().isNotEmpty) &&
        km != null;

    final matricesOk = _validateMatrix(niveaux) &&
        _validateMatrix(signalisationVehicule) &&
        _validateMatrix(trousseSecours) &&
        _validateMatrix(divers) &&
        _validateMatrix(mpi) &&
        _validateMatrix(mpeElectrique) &&
        _validateMatrix(mpeSdis039) &&
        _validateMatrix(mpeCommune) &&
        _validateMatrix(verificationAutoprotection1) &&
        _validateMatrix(verificationAutoprotection2) &&
        _validateMatrix(lotBalisage);

    final commentsOk = _validateText(comKilometrageObs) &&
        _validateText(comNiveaux) &&
        _validateText(comSignalisation) &&
        _validateText(comTrousse) &&
        _validateText(comDivers) &&
        _validateText(comMpi) &&
        _validateText(comMpeElec) &&
        _validateText(comMpe039) &&
        _validateText(comMpeCommune) &&
        _validateText(comLotBalisage) &&
        faireRoulerFait == true &&
        _validateText(comEnsembleVerifs);
        

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

  // ============================================================
  // Submit Firestore
  // ============================================================
  Future<void> _submit() async {
    if (!_validateAll()) {
      _showIncomplete();
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final km = _parseKm()!;

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

      // KILOMETRAGE (en answers + champ direct)
      answers.add({
        'section': "KILOMETRAGE",
        'question': "Kilométrage",
        'answer': km,
      });

      answers.add({
        'section': "KILOMETRAGE",
        'question': "Observation(s)",
        'answer': comKilometrageObs.text.trim(),
      });

      // Sections
      addSection("NIVEAUX", niveaux);
      answers.add({'section': "Commentaires", 'question': "Commentaires divers sur les niveaux", 'answer': comNiveaux.text.trim()});

      addSection("SIGNALISATION DU VEHICULE", signalisationVehicule);
      answers.add({'section': "Commentaires", 'question': "Commentaires divers sur la signalisation", 'answer': comSignalisation.text.trim()});

      addSection("TROUSSE DE SECOURS", trousseSecours);
      answers.add({'section': "Commentaires", 'question': "Commentaires divers sur la trousse de secours", 'answer': comTrousse.text.trim()});

      addSection("DIVERS", divers);
      answers.add({'section': "Commentaires", 'question': "Commentaires sur DIVERS", 'answer': comDivers.text.trim()});

      addSection("MPI", mpi);
      answers.add({'section': "Commentaires", 'question': "Commentaires sur divers la MPI", 'answer': comMpi.text.trim()});

      addSection("MPE ELECTRIQUE", mpeElectrique);
      answers.add({'section': "Commentaires", 'question': "Commentaires divers sur la MPE électrique", 'answer': comMpeElec.text.trim()});

      addSection("MPE SDIS 039", mpeSdis039);
      answers.add({'section': "Commentaires", 'question': "Commentaires divers sur la MPE 039", 'answer': comMpe039.text.trim()});

      addSection("MPE COMMUNE", mpeCommune);
      answers.add({'section': "Commentaires", 'question': "Commentaires divers sur la MPE communale", 'answer': comMpeCommune.text.trim()});

      addSection("LOT BALISAGE. Mis en service 05/2022.", lotBalisage);
      answers.add({'section': "Commentaires", 'question': "Commentaires divers sur lot balisage", 'answer': comLotBalisage.text.trim()});

      addSection("VÉRIFICATION AUTOPROTECTION 176", verificationAutoprotection1);

      addSection("VÉRIFICATION AUTOPROTECTION 177", verificationAutoprotection2);
      answers.add({'section': "Commentaires", 'question': "Commentaires sur l'autoprotection", 'answer': comAutoprotection.text.trim()});
      // Faire rouler (checkbox + texte)
      answers.add({'section': "FAIRE ROULER", 'question': "FAIRE ROULER VLHR 10/15 minutes. (FAIT)", 'answer': faireRoulerFait ? "FAIT" : ""});
      answers.add({'section': "Commentaires", 'question': "Commentaires sur l'ensemble des vérifications", 'answer': comEnsembleVerifs.text.trim()});

      await FirebaseFirestore.instance.collection('vehicle_checks_submissions').add({
        'formId': VidMpiMpeLotPbFormPage.formId,
        'formTitle': VidMpiMpeLotPbFormPage.formTitle,
        'vehicle': VidMpiMpeLotPbFormPage.vehicle,
        'dateVerification': Timestamp.fromDate(dateVerification!),
        'controleur': controleur ?? '',
        'kilometrage': km, // champ direct
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'createdByEmail': user.email ?? '',
        'answers': answers,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Formulaire enregistré ✅")),
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
      appBar: AppBar(title: const Text("VID / MPI / MPE / LOT / PB")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // ================================
            // EN-TÊTE (même style que CCF176)
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

                  const SizedBox(height: 16),
                  const Text("KILOMETRAGE. *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 6),
                  const Text(
                    "Observation(s):\nProchaine vidange à 15000 kms.\nCT avant le 29/03/2028.",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: kilometrageCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Votre kilométrage (ex: 45231)",
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: comKilometrageObs,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Votre réponse (Observation(s))",
                    ),
                  ),
                ]),
              ),
            ),

            // ================================
            // FORMULAIRES
            // ================================

            FormMatrix(
              title: "NIVEAUX",
              columns: const ["OK", "Niveau bas", "Complément fait"],
              values: niveaux,
              onChanged: (r, v) => setState(() => niveaux[r] = v),
            ),
            _TextCommentCard(label: "Commentaires divers sur les niveaux *", controller: comNiveaux),

            FormMatrix(
              title: "SIGNALISATION DU VEHICULE",
              columns: const ["Fonctionne", "Ne fonctionne pas", "Ampoule remplacée"],
              values: signalisationVehicule,
              onChanged: (r, v) => setState(() => signalisationVehicule[r] = v),
            ),
            _TextCommentCard(label: "Commentaires divers sur la signalisation *", controller: comSignalisation),

            FormMatrix(
              title: "TROUSSE DE SECOURS",
              columns: const ["OK", "Périmé", "Absent"],
              values: trousseSecours,
              onChanged: (r, v) => setState(() => trousseSecours[r] = v),
            ),
            _TextCommentCard(label: "Commentaires divers sur la trousse de secours *", controller: comTrousse),

            FormMatrix(
              title: "DIVERS",
              columns: const ["OK", "Mauvais état", "Manque"],
              values: divers,
              onChanged: (r, v) => setState(() => divers[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur DIVERS *", controller: comDivers),

            FormMatrix(
              title: "MPI",
              columns: const ["OK", "Complément fait", "Mauvais état"],
              values: mpi,
              onChanged: (r, v) => setState(() => mpi[r] = v),
            ),
            _TextCommentCard(label: "Commentaires sur divers la MPI *", controller: comMpi),

            FormMatrix(
              title: "MPE ELECTRIQUE",
              columns: const ["OK", "Mauvais état"],
              values: mpeElectrique,
              onChanged: (r, v) => setState(() => mpeElectrique[r] = v),
            ),
            _TextCommentCard(label: "Commentaires divers sur la MPE électrique *", controller: comMpeElec),

            FormMatrix(
              title: "MPE SDIS 039",
              columns: const ["OK", "Mauvais état"],
              values: mpeSdis039,
              onChanged: (r, v) => setState(() => mpeSdis039[r] = v),
            ),
            _TextCommentCard(label: "Commentaires divers sur la MPE 039 *", controller: comMpe039),

            FormMatrix(
              title: "MPE COMMUNE",
              columns: const ["OK", "Mauvais état"],
              values: mpeCommune,
              onChanged: (r, v) => setState(() => mpeCommune[r] = v),
            ),
            _TextCommentCard(label: "Commentaires divers sur la MPE communale *", controller: comMpeCommune),

            FormMatrix(
              title: "LOT BALISAGE. Mis en service 05/2022.",
              columns: const ["OK", "Ne fonctionne pas"],
              values: lotBalisage,
              onChanged: (r, v) => setState(() => lotBalisage[r] = v),
            ),
            _TextCommentCard(label: "Commentaires divers sur lot balisage *", controller: comLotBalisage),

            FormMatrix(
              title: "VÉRIFICATION AUTOPROTECTION CCF 176",
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

            // FAIRE ROULER (checkbox FAIT)
            Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("FAIRE ROULER VLHR 10/15 minutes. *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: faireRoulerFait,
                    onChanged: (v) => setState(() => faireRoulerFait = (v == true)),
                    title: const Text("FAIT"),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ]),
              ),
            ),

            _TextCommentCard(label: "Commentaires sur l'ensemble des vérifications *", controller: comEnsembleVerifs),

            // Deuxième question "FAIRE ROULER..." en texte (comme ta capture)
            

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