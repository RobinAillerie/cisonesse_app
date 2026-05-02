// lib/pages/fptl017_form.dart
//
// UI identique CCF176 (Cards + FormMatrix + _TextCommentCard)
// ⚠️ Contenu/questions inchangés (maps + libellés identiques)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // digitsOnly


import '../widgets/form_matrix.dart';

class FPTL017FormPage extends StatefulWidget {
  const FPTL017FormPage({super.key});

  static const String formId = 'FPTL_017';
  static const String formTitle = 'FPTL 017';
  static const String vehicle = 'FPTL 017';

  @override
  State<FPTL017FormPage> createState() => _FPTL017FormPageState();
}

class _FPTL017FormPageState extends State<FPTL017FormPage> {
  // ============================================================
  // LISTE CONTROLEURS
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
  String? controleurSelectionne;

  final TextEditingController kilometrageCtrl = TextEditingController();

  // ============================================================
  // Helpers validation (inchangés côté logique)
  // ============================================================
  bool _validateMatrix(Map<String, String?> map) => !map.values.any((v) => v == null);

  bool _validateText(TextEditingController c) => c.text.trim().isNotEmpty;

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  int? _parseKilometrage() {
    final raw = kilometrageCtrl.text.trim();
    if (raw.isEmpty) return null;
    final km = int.tryParse(raw);
    if (km == null) return null;
    if (km < 0) return null;
    return km;
  }

  bool vehiculeRoule = false;
  // ============================================================
  // MAPS (QUESTIONS INCHANGÉES)
  // ============================================================

  // Carburant (dans ton fichier : radio '+ de 3/4' | '- de 3/4')
  // -> on l’exprime en matrix comme sur CCF176 (1 ligne, 2 colonnes)
  final Map<String, String?> carburant = {
    "Niveau réservoir": null, // answer will be '+ de 3/4' / '- de 3/4'
  };

  final Map<String, String?> niveaux = {
    'Tonne': null,
    'Huile moteur': null,
    'Liquide refroidissement': null,
    'Liquide de frein': null,
    'Liquide de direction': null,
  };

  final Map<String, String?> signalisation = {
    'Clignotant AV D': null,
    'Clignotant AV G': null,
    'Feux de position': null,
    'Feux de croisement': null,
    'Feux de route': null,
    'Gyrophare AV': null,
    'Feux de gabarit G': null,
    'Feux de gabarit D': null,
    'Feux de position AR': null,
    'Feux STOP': null,
    'Feux de recul': null,
    'Clignotant ARG': null,
    'Clignotant ARD': null,
    'Eclairage plaque immat': null,
    'Gyrophares AR': null,
    'Rampe AR': null,
    '2 tons': null,
    'Phare de travail AR': null,
  };

  final Map<String, String?> interieurAvantCabine = {
    "1 GPS : s'allume": null,
    "1 radio : s'allume": null,
    "1 housse TPH 700": null,
    "1 plan foyer municipal": null,
    "1 plan école primaire": null,
    "1 plan ateliers municipaux": null,
    "1 plan Humuland": null,
    "1 plan camping": null,
    "1 plan maternelle/cantine": null,
    "1 plan médiathèque": null,
    "1 plan complexe sportif": null,
    "1 plan mairie": null,
    "1 plan église": null,
    "1 plan Jacquet": null,
    "1 plan Ephad": null,
    "1 plan STEP": null,
    "2 marqueurs effaçables": null,
    "2 stylos": null,
    "1 boîte lingettes": null,
    "1 boîte gaz avec:": null,
    "10 étiquettes gaz": null,
    "1 clé coffret gaz": null,
    "1 clé multis embouts": null,
    "1 pied de biche": null,
    "1 hachette": null,
    "1 carnet": null,
    "1 plaquette porte documents": null,
    "1 fiche messages": null,
    "1 fiche utilisation TPH700": null,
    "1 clé ouverture coffrets": null,
    "1 trousse à outils comprenant": null,
    "1 pince multiprises": null,
    "1 clé à molette": null,
    "1 clé à griffes": null,
    "1 tournevis mixte": null,
    "2 clés 6 pans de 14": null,
    "1 clé avec 2 embouts carrés": null,
    "6 gilets haute visibilité": null,
    "1 carte carburant": null,
    "1 polycoise": null,
    "1 rouleau rubalise": null,
  };

