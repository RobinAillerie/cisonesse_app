import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/form_matrix.dart';

class RetourFdfCcf176FormPage extends StatefulWidget {
  const RetourFdfCcf176FormPage({super.key});

  @override
  State<RetourFdfCcf176FormPage> createState() => _RetourFdfCcf176FormPageState();
}

class _RetourFdfCcf176FormPageState extends State<RetourFdfCcf176FormPage> {
  static const List<String> controleurs = [
    'Aillerie R',
    'Bellegarde N',
    'Condro A',
    'Dubourg S',
    'Ducout Ma',
    'Duvignac J',
    'Etcheverry J',
    'Fernandez N',
    'Fournié B',
    'Fournie J',
    'Gauthé D',
    'Geffroy A',
    'Guyou L',
    'Lapié R',
    'Lasserre J',
    'Limouzi R',
    'Marsan S',
    'Moussu M',
    'Paillou F',
    'Sanguina D',
    'Sanguina T',
    'Tallon N',
  ];

  DateTime? dateVerification;
  String? controleur;
  bool photoPreFiltre = false;
  bool saving = false;

  final TextEditingController commentairesDiversCtrl = TextEditingController();

  final Map<String, String?> cabine = {
    'Passer la souflette': null,
    'Nettoyage commandes': null,
    'Nettoyage sur et sous les sièges': null,
    'Nettoyage sol': null,
    'Nettoyage intérieur des vitres': null,
    'Niveau carburant': null,
    'Contrôle pression bouteille air 270b mini': null,
  };

  final Map<String, String?> sousCapotMoteur = {
    'Contrôle niveau liquide refroidissement': null,
    'Contrôle niveau liquide de freins': null,
    'Contrôle niveau huile moteur': null,
    'Souffler le radiateur': null,
    'Souffler la calandre avant': null,
    'Contrôle absence fuite divers liquides': null,
    "Contrôle absence fuite d'air": null,
    'Souffler les 2 filtres à air': null,
  };

  final Map<String, String?> moteurAuxiliaire = {
    'Souffler filtre à air': null,
    'Nettoyage préfiltre à air (Voir ci-dessous)': null,
    'Contrôle niveau huile moteur': null,
    'Contrôle niveau liquide de refroidissement': null,
    'Contrôle absence fuite divers liquides': null,
  };

  final Map<String, String?> exterieur = {
    'Contrôle absence branches ou autres': null,
    'Contrôle bon branchement des lances': null,
    'Contrôle bonne fixation des lances': null,
    'Contrôle et rangement coffres': null,
    'Contrôle fontion clignotants AV et AR': null,
    'Contrôle fonction feux AV et AR': null,
    'Contrôle fonction giro': null,
    'Contrôle sous le CCF absence fuite air.': null,
    'Contrôle sous le CCF câbles arrachés': null,
    'Contrôle niveau tonne': null,
    'Contrôle état pneus (Flanc)': null,
    'Contrôle pression pneus': null,
    'Contrôle niveau mouillant': null,
    'Nettoyage filtre dosatron': null,
    'Contrôle diverses barres': null,
  };

  final Map<String, String?> verificationAutoprotection = {
    'Nettoyage filtre à sable': null,
    'Vidange fond de cuve': null,
    'Amorcer la pompe à 4 bars': null,
    "Enclencher l'autoprotection": null,
    'Diminuer pression refoulement -3B': null,
    "La pompe électrique s'enclenche": null,
  };

  final Map<String, String?> divers = {
    'Nettoyage complet au karcher': null,
    'Nettoyage pare-brise': null,
    'Nettoyage vitres': null,
    'Nettoyage rétroviseur': null,
  };

  @override
  void dispose() {
    commentairesDiversCtrl.dispose();
    super.dispose();
  }

  bool _validateMatrix(Map<String, String?> map) => !map.values.any((v) => v == null);

  bool _validateAll() {
    return dateVerification != null &&
        controleur != null &&
        _validateMatrix(cabine) &&
        _validateMatrix(sousCapotMoteur) &&
        _validateMatrix(moteurAuxiliaire) &&
        photoPreFiltre &&
        _validateMatrix(exterieur) &&
        _validateMatrix(verificationAutoprotection) &&
        _validateMatrix(divers) &&
        commentairesDiversCtrl.text.trim().isNotEmpty;
  }

