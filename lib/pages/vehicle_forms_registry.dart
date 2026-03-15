import 'package:flutter/material.dart';

// Importe ici UNIQUEMENT les formulaires réels (pas les placeholders)
import 'ccf176_form.dart';
import 'ccf177_form.dart';
import 'fptl017_form.dart';
import 'vid_mpi_mpe_lot_pb_form.dart';
import 'vlhr_form.dart';
import 'vsav_form.dart';
/// Registry central des formulaires véhicules.
/// - Permet d'ajouter un nouveau formulaire en 1 ligne.
/// - Si un formId n'est pas présent, l'app garde le placeholder.
class VehicleFormsRegistry {
  static final Map<String, WidgetBuilder> _builders = {
    'CCF_176': (_) => const CCF176FormPage(),
    'CCF_177': (_) => const CCF177FormPage(),
    'FPTL_017': (_) => const FPTL017FormPage(),
    'VID_MPI_MPE_LOT_PB': (_) => const VidMpiMpeLotPbFormPage(),
    'VLHR_095': (_) => const VLHRFormPage(),
    'VSAV_065': (_) => const VSAVFormPage(),
    // Ajoute les suivants au fur et à mesure :
    // 'FPTL_017': (_) => const FPTL017FormPage(),
    // 'VID_MPI_MPE_LOT_PB': (_) => const VidMpiMpeLotPbFormPage(),
    // 'VLHR_095': (_) => const Vlhr095FormPage(),
    // 'VSAV_065': (_) => const Vsav065FormPage(),
  };

  static bool has(String formId) => _builders.containsKey(formId);

  static Widget build(String formId, BuildContext context) {
    final b = _builders[formId];
    if (b == null) {
      // Ne doit normalement pas être appelé si has() est false
      return const SizedBox.shrink();
    }
    return b(context);
  }
}