  final Map<String, String?> interieurArriereCabine = {
    "2 commandes": null,
    "2 sangles Rhinoévac": null,
    "2 masques araignée": null,
    "2 housses TPH 700": null,
    "4 masques ARI à griffes": null,
  };

  final Map<String, String?> coffreInterieurCabine = {
    "1 Balai": null,
    "1 Pioche": null,
    "1 Trépied métal (Pour phare AR)": null,
    "1 Triangle de signalisation": null,
    "1 Cric et la barre": null,
    "1 Clé pour les roues": null,
    "1 Fourche courbée": null,
    "1 Pince Monseigneur": null,
    "1 Hache": null,
    "1 Marteau": null,
    "1 Burin": null,
    "1 pelle": null,
  };

  final Map<String, String?> hommesMorts = {
    "Dossard N° 621": null,
    "Dossard N° 622": null,
    "Dossard N° 623": null,
    "Dossard N° 624": null,
  };

  final Map<String, String?> cornesAppels = {
    "Dossard N° 621": null,
    "Dossard N° 622": null,
    "Dossard N° 623": null,
    "Dossard N° 624": null,
  };

  // (Google Forms: grille 1 colonne OK)
  // On le garde tel quel côté contenu, mais UI en matrix 1 colonne "OK"
  final Map<String, String?> sanglesDetenduesOkMatrix = {
    "Dossard N° 621": null,
    "Dossard N° 622": null,
    "Dossard N° 623": null,
    "Dossard N° 624": null,
  };

  final Map<String, String?> bouteillesAir = {
    "Bte N°1514": null,
    "Bte N°1515": null,
    "Bte N°1516": null,
    "Bte N°1517": null,
    "Bte N°1518": null,
    "Bte N°1519": null,
    "Bte N°1520": null,
    "Bte N°1521": null,
  };

  final Map<String, String?> coffreAvConducteur = {
    "6 Tuyaux 70/20 mètres": null,
    "7 Tuyaux 45/20 mètres": null,
    "1 Ldv 500": null,
    "1 Commande": null,
    "1 Crépine avec flotteur": null,
  };

  final Map<String, String?> coffreArConducteur = {
    "2 Cales fer": null,
    "6 Cônes de Lubeck": null,
    "1 Volant pour enrouler Ldt": null,
    "1 Tuyau 110/10 mètres": null,
    "1 Tuyau 70/10 mètres": null,
    "1 Clé de poteaux": null,
    "1 Polycoise": null,
    "2 Tricoises": null,
    "1 Coude d'alimentation de 110": null,
    "1 Réducteur 65/40": null,
    "1 Réducteur 65/100": null,
    "1 Division 100/2x65": null,
    "1 Collecteur alimentation": null,
    "1 Retenue 100/2x65": null,
    "2 bouchon de 45": null,
    "2 bouchons PEI de 65": null,
    "1 bouchon PEI de 100": null,
    "1 Rallonge électrique": null,
    "Mise en service rallonge électrique": null,
    "1 Bâche": null,
    "2 obturateurs plaquettes": null,
  };

  final Map<String, String?> arriereDuFptl = {
    "2 dévidoirs": null,
    "Dévidoir G 200m tuyaux": null,
    "Dévidoir D 200m tuyaux": null,
    "Dévidoir D: 1 division mixte": null,
    "1 LDT": null,
  };

  final Map<String, String?> coffreDeToit = {
    "5 Tuyaux d'aspiration": null,
    "2 Passages de roues": null,
    "1 Fourche": null,
    "1 Clé de barrage": null,
    "6 Manches kit de ramonage": null,
    "2 Hérissons carrés": null,
    "1 Hérisson rectangulaire": null,
    "1 Hérisson rond": null,
    "1 Cordage": null,
  };