  String _fmtDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: dateVerification ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (!mounted) return;
    if (picked != null) setState(() => dateVerification = picked);
  }

  void _showIncomplete() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Formulaire incomplet : merci de répondre à toutes les questions obligatoires.'),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _submit() async {
    if (!_validateAll()) {
      _showIncomplete();
      return;
    }

    setState(() => saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }

      final List<Map<String, dynamic>> answers = [];

      void addSection(String section, Map<String, String?> map) {
        map.forEach((question, answer) {
          answers.add({
            'section': section,
            'question': question,
            'answer': answer ?? '',
          });
        });
      }

      answers.add({
        'section': 'DATE DE VERIFICATION',
        'question': 'DATE DE VERIFICATION',
        'answer': _fmtDate(dateVerification!),
      });
      answers.add({
        'section': 'NOMS DES CONTROLEURS',
        'question': 'NOMS DES CONTROLEURS',
        'answer': controleur ?? '',
      });

      addSection('CABINE', cabine);
      addSection('SOUS CAPOT MOTEUR', sousCapotMoteur);
      addSection('MOTEUR AUXILIAIRE', moteurAuxiliaire);

      answers.add({
        'section': 'PHOTO PRE FILTRE',
        'question': 'Option 1',
        'answer': photoPreFiltre ? 'OK' : '',
      });

      addSection('EXTERIEUR', exterieur);
      addSection('VERIFICATION AUTO-PROTECTION', verificationAutoprotection);
      addSection('DIVERS', divers);

      answers.add({
        'section': 'COMMENTAIRES DIVERS',
        'question': 'COMMENTAIRES DIVERS',
        'answer': commentairesDiversCtrl.text.trim(),
      });

      await FirebaseFirestore.instance.collection('vehicle_checks_submissions').add({
        'formId': 'RETOUR_FDF_CCF_176',
        'formTitle': 'Retour FDF CCF 176',
        'vehicle': 'CCF 176',
        'dateVerification': Timestamp.fromDate(dateVerification!),
        'controleur': controleur ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'createdByEmail': user.email ?? '',
        'answers': answers,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retour FDF CCF 176 enregistré ✅')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (!mounted) return;
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text('VERIFICATION RETOUR FDF CCF 176')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DATE DE VERIFICATION *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(
                          dateVerification == null ? 'Choisir la date' : _fmtDate(dateVerification!),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('NOMS DES CONTROLEURS *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: controleur,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: controleurs.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => controleur = v),
                    ),
                  ],
                ),
              ),
            ),
            FormMatrix(
              title: 'CABINE',
              columns: const ['OK', 'HS'],
              values: cabine,
              onChanged: (r, v) => setState(() => cabine[r] = v),
            ),
            FormMatrix(
              title: 'SOUS CAPOT MOTEUR',
              columns: const ['OK', 'HS'],
              values: sousCapotMoteur,
              onChanged: (r, v) => setState(() => sousCapotMoteur[r] = v),
            ),
            FormMatrix(
              title: 'MOTEUR AUXILIAIRE',
              columns: const ['OK', 'HS'],
              values: moteurAuxiliaire,
              onChanged: (r, v) => setState(() => moteurAuxiliaire[r] = v),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 10, bottom: 12),
                  child: Text(
                    'PHOTO PRE FILTRE *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(
                            'assets/images/formulaires/pre_filtre_ccf176.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),

                        const SizedBox(height: 12),

                        CheckboxListTile(
                          value: photoPreFiltre,
                          onChanged: (v) =>
                              setState(() => photoPreFiltre = v ?? false),
                          title: const Text('Option 1'),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            FormMatrix(
              title: 'EXTERIEUR',
              columns: const ['OK', 'HS'],
              values: exterieur,
              onChanged: (r, v) => setState(() => exterieur[r] = v),
            ),
            FormMatrix(
              title: 'VERIFICATION AUTO-PROTECTION',
              columns: const ['OK', 'HS'],
              values: verificationAutoprotection,
              onChanged: (r, v) => setState(() => verificationAutoprotection[r] = v),
            ),
            FormMatrix(
              title: 'DIVERS',
              columns: const ['OK'],
              values: divers,
              onChanged: (r, v) => setState(() => divers[r] = v),
            ),
            _TextCommentCard(label: 'COMMENTAIRES DIVERS *', controller: commentairesDiversCtrl),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle_outline_rounded),
                label: Text(saving ? 'ENVOI...' : 'VALIDER'),
                onPressed: saving ? null : _submit,
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