  final Map<String, String?> toit = {
    "1 Echelle à crochet": null,
    "1 Echelle à coulisse": null,
    "1 Gaffe": null,
  };

  final Map<String, String?> coffreArPassager = {
    "1 Masse": null,
    "1 Halligan tools": null,
    "1 Tuyau 70/20m avec division65/2x40": null,
    "2 Tuyaux 70/20 m échevaux": null,
    "1 Tuyau 70/20m échevaux division 65/65/2x40": null,
    "2 Tuyaux 45/20 m en échevaux": null,
    "1 Tuyau 45/20 m échevo LDV 500": null,
  };

  final Map<String, String?> coffreAvPassager = {
    "1 poche kit fumées comprenant": null,
    "1 Brosses pour textiles": null,
    "Sacs poubelles": null,
    "Savon pour les mains": null,
    "Masques FFP2": null,
    "6 Paires gants bleus": null,
    "2 Lignes guides": null,
    "2 Extincteurs à poudre": null,
    "1 Extincteur Dioxyde de carbone": null,
    "1 Lance à mousse": null,
    "1 LMF": null,
    "1 Injecteur proportionneur": null,
    "2 Bidons d'émulseur": null,
    "1 Lance queue de paon de 45": null,
    "1 LSPCC N°234.Plombé": null,
    "1 LSPCC N°235.Plombé": null,
    "1 Ldv 1000": null,
  };

  final Map<String, String?> caissePlatesOeils = {
    "6": null,
    "7": null,
    "8": null,
    "9": null,
    "10": null,
    "11": null,
    "12": null,
    "13": null,
    "14": null,
    "15": null,
    "16": null,
    "17": null,
    "18": null,
    "19": null,
    "21": null,
    "22": null,
    "23": null,
    "24": null,
  };

  final Map<String, String?> caisseCliquetsOeils = {
    "7/8": null,
    "09/10": null,
    "11/13": null,
    "15/17": null,
    "19/21": null,
  };

  final Map<String, String?> caisse6Pans = {
    "2": null,
    "2,5": null,
    "3": null,
    "2 de 4": null,
    "5": null,
    "6": null,
    "7": null,
    "8": null,
    "9": null,
    "10": null,
  };

  final Map<String, String?> caisseDouilles = {
    "8": null,
    "9": null,
    "2 de 10": null,
    "11": null,
    "12": null,
    "13": null,
    "14": null,
    "15": null,
    "16": null,
    "2 de 17": null,
    "18": null,
    "2 de 19": null,
    "21": null,
    "22": null,
    "23": null,
    "2 de 24": null,
    "25": null,
    "26": null,
    "27": null,
    "29": null,
    "30": null,
    "32": null,
  };

  final Map<String, String?> caisseDivers = {
    "1 Carré avec manche": null,
    "1 petite rallonge": null,
    "1 grande rallonge": null,
    "1 Douille articulée": null,
    "2 Marteaux": null,
    "1 Clé à molette": null,
    "1 Brosse métallique": null,
    "1 Paquet lames scie métaux": null,
    "1 Clé à cliquet": null,
    "2 Pinces circlips": null,
    "1 Pince coupante": null,
    "1 Pince becs plats": null,
    "1 Pince becs longs": null,
    "4 Tournevis plats": null,
    "1 Pince étaux": null,
    "1 Scie à métaux": null,
    "1 Pince plate": null,
    "1 Pince multiprises": null,
    "1 Burin": null,
    "4 Chasses goupilles": null,
  };

  final Map<String, String?> detecteurGaz = {
    "1 Détecteur de gaz": null,
    "En charge": null,
    "Test fonctionnement": null,
  };

  final Map<String, String?> valiseElectroSecours = {
    "1 Détecteur de tension": null,
    "Faire essai bouton test": null,
    "Faire essai sur câble électrique": null,
    "1 Paire de gants et sa sacoche": null,
    "1 Perche en 3 morceaux": null,
    "1 Pince coupante": null,
    "1 Paire de bottes": null,
    "1 Tabouret": null,
    "1 Rouleau de rubalise": null,
  };

  // (Google Forms: grille 1 colonne OK)
  final Map<String, String?> diversNettoyageOkMatrix = {
    "Nettoyage vitres": null,
    "Nettoyage rétros": null,
    "Nettoyage pare-brise": null,
    "Nettoyage extérieur véhicule": null,
  };

  final Map<String, String?> verificationAutoprotection1 = {
    "Auto protection châssis": null,
    "Auto protection cabine": null,
    "Inscrit sur main courante": null,
    "Vérification Bouteille d'air >270 B": null,
  };

  final Map<String, String?> verificationAutoprotection2 = {
    "Auto protection châssis": null,
    "Auto protection cabine": null,
    "Inscrit sur main courante": null,
    "Vérification Bouteille d'air >270 B": null,
  };
  // ============================================================
  // COMMENTAIRES (inchangés)
  // ============================================================
  final commentaireNiveauxCtrl = TextEditingController();
  final commentaireSignalisationCtrl = TextEditingController();
  final commentaireInterieurAvantCtrl = TextEditingController();
  final commentaireInterieurArriereCtrl = TextEditingController();
  final commentaireCoffreInterieurCtrl = TextEditingController();
  final commentaireHommesMortsCtrl = TextEditingController();
  final commentaireCornesCtrl = TextEditingController();
  final commentaireBouteillesAirCtrl = TextEditingController();
  final commentaireCoffreAvConducteurCtrl = TextEditingController();
  final commentaireCoffreArConducteurCtrl = TextEditingController();
  final commentaireArFptlCtrl = TextEditingController();
  final commentaireCoffreToitCtrl = TextEditingController();
  final commentaireCoffreArPassagerCtrl = TextEditingController();
  final commentaireCoffreAvPassagerCtrl = TextEditingController();
  final commentaireCaisseOutilsCtrl = TextEditingController();
  final commentaireDetecteurGazCtrl = TextEditingController();
  final commentaireValiseElectroCtrl = TextEditingController();
  final commentaireDiversCtrl = TextEditingController();
  
  final TextEditingController comAutoprotection = TextEditingController();

  @override
  void dispose() {
    kilometrageCtrl.dispose();

    commentaireNiveauxCtrl.dispose();
    commentaireSignalisationCtrl.dispose();
    commentaireInterieurAvantCtrl.dispose();
    commentaireInterieurArriereCtrl.dispose();
    commentaireCoffreInterieurCtrl.dispose();
    commentaireHommesMortsCtrl.dispose();
    commentaireCornesCtrl.dispose();
    commentaireBouteillesAirCtrl.dispose();
    commentaireCoffreAvConducteurCtrl.dispose();
    commentaireCoffreArConducteurCtrl.dispose();
    commentaireArFptlCtrl.dispose();
    commentaireCoffreToitCtrl.dispose();
    commentaireCoffreArPassagerCtrl.dispose();
    commentaireCoffreAvPassagerCtrl.dispose();
    commentaireCoffreAvPassagerCtrl.dispose();
    commentaireCaisseOutilsCtrl.dispose();
    commentaireDetecteurGazCtrl.dispose();
    commentaireValiseElectroCtrl.dispose();
    commentaireDiversCtrl.dispose();
    comAutoprotection.dispose();

    super.dispose();
  }

  // ============================================================
  // Validation stricte (identique en intention à ton fichier)
  // (ici on valide via matrices + textes + header)
  // ============================================================
  bool _validateAll() {
    final km = _parseKilometrage();

    final headerOk =
        dateVerification != null &&
        (controleurSelectionne != null && controleurSelectionne!.trim().isNotEmpty) &&
        km != null;

    final matricesOk =
        _validateMatrix(carburant) &&
        _validateMatrix(niveaux) &&
        _validateMatrix(signalisation) &&
        _validateMatrix(interieurAvantCabine) &&
        _validateMatrix(interieurArriereCabine) &&
        _validateMatrix(coffreInterieurCabine) &&
        _validateMatrix(hommesMorts) &&
        _validateMatrix(cornesAppels) &&
        _validateMatrix(sanglesDetenduesOkMatrix) &&
        _validateMatrix(bouteillesAir) &&
        _validateMatrix(coffreAvConducteur) &&
        _validateMatrix(coffreArConducteur) &&
        _validateMatrix(arriereDuFptl) &&
        _validateMatrix(coffreDeToit) &&
        _validateMatrix(toit) &&
        _validateMatrix(coffreArPassager) &&
        _validateMatrix(coffreAvPassager) &&
        _validateMatrix(caissePlatesOeils) &&
        _validateMatrix(caisseCliquetsOeils) &&
        _validateMatrix(caisse6Pans) &&
        _validateMatrix(caisseDouilles) &&
        _validateMatrix(caisseDivers) &&
        _validateMatrix(detecteurGaz) &&
        _validateMatrix(valiseElectroSecours) &&
        _validateMatrix(diversNettoyageOkMatrix)&&
        _validateMatrix(verificationAutoprotection1)&&
        _validateMatrix(verificationAutoprotection2);


    final commentsOk =
        _validateText(commentaireNiveauxCtrl) &&
        _validateText(commentaireSignalisationCtrl) &&
        _validateText(commentaireInterieurAvantCtrl) &&
        _validateText(commentaireInterieurArriereCtrl) &&
        _validateText(commentaireCoffreInterieurCtrl) &&
        _validateText(commentaireHommesMortsCtrl) &&
        _validateText(commentaireCornesCtrl) &&
        _validateText(commentaireBouteillesAirCtrl) &&
        _validateText(commentaireCoffreAvConducteurCtrl) &&
        _validateText(commentaireCoffreArConducteurCtrl) &&
        _validateText(commentaireArFptlCtrl) &&
        _validateText(commentaireCoffreToitCtrl) &&
        _validateText(commentaireCoffreArPassagerCtrl) &&
        _validateText(commentaireCoffreAvPassagerCtrl) &&
        _validateText(commentaireCaisseOutilsCtrl) &&
        _validateText(commentaireDetecteurGazCtrl) &&
        _validateText(commentaireValiseElectroCtrl) &&
        _validateText(commentaireDiversCtrl);
        

    return headerOk && matricesOk && commentsOk;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
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

  List<Map<String, dynamic>> _buildAnswers({required int kilometrage}) {
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

    answers.add({'section': "KILOMÉTRAGE", 'question': "Kilométrage", 'answer': kilometrage});

    // Sections (inchangées)
    addSection("Carburant (Si moins de 3/4 plein à faire)", carburant);
    addSection("NIVEAUX", niveaux);
    addSection("SIGNALISATION", signalisation);
    addSection("INTERIEUR AVANT DE LA CABINE", interieurAvantCabine);
    addSection("INTERIEUR ARRIERE DE LA CABINE", interieurArriereCabine);
    addSection("COFFRE INTERIEUR CABINE", coffreInterieurCabine);
    addSection("HOMMES MORTS", hommesMorts);
    addSection("CORNES D'APPELS", cornesAppels);
    addSection("SANGLES DETENDUES", sanglesDetenduesOkMatrix);
    addSection("BOUTEILLES AIR", bouteillesAir);
    addSection("COFFRE AV COTE CONDUCTEUR", coffreAvConducteur);
    addSection("COFFRE ARRIERE COTE CONDUCTEUR", coffreArConducteur);
    addSection("ARRIERE DU FPTL", arriereDuFptl);
    addSection("COFFRE DE TOIT", coffreDeToit);
    addSection("TOIT", toit);
    addSection("COFFRE ARRIERE COTE PASSAGER", coffreArPassager);
    addSection("COFFRE AV COTE PASSAGER", coffreAvPassager);
    addSection("CAISSE A OUTILS: CLES PLATES/OEILS", caissePlatesOeils);
    addSection("CAISSE A OUTILS: CLES CLIQUETS A OEILS", caisseCliquetsOeils);
    addSection("CAISSE A OUTILS: CLES 6 PANS", caisse6Pans);
    addSection("CAISSE A OUTILS: DOUILLES", caisseDouilles);
    addSection("CAISSE OUTILS: DIVERS", caisseDivers);
    addSection("DETECTEUR DE GAZ", detecteurGaz);
    addSection("VALISE ELECTRO SECOURS", valiseElectroSecours);
    addSection("DIVERS", diversNettoyageOkMatrix);
    addSection("VÉRIFICATION AUTOPROTECTION 176 ", verificationAutoprotection1);
    addSection("VÉRIFICATION AUTOPROTECTION 177", verificationAutoprotection2);

    // Commentaires (inchangés)
    answers.add({'section': "Commentaires", 'question': "Commentaire sur les niveaux", 'answer': commentaireNiveauxCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire sur la signalisation", 'answer': commentaireSignalisationCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire sur l'intérieur avant cabine", 'answer': commentaireInterieurAvantCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire sur l'intérieur arrière cabine", 'answer': commentaireInterieurArriereCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire sur coffre intérieur cabine", 'answer': commentaireCoffreInterieurCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire sur les hommes morts", 'answer': commentaireHommesMortsCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire(s) sur les cornes", 'answer': commentaireCornesCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire (s) bouteilles air", 'answer': commentaireBouteillesAirCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire sur le coffre AV côté conducteur", 'answer': commentaireCoffreAvConducteurCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire sur le coffre AR côté conducteur", 'answer': commentaireCoffreArConducteurCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire sur l'AR du FPTL", 'answer': commentaireArFptlCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire sur le coffre de toit", 'answer': commentaireCoffreToitCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire sur le coffre AR côté passager", 'answer': commentaireCoffreArPassagerCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire sur le coffre AV côté passager", 'answer': commentaireCoffreAvPassagerCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire sur la caisse outils", 'answer': commentaireCaisseOutilsCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire sur le détecteur gaz", 'answer': commentaireDetecteurGazCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire sur la valise électro secours", 'answer': commentaireValiseElectroCtrl.text.trim()});
    answers.add({'section': "Commentaires", 'question': "Commentaire divers", 'answer': commentaireDiversCtrl.text.trim()});
    answers.add({
      'section': "Commentaires",
      'question': "Faire rouler VLHR 10/15 minutes",
      'answer': vehiculeRoule ? 'Oui' : 'Non',
    });
    answers.add({'section': "Commentaires", 'question': "Commentaire autoprotection", 'answer': comAutoprotection.text.trim()});

    return answers;
  }

  Future<void> _submit() async {
    if (!_validateAll()) {
      _showIncomplete();
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final km = _parseKilometrage()!;

      await FirebaseFirestore.instance.collection('vehicle_checks_submissions').add({
        'formId': FPTL017FormPage.formId,
        'formTitle': FPTL017FormPage.formTitle,
        'vehicle': FPTL017FormPage.vehicle,
        'dateVerification': Timestamp.fromDate(dateVerification!),
        'controleur': controleurSelectionne ?? '',
        'kilometrage': km,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'createdByEmail': user.email ?? '',
        'answers': _buildAnswers(kilometrage: km),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("FPTL 017 enregistré ✅")));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text("FPTL 017")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // ================================
            // EN-TÊTE (identique 176)
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
                    initialValue: (controleurSelectionne != null && controleurSelectionne!.isNotEmpty)
                        ? controleurSelectionne
                        : null,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: CONTROLEURS.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => controleurSelectionne = v),
                  ),
                  if (CONTROLEURS.isEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      "Sélectionner votre Nom/Prénom",
                      style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
                    ),
                  ],
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
            // FORMULAIRES (FormMatrix + commentaires identiques 176)
            // ================================

            FormMatrix(
              title: "Carburant (Si moins de 3/4 plein à faire)",
              columns: const ['+ de 3/4', '- de 3/4'],
              values: carburant,
              onChanged: (r, v) => setState(() => carburant[r] = v),
            ),

            FormMatrix(
              title: "NIVEAUX",
              columns: const ['OK', 'Niveau bas', 'Complément fait'],
              values: niveaux,
              onChanged: (r, v) => setState(() => niveaux[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur les niveaux *", controller: commentaireNiveauxCtrl),

            FormMatrix(
              title: "SIGNALISATION",
              columns: const ['Fonctionne', 'Ne fonctionne pas', 'Ampoule remplacée'],
              values: signalisation,
              onChanged: (r, v) => setState(() => signalisation[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur la signalisation *", controller: commentaireSignalisationCtrl),

            FormMatrix(
              title: "INTERIEUR AVANT DE LA CABINE",
              columns: const ['OK', 'Ne fonctionne pas'],
              values: interieurAvantCabine,
              onChanged: (r, v) => setState(() => interieurAvantCabine[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur l'intérieur avant cabine *", controller: commentaireInterieurAvantCtrl),

            FormMatrix(
              title: "INTERIEUR ARRIERE DE LA CABINE",
              columns: const ['OK', 'Manque'],
              values: interieurArriereCabine,
              onChanged: (r, v) => setState(() => interieurArriereCabine[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur l'intérieur arrière cabine *", controller: commentaireInterieurArriereCtrl),

            FormMatrix(
              title: "COFFRE INTERIEUR CABINE",
              columns: const ['OK', 'Manque'],
              values: coffreInterieurCabine,
              onChanged: (r, v) => setState(() => coffreInterieurCabine[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur coffre intérieur cabine *", controller: commentaireCoffreInterieurCtrl),

            FormMatrix(
              title: "HOMMES MORTS",
              columns: const ['Fonctionne', 'HS'],
              values: hommesMorts,
              onChanged: (r, v) => setState(() => hommesMorts[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur les hommes morts *", controller: commentaireHommesMortsCtrl),

            FormMatrix(
              title: "CORNES D'APPELS",
              columns: const ['Fonctionne', 'HS'],
              values: cornesAppels,
              onChanged: (r, v) => setState(() => cornesAppels[r] = v),
            ),
            _TextCommentCard(label: "Commentaire (s) sur les cornes *", controller: commentaireCornesCtrl),

            FormMatrix(
              title: "SANGLES DETENDUES",
              columns: const ['OK'],
              values: sanglesDetenduesOkMatrix,
              onChanged: (r, v) => setState(() => sanglesDetenduesOkMatrix[r] = v),
            ),

            FormMatrix(
              title: "BOUTEILLES AIR",
              columns: const ['En réserve', 'Pression > à 270 B'],
              values: bouteillesAir,
              onChanged: (r, v) => setState(() => bouteillesAir[r] = v),
            ),
            _TextCommentCard(label: "Commentaire (s) bouteilles air *", controller: commentaireBouteillesAirCtrl),

            FormMatrix(
              title: "COFFRE AV COTE CONDUCTEUR",
              columns: const ['OK', 'Manque'],
              values: coffreAvConducteur,
              onChanged: (r, v) => setState(() => coffreAvConducteur[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur le coffre AV côté conducteur *", controller: commentaireCoffreAvConducteurCtrl),

            FormMatrix(
              title: "COFFRE ARRIERE COTE CONDUCTEUR",
              columns: const ['OK', 'Manque'],
              values: coffreArConducteur,
              onChanged: (r, v) => setState(() => coffreArConducteur[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur le coffre AR côté conducteur *", controller: commentaireCoffreArConducteurCtrl),

            FormMatrix(
              title: "ARRIERE DU FPTL",
              columns: const ['OK', 'Incomplet'],
              values: arriereDuFptl,
              onChanged: (r, v) => setState(() => arriereDuFptl[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur l'AR du FPTL *", controller: commentaireArFptlCtrl),

            FormMatrix(
              title: "COFFRE DE TOIT",
              columns: const ['OK', 'Manque'],
              values: coffreDeToit,
              onChanged: (r, v) => setState(() => coffreDeToit[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur le coffre de toit *", controller: commentaireCoffreToitCtrl),

            FormMatrix(
              title: "TOIT",
              columns: const ['OK', 'Manque'],
              values: toit,
              onChanged: (r, v) => setState(() => toit[r] = v),
            ),

            FormMatrix(
              title: "COFFRE ARRIERE COTE PASSAGER",
              columns: const ['OK', 'Manque'],
              values: coffreArPassager,
              onChanged: (r, v) => setState(() => coffreArPassager[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur le coffre AR côté passager *", controller: commentaireCoffreArPassagerCtrl),

            FormMatrix(
              title: "COFFRE AV COTE PASSAGER",
              columns: const ['OK', 'Manque'],
              values: coffreAvPassager,
              onChanged: (r, v) => setState(() => coffreAvPassager[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur le coffre AV côté passager *", controller: commentaireCoffreAvPassagerCtrl),

            // CAISSE À OUTILS (5 matrices + 1 commentaire)
            FormMatrix(
              title: "CAISSE A OUTILS: CLES PLATES/OEILS",
              columns: const ['OK', 'Manque'],
              values: caissePlatesOeils,
              onChanged: (r, v) => setState(() => caissePlatesOeils[r] = v),
            ),
            FormMatrix(
              title: "CAISSE A OUTILS: CLES CLIQUETS A OEILS",
              columns: const ['OK', 'Manque'],
              values: caisseCliquetsOeils,
              onChanged: (r, v) => setState(() => caisseCliquetsOeils[r] = v),
            ),
            FormMatrix(
              title: "CAISSE A OUTILS: CLES 6 PANS",
              columns: const ['OK', 'Manque'],
              values: caisse6Pans,
              onChanged: (r, v) => setState(() => caisse6Pans[r] = v),
            ),
            FormMatrix(
              title: "CAISSE A OUTILS: DOUILLES",
              columns: const ['OK', 'Manque'],
              values: caisseDouilles,
              onChanged: (r, v) => setState(() => caisseDouilles[r] = v),
            ),
            FormMatrix(
              title: "CAISSE OUTILS: DIVERS",
              columns: const ['OK', 'Manque'],
              values: caisseDivers,
              onChanged: (r, v) => setState(() => caisseDivers[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur la caisse outils *", controller: commentaireCaisseOutilsCtrl),

            // Partie 2
            FormMatrix(
              title: "DETECTEUR DE GAZ",
              columns: const ['OK', 'HS'],
              values: detecteurGaz,
              onChanged: (r, v) => setState(() => detecteurGaz[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur le détecteur gaz *", controller: commentaireDetecteurGazCtrl),

            FormMatrix(
              title: "VALISE ELECTRO SECOURS",
              columns: const ['OK', 'HS'],
              values: valiseElectroSecours,
              onChanged: (r, v) => setState(() => valiseElectroSecours[r] = v),
            ),
            _TextCommentCard(label: "Commentaire sur la valise électro secours *", controller: commentaireValiseElectroCtrl),

            FormMatrix(
              title: "DIVERS",
              columns: const ['OK'],
              values: diversNettoyageOkMatrix,
              onChanged: (r, v) => setState(() => diversNettoyageOkMatrix[r] = v),
            ),
            _TextCommentCard(label: "Commentaire divers *", controller: commentaireDiversCtrl),

            FormMatrix(
              title: "VÉRIFICATION AUTOPROTECTION CCF 176",
              columns: const ["OK", "HS"],
              values: verificationAutoprotection1,
              onChanged: (r, v) => setState(() => verificationAutoprotection1[r] = v),
            ),

            FormMatrix(
              title: "VÉRIFICATION AUTOPROTECTION CCF 177",
              columns: const ["OK", "HS"],
              values: verificationAutoprotection2,
              onChanged: (r, v) => setState(() => verificationAutoprotection2[r] = v),
            ),
            _TextCommentCard(label: "Commentaire autoprotection *", controller: comAutoprotection),

            // FAIRE ROULER (Card comme 176)
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