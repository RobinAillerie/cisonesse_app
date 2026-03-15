// lib/main.dart
//
// ✅ DESIGN INCHANGÉ
// ✅ FIX : "DIVERS (PDF)" + "PLANS BATIMENTS" SANS FIRESTORE (0 index, 0 Storage)
// ✅ Les PDFs sont lus depuis assets/ (gratuit) via DiversDocsData + openPdfAsset()
// ✅ Aucun changement sur le reste de l'app (actu / planning / vérifs / astreinte CIS restent Firestore)
//
// IMPORTANT :
// - Tes PDFs doivent être bien déclarés dans pubspec.yaml (assets: - assets/pdfs/)
// - Les chemins dans DiversDocsData doivent correspondre EXACTEMENT (majuscules/espaces/accents)

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'pages/vehicle_forms_registry.dart';
import 'pages/ccf176_form.dart';
import 'pages/ccf177_form.dart';
import 'pages/fptl017_form.dart';
import 'pages/vid_mpi_mpe_lot_pb_form.dart';
import 'pages/vlhr_form.dart';
import 'pages/vsav_form.dart';
// ✅ DIVERS ASSETS (gratuit)
import '../widgets/form_matrix.dart';
import 'package:excel/excel.dart' as excel;
import 'package:cisonesse_app/pages/divers/divers_docs_data.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

// PDF export (Option gratuite)
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';


final GlobalKey<NavigatorState> appNavigatorKey =
    GlobalKey<NavigatorState>();

Future<void> handleNotificationNavigation(RemoteMessage message) async {
  final context = appNavigatorKey.currentContext;
  if (context == null) return;

  final type = (message.data['type'] ?? '').toString();

  final shell = context.findAncestorStateOfType<_AppShellState>();
  if (shell == null) return;

  switch (type) {
    case 'agenda':
      shell.setSection(AppSection.planning);
      break;

    case 'vehicle_check':
      shell.setSection(AppSection.vehicleChecks);
      break;

    case 'vsav_return':
      shell.setSection(AppSection.retourInterVsav);
      break;

    case 'prompt_secours':
      shell.setSection(AppSection.sacPromptSecours);
      break;

    case 'mobilhome_reservation':
      shell.setSection(AppSection.amicaleMobilhomeReservation);
      break;

    case 'ticket':
      shell.setSection(AppSection.ticket);
      break;
  }
}


Future<void> subscribeToNotificationTopics() async {
  final messaging = FirebaseMessaging.instance;
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) return;

  await messaging.requestPermission();

  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();

  final userData = userDoc.data() ?? <String, dynamic>{};

  final notifyUtilisateurs = userData['notifyUtilisateurs'] == true;
  final notifyMobilhommes = userData['notifyMobilhommes'] == true;
  final notifyMecano = userData['notifyMecano'] == true;
  final notifySuap = userData['notifySuap'] == true;

  final adminDoc = await FirebaseFirestore.instance
      .collection('admins')
      .doc(user.uid)
      .get();

  final isAdmin = adminDoc.exists;

  if (notifyUtilisateurs) {
    await messaging.subscribeToTopic('utilisateurs');
  } else {
    await messaging.unsubscribeFromTopic('utilisateurs');
  }

  if (notifyMobilhommes) {
    await messaging.subscribeToTopic('mobilhommes');
  } else {
    await messaging.unsubscribeFromTopic('mobilhommes');
  }

  if (notifyMecano) {
    await messaging.subscribeToTopic('mecano');
  } else {
    await messaging.unsubscribeFromTopic('mecano');
  }

  if (notifySuap) {
    await messaging.subscribeToTopic('suap');
  } else {
    await messaging.unsubscribeFromTopic('suap');
  }

  if (isAdmin) {
    await messaging.subscribeToTopic('admins');
  } else {
    await messaging.unsubscribeFromTopic('admins');
  }
}

Future<void> setupNotifications() async {
  final messaging = FirebaseMessaging.instance;

  await messaging.requestPermission();

  final token = await messaging.getToken();
  debugPrint('FCM TOKEN: $token');

  FirebaseMessaging.onMessageOpenedApp.listen(
    handleNotificationNavigation,
  );

  final initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    await Future.delayed(const Duration(milliseconds: 500));
    await handleNotificationNavigation(initialMessage);
  }
}




Future<void> openPdfAsset(String assetPath, {String? filename}) async {
  final bytes = await rootBundle.load(assetPath);
  final dir = await getTemporaryDirectory();
  final fileName = filename ?? assetPath.split('/').last;
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
  await OpenFilex.open(file.path);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await subscribeToNotificationTopics();
  await initializeDateFormatting('fr_FR', null);
  

  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  runApp(const CisonesseApp());
}

Future<Uint8List> _compressToLimit(Uint8List input, {int maxBytes = 850 * 1024}) async {
  // Objectif: bytes <= ~850KB pour rester safe dans le doc Firestore
  var out = input;

  // On tente plusieurs niveaux
  const qualities = [70, 55, 45, 35, 25];
  for (final q in qualities) {
    if (out.lengthInBytes <= maxBytes) break;

    final compressed = await FlutterImageCompress.compressWithList(
      out,
      quality: q,
      format: CompressFormat.jpeg,
    );

    out = Uint8List.fromList(compressed);
  }

  return out;
}

class CisonesseApp extends StatelessWidget {
  const CisonesseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cisonesse',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      navigatorKey: appNavigatorKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr', 'FR'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF0B3D91),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F7FC),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFF4F7FC),
          foregroundColor: Colors.black87,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
        ),
        dividerTheme: const DividerThemeData(
          thickness: 1,
          color: Color(0xFFE3EAF4),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF0B3D91), width: 1.2),
          ),
        ),
      ),
      builder: (context, child) {
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
              Color(0xFFF4F7FC),
              Color(0xFFF8FAFE),
              Color(0xFFFFFFFF),
              ],
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthGate(),
    );
  }
}

/// ---------------------------------------------------------------------------
/// AUTH GATE
/// ---------------------------------------------------------------------------
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snap.data;
        if (user == null) return const LoginPage();
        return AppShell(user: user);
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// LOGIN
/// ---------------------------------------------------------------------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String? error;



  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailCtrl.text.trim(),
        password: passCtrl.text,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => error = e.message ?? 'Erreur de connexion.');
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'Erreur inconnue: $e');
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 2,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 6),
                  Text(
                    'Cisonesse',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: cs.primary),
                  ),
                  const SizedBox(height: 6),
                  Text('Connexion interne', style: TextStyle(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 18),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  if (error != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(error!, style: TextStyle(color: cs.onErrorContainer)),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: loading ? null : _login,
                      child: loading
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Se connecter'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// CHEFS D'EQUIPE
/// ---------------------------------------------------------------------------
class TeamLeaderService {
  static Future<bool> isTeamLeader(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('team_leaders')
          .doc(uid)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }
}

/// ---------------------------------------------------------------------------
/// ADMIN SERVICE
/// ---------------------------------------------------------------------------
class AdminService {
  static Future<bool> isAdmin(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('admins').doc(uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }
}

/// ---------------------------------------------------------------------------
/// APP SHELL + DRAWER
/// ---------------------------------------------------------------------------
enum AppSection {
  home,
  planning,
  fuelConsumption,
  vehicleChecks,
  amicale,
  pdfDivers,
  astreinteCis,
  ressources,
  numerosUtiles,
  retourInterVsav,
  sacPromptSecours,
  ticket,

  // Amicale
  amicaleOrganigramme,
  amicaleStatuts,
  amicaleReglementInterieur,
  amicaleCommissions,
  amicaleCrReunion,
  amicaleListe,
  amicaleMobilhommes,
  amicaleMobilhomeReservation,
  amicaleMobilhomeConsignes,
  amicaleMobilhomeReglement,

  // Divers (PDF) -> 11 sous sections (dans ton drawer)
  diversMaterielVehicules,
  diversAscenseursEphad,
  diversSupportsIncendie,
  diversSupportsSuap,
  diversSupportsFdf,
  diversProcedureBalisage,
  diversAntaresThp700,
  diversControlePfPei,
  diversOrganigrammeCis,
  diversInfosDiverses,
  diversHabillement,

  // Plans bâtiments -> 13 sous sections (noms exacts)
  plansEphadANoste,
  plansFoyerMunicipal,
  plansMaternelleCantine,
  plansTradilandesJacquet,
  plansHumoland,
  plansAteliersMunicipaux,
  plansMediatheque,
  plansStep,
  plansComplexeSportif,
  plansMairie,
  plansCamping,
  plansEglise,
  plansDomaineMalagaVandame,
}

class AppShell extends StatefulWidget {
  final User user;
  const AppShell({super.key, required this.user});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection section = AppSection.home;

  void setSection(AppSection newSection) {
    setState(() => section = newSection);
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, bool>>(
      future: () async {
        final isAdmin = await AdminService.isAdmin(widget.user.uid);
        final isTeamLeader = isAdmin
            ? false
            : await TeamLeaderService.isTeamLeader(widget.user.uid);

        return {
          'isAdmin': isAdmin,
          'isTeamLeader': isTeamLeader,
        };
      }(),
      builder: (context, snap) {
        final roles = snap.data ?? const {
          'isAdmin': false,
          'isTeamLeader': false,
        };

        final isAdmin = roles['isAdmin'] ?? false;
        final isTeamLeader = roles['isTeamLeader'] ?? false;

        return Scaffold(
          appBar: AppBar(
            title: Text(_titleFor(section)),
            actions: [
              IconButton(
                tooltip: 'Se déconnecter',
                onPressed: () => _logout(context),
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          drawer: _AppDrawer(
            current: section,
            isAdmin: isAdmin,
            isTeamLeader: isTeamLeader,
            onSelect: (s) {
              setState(() => section = s);
              Navigator.of(context).pop();
            },
            onLogout: () async {
              Navigator.of(context).pop();
              await _logout(context);
            },
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE3EAF4)),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                        color: Colors.black.withOpacity(0.05),
                      ),
                    ],
                  ),
                  child: _bodyFor(
                    section,
                    isAdmin: isAdmin,
                    isTeamLeader: isTeamLeader,
                    user: widget.user,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  String _titleFor(AppSection s) {
    switch (s) {
      case AppSection.home:
        return "Accueil";
      case AppSection.ticket:
        return "Idée / Réclamation";
      case AppSection.planning:
        return "Agenda";
      case AppSection.fuelConsumption:
        return "Consommation Carburant";
      case AppSection.numerosUtiles:
        return "Numéros utiles";
      case AppSection.vehicleChecks:
        return "Vérif véhicules";
      case AppSection.pdfDivers:
        return "Document Divers";
      case AppSection.astreinteCis:
        return "Astreinte CIS (PDF)";
      case AppSection.ressources:
        return "Ressources SDIS";
      case AppSection.retourInterVsav:
        return "Retour Inter VSAV";
      case AppSection.sacPromptSecours:
        return "Sac Prompt Secours";

      // Amicale
      case AppSection.amicale:
        return "Amicale";
      case AppSection.amicaleOrganigramme:
        return "Amicale — Organigramme";
      case AppSection.amicaleStatuts:
        return "Amicale — Statuts";
      case AppSection.amicaleReglementInterieur:
        return "Amicale — Règlement intérieur";
      case AppSection.amicaleCommissions:
        return "Amicale — Les commissions";
      case AppSection.amicaleCrReunion:
        return "Amicale — CR réunion";
      case AppSection.amicaleListe:
        return "Amicale — Liste Matériel Amicale";
      case AppSection.amicaleMobilhommes:
        return "Amicale — Mobil-homme";
      case AppSection.amicaleMobilhomeReservation:
        return "Mobil-homme — Réservation";
      case AppSection.amicaleMobilhomeConsignes:
        return "Mobil-homme — Consignes Arrivée/Départ";
      case AppSection.amicaleMobilhomeReglement:
        return "Mobil-homme — Règlement Mobil-home";

      // Divers
      case AppSection.diversMaterielVehicules:
        return "Matériel Véhicules";
      case AppSection.diversAscenseursEphad:
        return "Ascenseurs EPHAD";
      case AppSection.diversSupportsIncendie:
        return "Supports Incendie";
      case AppSection.diversSupportsSuap:
        return "Supports SUAP";
      case AppSection.diversSupportsFdf:
        return "Supports FDF";
      case AppSection.diversProcedureBalisage:
        return "Procédure balisage";
      case AppSection.diversAntaresThp700:
        return "Antares et THP 700";
      case AppSection.diversControlePfPei:
        return "Contrôle PF et PEI";
      case AppSection.diversOrganigrammeCis:
        return "Organigramme CIS";
      case AppSection.diversInfosDiverses:
        return "Infos diverses";
      case AppSection.diversHabillement:
        return "Habillement";

      // Plans
      case AppSection.plansEphadANoste:
        return "Plans — EPHAD A NOSTE";
      case AppSection.plansFoyerMunicipal:
        return "Plans — FOYER MUNICIPAL";
      case AppSection.plansMaternelleCantine:
        return "Plans — MATERNELLE et CANTINE";
      case AppSection.plansTradilandesJacquet:
        return "Plans — TRADILANDES JACQUET";
      case AppSection.plansHumoland:
        return "Plans — HUMULAND";
      case AppSection.plansAteliersMunicipaux:
        return "Plans — ATELIERS MUNICIPAUX";
      case AppSection.plansMediatheque:
        return "Plans — MEDIATHEQUE";
      case AppSection.plansStep:
        return "Plans — STEP";
      case AppSection.plansComplexeSportif:
        return "Plans — COMPLEXE SPORTIF";
      case AppSection.plansMairie:
        return "Plans — MAIRIE";
      case AppSection.plansCamping:
        return "Plans — CAMPING";
      case AppSection.plansEglise:
        return "Plans — EGLISE";
      case AppSection.plansDomaineMalagaVandame:
        return "Plans — DOMAINE DE MALAGA.VANDAME";
    }
  }

  Widget _bodyFor(AppSection s, {required bool isAdmin, required bool isTeamLeader, required User user}) {
    switch (s) {
      case AppSection.home:
        return HomeFeedPage(isAdmin: isAdmin, user: user);
      case AppSection.ticket:
        return const TicketCreatePage();
      case AppSection.planning:
        return PlanningPage(isAdmin: isAdmin || isTeamLeader, user: user);
      case AppSection.fuelConsumption:
        return FuelConsumptionPage(isAdmin: isAdmin, user: user);
      case AppSection.numerosUtiles:
        return const NumerosUtilesPage();
      case AppSection.vehicleChecks:
        return VehicleChecksPage(isAdmin: isAdmin, user: user);
      case AppSection.retourInterVsav:
        return RetourInterVsavPage(isAdmin: isAdmin, user: user);
      case AppSection.sacPromptSecours:
        return SacPromptSecoursPage(isAdmin: isAdmin, user: user);

      case AppSection.pdfDivers:
        return const _DiversAssetsHubPage();

      case AppSection.astreinteCis:
        return const _AstreinteAssetsPage();

      case AppSection.ressources:
        return const ResourcesPage();

      // ---------------------------
      // AMICALE
      // ---------------------------
      case AppSection.amicale:
        return const _AmicaleHomePage();
      case AppSection.amicaleOrganigramme:
        return const _AmicaleCategoryAssetsPage(
          title: 'Organigramme',
          items: [
            PdfItem(title: 'Organigramme', assetPath: 'assets/pdfs/amicale/organigramme.pdf'),
          ],
        );
      case AppSection.amicaleStatuts:
        return const _AmicaleCategoryAssetsPage(
          title: 'Statuts',
          items: [
            PdfItem(title: 'Statuts', assetPath: 'assets/pdfs/amicale/Statuts Onesse 2025.pdf'),
          ],
        );
      case AppSection.amicaleReglementInterieur:
        return const _AmicaleCategoryAssetsPage(
          title: 'Règlement intérieur',
          items: [
            PdfItem(title: 'Règlement intérieur', assetPath: 'assets/pdfs/amicale/Reglement Interieur 2025.pdf'),
          ],
        );
      case AppSection.amicaleCommissions:
        return const _AmicaleCategoryAssetsPage(
          title: 'Les commissions',
          items: [
            PdfItem(title: 'Les commissions', assetPath: 'assets/pdfs/amicale/Commissions.pdf'),
          ],
        );
      case AppSection.amicaleCrReunion:
        return const _AmicaleCategoryAssetsPage(
          title: 'CR réunion',
          items: [
            PdfItem(title: 'CR réunion 28/05/2025', assetPath: 'assets/pdfs/amicale/cr_reunion.pdf'),
            PdfItem(title: 'CR CA Novembre 2025', assetPath: 'assets/pdfs/amicale/CR CA Novembre 2025.pdf'),
          ],
        );
      case AppSection.amicaleListe:
        return const _AmicaleCategoryAssetsPage(
          title: 'Liste Matériel Amicale',
          items: [
            PdfItem(title: 'Liste Matériel Amicale', assetPath: 'assets/pdfs/amicale/Liste materiel AMICALE 2025.pdf'),
          ],
        );
      case AppSection.amicaleMobilhommes:
        return const _MobilhomeHomePage();
      case AppSection.amicaleMobilhomeReservation:
        return MobilhomeReservationSection(isAdmin: isAdmin, user: user);
      case AppSection.amicaleMobilhomeConsignes:
        return const _AmicaleCategoryAssetsPage(
          title: 'Consignes Arrivée / Départ',
          items: [
            PdfItem(
              title: 'Consignes ARRIVEE DEPART mobil-home 2024',
              assetPath: 'assets/pdfs/amicale/mobilhommes/Consignes ARRIVEE DEPART mobil-home 2024.pdf',
            ),
          ],
        );
      case AppSection.amicaleMobilhomeReglement:
        return const _AmicaleCategoryAssetsPage(
          title: 'Règlement Mobil-home',
          items: [
            PdfItem(
              title: 'Règlement mobil-home 2021',
              assetPath: 'assets/pdfs/amicale/mobilhommes/Règlement mobil-home 2021.pdf',
            ),
          ],
        );

      // ---------------------------
      // DIVERS
      // ---------------------------
      case AppSection.diversMaterielVehicules:
        return const _AssetsPdfsPage(title: 'Matériel Véhicules', categoryTitle: 'Matériel Véhicules');
      case AppSection.diversAscenseursEphad:
        return const _AssetsPdfsPage(title: 'Ascenseurs EPHAD', categoryTitle: 'Ascenseurs EPHAD');
      case AppSection.diversSupportsIncendie:
        return const _AssetsPdfsPage(title: 'Supports Incendie', categoryTitle: 'Supports Incendie');
      case AppSection.diversSupportsSuap:
        return const _AssetsPdfsPage(title: 'Supports SUAP', categoryTitle: 'Supports SUAP');
      case AppSection.diversSupportsFdf:
        return const _AssetsPdfsPage(title: 'Supports FDF', categoryTitle: 'Supports FDF');
      case AppSection.diversProcedureBalisage:
        return const _AssetsPdfsPage(title: 'Procédure balisage', categoryTitle: 'Procédure balisage');
      case AppSection.diversAntaresThp700:
        return const _AssetsPdfsPage(title: 'Antares et THP 700', categoryTitle: 'Antares et THP 700');
      case AppSection.diversControlePfPei:
        return const _AssetsPdfsPage(title: 'Contrôle PF et PEI', categoryTitle: 'Contrôle PF et PEI');
      case AppSection.diversOrganigrammeCis:
        return const _AssetsPdfsPage(title: 'Organigramme CIS', categoryTitle: 'Organigramme CIS');
      case AppSection.diversInfosDiverses:
        return const _AssetsPdfsPage(title: 'Infos diverses', categoryTitle: 'Infos diverses');
      case AppSection.diversHabillement:
        return const _AssetsPdfsPage(title: 'Habillement', categoryTitle: 'Habillement');

      // ---------------------------
      // PLANS
      // ---------------------------
      case AppSection.plansEphadANoste:
        return const _AssetsPlanPage(title: 'EPHAD A NOSTE', planTitle: 'EPHAD A NOSTE');
      case AppSection.plansFoyerMunicipal:
        return const _AssetsPlanPage(title: 'FOYER MUNICIPAL', planTitle: 'Foyer municipal');
      case AppSection.plansMaternelleCantine:
        return const _AssetsPlanPage(title: 'MATERNELLE et CANTINE', planTitle: 'Maternelle et cantine');
      case AppSection.plansTradilandesJacquet:
        return const _AssetsPlanPage(title: 'TRADILANDES JACQUET', planTitle: 'Tradilandes Jacquet');
      case AppSection.plansHumoland:
        return const _AssetsPlanPage(title: 'HUMULAND', planTitle: 'HUMULAND');
      case AppSection.plansAteliersMunicipaux:
        return const _AssetsPlanPage(title: 'ATELIERS MUNICIPAUX', planTitle: 'Ateliers municipaux');
      case AppSection.plansMediatheque:
        return const _AssetsPlanPage(title: 'MEDIATHEQUE', planTitle: 'Médiathèque');
      case AppSection.plansStep:
        return const _AssetsPlanPage(title: 'STEP', planTitle: 'STEP');
      case AppSection.plansComplexeSportif:
        return const _AssetsPlanPage(title: 'COMPLEXE SPORTIF', planTitle: 'COMPLEXE SPORTIF');
      case AppSection.plansMairie:
        return const _AssetsPlanPage(title: 'MAIRIE', planTitle: 'MAIRIE');
      case AppSection.plansCamping:
        return const _AssetsPlanPage(title: 'CAMPING', planTitle: 'CAMPING ONESSE');
      case AppSection.plansEglise:
        return const _AssetsPlanPage(title: 'EGLISE', planTitle: 'EGLISE');
      case AppSection.plansDomaineMalagaVandame:
        return const _AssetsPlanPage(title: 'DOMAINE DE MALAGA.VANDAME', planTitle: 'MALAGA');
    }
  }
}


class _AppDrawer extends StatefulWidget {
  final AppSection current;
  final bool isAdmin;
  final bool isTeamLeader;
  final ValueChanged<AppSection> onSelect;
  final Future<void> Function() onLogout;

  const _AppDrawer({
    required this.current,
    required this.isAdmin,
    required this.isTeamLeader,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  State<_AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<_AppDrawer> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(String label) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return label.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = widget.current;
    final isAdmin = widget.isAdmin;
    final isTeamLeader = widget.isTeamLeader;
    final onSelect = widget.onSelect;
    final onLogout = widget.onLogout;
    final searching = _query.trim().isNotEmpty;

    Widget item(AppSection s, IconData icon, String label, {bool bold = false}) {
      if (!_matches(label)) return const SizedBox.shrink();

      final selected = current == s;
      return ListTile(
        selected: selected,
        leading: Icon(icon, color: selected ? cs.primary : null),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => onSelect(s),
      );
    }

    final showDocumentDivers = !searching ||
        [
          'Document Divers',
          'Matériel Véhicules',
          'Ascenseurs EPHAD',
          'Supports Incendie',
          'Supports SUAP',
          'Supports FDF',
          'Procédure balisage',
          'Antares et THP 700',
          'Plans batiments',
          'EPHAD A NOSTE',
          'FOYER MUNICIPAL',
          'MATERNELLE et CANTINE',
          'TRADILANDES JACQUET',
          'HUMULAND',
          'ATELIERS MUNICIPAUX',
          'MEDIATHEQUE',
          'STEP',
          'COMPLEXE SPORTIF',
          'MAIRIE',
          'CAMPING',
          'EGLISE',
          'DOMAINE DE MALAGA.VANDAME',
          'Contrôle PF et PEI',
          'Organigramme CIS',
          'Infos diverses',
          'Habillement',
        ].any(_matches);

    final showPlans = !searching ||
        [
          'Plans batiments',
          'EPHAD A NOSTE',
          'FOYER MUNICIPAL',
          'MATERNELLE et CANTINE',
          'TRADILANDES JACQUET',
          'HUMULAND',
          'ATELIERS MUNICIPAUX',
          'MEDIATHEQUE',
          'STEP',
          'COMPLEXE SPORTIF',
          'MAIRIE',
          'CAMPING',
          'EGLISE',
          'DOMAINE DE MALAGA.VANDAME',
        ].any(_matches);

    final showAmicale = !searching ||
        [
          'Amicale',
          'Organigramme',
          'Statuts',
          'Règlement intérieur',
          'Les commissions',
          'CR réunion',
          'Cr CA Novembre2025',
          'Liste Matériel Amicale',
          'Mobil-homme',
          'Réservation',
          'Consignes Arrivé/Départ',
          'Réglement Mobil-home',
        ].any(_matches);

    return Drawer(
      elevation: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F7FC), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                  border: const Border(
                    top: BorderSide(color: Color(0xFFD32F2F), width: 4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                      color: Colors.black.withOpacity(0.08),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cisonesse',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isAdmin
                          ? 'Profil : Admin'
                          : isTeamLeader
                              ? 'Profil : Chef d’équipe'
                              : 'Profil : Utilisateur',
                      style: TextStyle(color: cs.onPrimaryContainer.withAlpha(204)),
                    ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'Rechercher dans le menu...',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.92),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFD32F2F),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.98),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE7EEF8)),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                            color: Colors.black.withOpacity(0.045),
                          ),
                        ],
                      ),
                      child: ListView(
                        children: [
                          item(AppSection.home, Icons.home_rounded, 'Accueil'),
                          item(AppSection.planning, Icons.event_note_rounded, 'Agenda'),
                          item(AppSection.numerosUtiles, Icons.phone_rounded, 'Numéros utiles'),
                          item(AppSection.retourInterVsav, Icons.medical_services_rounded, 'Retour Inter VSAV'),
                          item(AppSection.sacPromptSecours, Icons.emergency_rounded, 'Sac Prompt Secours'),
                          item(AppSection.ticket, Icons.campaign_rounded, 'Idée / Réclamation'),
                          item(AppSection.fuelConsumption, Icons.local_gas_station_rounded, 'Consommation Carburant'),
                          item(AppSection.vehicleChecks, Icons.fact_check_rounded, 'Vérif véhicules'),
                          item(AppSection.astreinteCis, Icons.upload_file_rounded, 'Astreinte CIS (PDF)'),
                          if (!searching) const Divider(),

                          if (showDocumentDivers)
                            ExpansionTile(
                              initiallyExpanded: searching,
                              leading: const Icon(Icons.picture_as_pdf_rounded),
                              title: const Text(
                                'Document Divers',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                              children: [
                                item(AppSection.diversMaterielVehicules, Icons.fire_truck_rounded, 'Matériel Véhicules'),
                                item(AppSection.diversAscenseursEphad, Icons.elevator_rounded, 'Ascenseurs EPHAD'),
                                item(AppSection.diversSupportsIncendie, Icons.local_fire_department_rounded, 'Supports Incendie'),
                                item(AppSection.diversSupportsSuap, Icons.medical_services_rounded, 'Supports SUAP'),
                                item(AppSection.diversSupportsFdf, Icons.forest_rounded, 'Supports FDF'),
                                item(AppSection.diversProcedureBalisage, Icons.traffic_rounded, 'Procédure balisage'),
                                item(AppSection.diversAntaresThp700, Icons.settings_input_antenna_rounded, 'Antares et THP 700'),
                                if (showPlans)
                                  Card(
                                    elevation: 0,
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(120),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ExpansionTile(
                                      initiallyExpanded: searching,
                                      leading: const Icon(Icons.map_rounded),
                                      title: const Text(
                                        'Plans batiments',
                                        style: TextStyle(fontWeight: FontWeight.w800),
                                      ),
                                      childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                                      children: [
                                        item(AppSection.plansEphadANoste, Icons.apartment_rounded, 'EPHAD A NOSTE'),
                                        item(AppSection.plansFoyerMunicipal, Icons.apartment_rounded, 'FOYER MUNICIPAL'),
                                        item(AppSection.plansMaternelleCantine, Icons.apartment_rounded, 'MATERNELLE et CANTINE'),
                                        item(AppSection.plansTradilandesJacquet, Icons.apartment_rounded, 'TRADILANDES JACQUET'),
                                        item(AppSection.plansHumoland, Icons.apartment_rounded, 'HUMULAND'),
                                        item(AppSection.plansAteliersMunicipaux, Icons.apartment_rounded, 'ATELIERS MUNICIPAUX'),
                                        item(AppSection.plansMediatheque, Icons.apartment_rounded, 'MEDIATHEQUE'),
                                        item(AppSection.plansStep, Icons.apartment_rounded, 'STEP'),
                                        item(AppSection.plansComplexeSportif, Icons.apartment_rounded, 'COMPLEXE SPORTIF'),
                                        item(AppSection.plansMairie, Icons.apartment_rounded, 'MAIRIE'),
                                        item(AppSection.plansCamping, Icons.apartment_rounded, 'CAMPING'),
                                        item(AppSection.plansEglise, Icons.apartment_rounded, 'EGLISE'),
                                        item(AppSection.plansDomaineMalagaVandame, Icons.apartment_rounded, 'DOMAINE DE MALAGA.VANDAME'),
                                      ],
                                    ),
                                  ),
                                item(AppSection.diversControlePfPei, Icons.plumbing_rounded, 'Contrôle PF et PEI'),
                                item(AppSection.diversOrganigrammeCis, Icons.account_tree_rounded, 'Organigramme CIS'),
                                item(AppSection.diversInfosDiverses, Icons.info_rounded, 'Infos diverses'),
                                item(AppSection.diversHabillement, Icons.checkroom_rounded, 'Habillement'),
                              ],
                            ),
                          if (showAmicale)
                            ExpansionTile(
                              initiallyExpanded: searching,
                              leading: const Icon(Icons.groups_rounded),
                              title: const Text(
                                'Amicale',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                              childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                              children: [
                                item(AppSection.amicaleOrganigramme, Icons.account_tree_rounded, 'Organigramme'),
                                item(AppSection.amicaleStatuts, Icons.description_rounded, 'Statuts'),
                                item(AppSection.amicaleReglementInterieur, Icons.rule_rounded, 'Règlement intérieur'),
                                item(AppSection.amicaleCommissions, Icons.diversity_3_rounded, 'Les commissions'),
                                item(AppSection.amicaleCrReunion, Icons.account_balance_wallet_outlined, 'CR réunion'),
                                item(AppSection.amicaleListe, Icons.store_mall_directory, 'Liste Matériel Amicale'),
                                Card(
                                  elevation: 0,
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(120),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ExpansionTile(
                                    leading: const Icon(Icons.holiday_village_rounded),
                                    title: const Text('Mobil-homme', style: TextStyle(fontWeight: FontWeight.w800)),
                                    childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                                    children: [
                                      item(AppSection.amicaleMobilhomeReservation, Icons.edit_calendar_rounded, 'Réservation'),
                                      item(AppSection.amicaleMobilhomeConsignes, Icons.login_rounded, 'Consignes Arrivé/Départ'),
                                      item(AppSection.amicaleMobilhomeReglement, Icons.rule_folder_rounded, 'Réglement Mobil-home'),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                          if (!searching) const Divider(),
                          item(AppSection.ressources, Icons.apps_rounded, 'Ressources SDIS', bold: true),
                          if (!searching) const Divider(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Déconnexion'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// ---------------------------------------------------------------------------
/// ✅ DIVERS (PDF) — HUB ASSETS (organisé et propre)
/// ---------------------------------------------------------------------------
class _DiversAssetsHubPage extends StatelessWidget {
  const _DiversAssetsHubPage();

  @override
  Widget build(BuildContext context) {
    final roots = DiversDocsData.buildCategories();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Documents internes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        const _InfoCard(
          title: 'Mode gratuit (assets)',
          message:
              'Les PDFs sont intégrés dans l’application (assets/pdfs/).\n'
              'Aucun Firebase Storage, aucun index Firestore.',
        ),
        const SizedBox(height: 12),
        for (final node in roots) _DocNodeCard(node: node),
      ],
    );
  }
}

class _DocNodeCard extends StatelessWidget {
  final DocNode node;
  const _DocNodeCard({required this.node});

  @override
  Widget build(BuildContext context) {
    if (node.isFolder) {
      return Card(
        elevation: 1.1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ExpansionTile(
          leading: Icon(node.icon),
          title: Text(node.title, style: const TextStyle(fontWeight: FontWeight.w900)),
          childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
          children: [
            for (final child in node.children) _DocNodeCard(node: child),
          ],
        ),
      );
    }

    return Card(
      elevation: 1.1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ExpansionTile(
        leading: Icon(node.icon),
        title: Text(node.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        childrenPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
        children: [
          if (node.items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Aucun document.'),
            )
          else
            for (final pdf in node.items)
              Card(
                elevation: 1.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf_rounded),
                  title: Text(pdf.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(pdf.assetPath, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.download_rounded),
                  onTap: () async {
                    try {
                      await openPdfAsset(pdf.assetPath);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Impossible d'ouvrir le PDF : $e")),
                      );
                    }
                  },
                ),
              ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// ✅ PAGE PDF ASSETS (catégorie simple)
/// ---------------------------------------------------------------------------
class _AssetsPdfsPage extends StatelessWidget {
  final String title;
  final String categoryTitle;

  const _AssetsPdfsPage({
    required this.title,
    required this.categoryTitle,
  });

  @override
  Widget build(BuildContext context) {
    final node = DiversDocsData.findCategoryByTitle(categoryTitle);

    final items = (node != null && !node.isFolder) ? node.items : const <PdfItem>[];

    if (node == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ErrorCard(
            title: 'Catégorie introuvable',
            message:
                'La catégorie "$categoryTitle" n’existe pas dans DiversDocsData.\n'
                'Vérifie le titre EXACT dans buildCategories().',
          ),
        ],
      );
    }

    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(title: title, message: 'Aucun document dans cette catégorie pour l’instant.'),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        ...items.map((pdf) {
          return Card(
            elevation: 1.1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: Text(pdf.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(pdf.assetPath, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.download_rounded),
              onTap: () async {
                try {
                  await openPdfAsset(pdf.assetPath);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Impossible d'ouvrir le PDF : $e")),
                  );
                }
              },
            ),
          );
        }),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// ✅ PAGE PDF ASSETS (plans batiments)
/// ---------------------------------------------------------------------------
class _AssetsPlanPage extends StatelessWidget {
  final String title;
  final String planTitle;

  const _AssetsPlanPage({
    required this.title,
    required this.planTitle,
  });

  @override
  Widget build(BuildContext context) {
    final node = DiversDocsData.findPlanByTitle(planTitle);
    final items = node?.items ?? const <PdfItem>[];

    if (node == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ErrorCard(
            title: 'Plan introuvable',
            message:
                'Le plan "$planTitle" n’existe pas dans le folder "Plans batiments" de DiversDocsData.\n'
                'Vérifie le titre EXACT dans buildCategories().',
          ),
        ],
      );
    }

    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(title: title, message: 'Aucun document dans ce plan pour l’instant.'),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        ...items.map((pdf) {
          return Card(
            elevation: 1.1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: Text(pdf.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(pdf.assetPath, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.download_rounded),
              onTap: () async {
                try {
                  await openPdfAsset(pdf.assetPath);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Impossible d'ouvrir le PDF : $e")),
                  );
                }
              },
            ),
          );
        }),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// HOME FEED (Firestore only, imageBase64)
/// ---------------------------------------------------------------------------

class _HomeDashboard extends StatelessWidget {
  const _HomeDashboard();

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _goTo(BuildContext context, AppSection section) {
    final shell = context.findAncestorStateOfType<_AppShellState>();
    shell?.setSection(section);
  }

  Future<bool> _isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final doc = await FirebaseFirestore.instance
        .collection('admins')
        .doc(user.uid)
        .get();

    return doc.exists;
  }

  String _vehicleToFormId(String vehicle) {
    switch (vehicle) {
      case 'CCF 176':
        return 'CCF_176';
      case 'CCF 177':
        return 'CCF_177';
      case 'FPTL 017':
        return 'FPTL_017';
      case 'VID MPI MPE LOT PB':
        return 'VID_MPI_MPE_LOT_PB';
      case 'VLHR 095':
        return 'VLHR_095';
      case 'VSAV 065':
        return 'VSAV_065';
      default:
        return '';
    }
  }

  String _formIdToLabel(String formId) {
    switch (formId) {
      case 'CCF_176':
        return 'CCF 176';
      case 'CCF_177':
        return 'CCF 177';
      case 'FPTL_017':
        return 'FPTL 017';
      case 'VID_MPI_MPE_LOT_PB':
        return 'VID / MPI / MPE / LOT / PB';
      case 'VLHR_095':
        return 'VLHR 095';
      case 'VSAV_065':
        return 'VSAV 065';
      default:
        return 'Non défini';
    }
  }

  void _openWeekendTargetForm(BuildContext context, String formId) {
    switch (formId) {
      case 'CCF_176':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CCF176FormPage()),
        );
        return;
      case 'CCF_177':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CCF177FormPage()),
        );
        return;
      case 'FPTL_017':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FPTL017FormPage()),
        );
        return;
      case 'VID_MPI_MPE_LOT_PB':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VidMpiMpeLotPbFormPage()),
        );
        return;
      case 'VLHR_095':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VLHRFormPage()),
        );
        return;
      case 'VSAV_065':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VSAVFormPage()),
        );
        return;
      default:
        _goTo(context, AppSection.vehicleChecks);
        return;
    }
  }

  Future<void> _openWeekendEditor(
    BuildContext context, {
      required DocumentSnapshot<Map<String, dynamic>> weekendDoc,
    }) async {
    final data = weekendDoc.data() ?? <String, dynamic>{};

    String vehicle = (data['vehicle'] ?? 'CCF 176').toString();
    String label = (data['label'] ?? 'Vérification week-end').toString();
    bool active = (data['active'] == true);

    String targetFormId = (data['targetFormId'] ?? '').toString();
    if (targetFormId.isEmpty) {
      targetFormId = _vehicleToFormId(vehicle);
    }

    DateTime start = DateTime.now();
    final startTs = data['startAt'];
    if (startTs is Timestamp) start = startTs.toDate();

    DateTime end = DateTime.now().add(const Duration(days: 2));
    final endTs = data['endAt'];
    if (endTs is Timestamp) end = endTs.toDate();

    Future<DateTime?> pickDateTime(DateTime initial) async {
      final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2024),
        lastDate: DateTime(2035),
      );
      if (date == null) return null;

      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
      );
      if (time == null) return null;

      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    if (!context.mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        final labelCtrl = TextEditingController(text: label);

        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Modifier rappel week-end'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: vehicle,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Véhicule',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'CCF 176',
                          child: Text(
                            'CCF 176',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'CCF 177',
                          child: Text(
                            'CCF 177',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'FPTL 017',
                          child: Text(
                            'FPTL 017',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'VID MPI MPE LOT PB',
                          child: Text(
                            'VID MPI MPE LOT PB',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'VLHR 095',
                          child: Text(
                            'VLHR 095',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'VSAV 065',
                          child: Text(
                            'VSAV 065',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setLocalState(() {
                            vehicle = v;
                            targetFormId = _vehicleToFormId(v);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: targetFormId.isEmpty ? null : targetFormId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Formulaire à ouvrir',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'CCF_176',
                          child: Text(
                            'CCF 176',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'CCF_177',
                          child: Text(
                            'CCF 177',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'FPTL_017',
                          child: Text(
                            'FPTL 017',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'VID_MPI_MPE_LOT_PB',
                          child: Text(
                            'VID / MPI / MPE / LOT / PB',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'VLHR_095',
                          child: Text(
                            'VLHR 095',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'VSAV_065',
                          child: Text(
                            'VSAV 065',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setLocalState(() => targetFormId = v);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: labelCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Libellé',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => label = v,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: active,
                      onChanged: (v) => setLocalState(() => active = v),
                      title: const Text('Rappel actif'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Début'),
                      subtitle: Text(DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(start)),
                      trailing: const Icon(Icons.edit_calendar_rounded),
                      onTap: () async {
                        final picked = await pickDateTime(start);
                        if (picked != null) {
                          setLocalState(() => start = picked);
                        }
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Fin'),
                      subtitle: Text(DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(end)),
                      trailing: const Icon(Icons.edit_calendar_rounded),
                      onTap: () async {
                        final picked = await pickDateTime(end);
                        if (picked != null) {
                          setLocalState(() => end = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () async {
                    await weekendDoc.reference.update({
                      'vehicle': vehicle,
                      'targetFormId': targetFormId,
                      'label': labelCtrl.text.trim(),
                      'active': active,
                      'startAt': Timestamp.fromDate(start),
                      'endAt': Timestamp.fromDate(end),
                    });

                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReminderCardWithEdit({
    required BuildContext context,
    required Widget child,
    DocumentSnapshot<Map<String, dynamic>>? weekendDoc,
  }) {
    return FutureBuilder<bool>(
      future: _isAdmin(),
      builder: (context, adminSnap) {
        final isAdmin = adminSnap.data ?? false;

        return Stack(
          children: [
            child,
            if (isAdmin)
              Positioned(
                top: 10,
                right: 10,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () async {
                      DocumentSnapshot<Map<String, dynamic>>? docToEdit = weekendDoc;

                      if (docToEdit == null) {
                        final col = FirebaseFirestore.instance.collection('weekend_verif_schedule');
                        final existing = await col.limit(1).get();

                        if (existing.docs.isNotEmpty) {
                          docToEdit = existing.docs.first;
                        } else {
                          final now = DateTime.now();
                          final created = await col.add({
                            'vehicle': 'CCF 176',
                            'targetFormId': 'CCF_176',
                            'label': 'Vérification week-end',
                            'active': false,
                            'startAt': Timestamp.fromDate(now),
                            'endAt': Timestamp.fromDate(now.add(const Duration(days: 2))),
                          });
                          final newDoc = await created.get();
                          docToEdit = newDoc;
                        }
                      }

                      if (!context.mounted) return;

                      await _openWeekendEditor(
                        context,
                        weekendDoc: docToEdit,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                            color: Colors.black.withOpacity(0.08),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.edit_rounded, size: 18),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = _dateOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    final in7Days = today.add(const Duration(days: 7));

    Widget tile({
      required IconData icon,
      required String title,
      required String value,
      required String subtitle,
      required Color tint,
    }) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFFFF), Color(0xFFF7FAFF)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE3EAF4)),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(0.05),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: tint.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: tint),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: tint)),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final eventsStream = FirebaseFirestore.instance
        .collection('events')
        .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
        .where('start', isLessThan: Timestamp.fromDate(in7Days))
        .orderBy('start', descending: false)
        .snapshots();

    final weekendReminderStream = FirebaseFirestore.instance
        .collection('weekend_verif_schedule')
        .limit(1)
        .snapshots();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.space_dashboard_rounded, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tableau de Bord',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: eventsStream,
          builder: (context, snap) {
            int todayCount = 0;
            int next7Count = 0;
            if (snap.hasData) {
              final docs = snap.data!.docs;
              next7Count = docs.length;
              for (final d in docs) {
                final ts = d.data()['start'];
                if (ts is Timestamp) {
                  final dt = ts.toDate();
                  if (!dt.isBefore(today) && dt.isBefore(tomorrow)) {
                    todayCount++;
                  }
                }
              }
            }

            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _goTo(context, AppSection.planning),
              child: tile(
                icon: Icons.event_note_rounded,
                title: 'Agenda',
                value: "$todayCount aujourd'hui",
                subtitle: "$next7Count sur 7 jours",
                tint: cs.primary,
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 560;

            final weekendReminderCard = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: weekendReminderStream,
              builder: (context, weekendSnap) {
                if (weekendSnap.hasError) {
                  return _buildReminderCardWithEdit(
                    context: context,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _goTo(context, AppSection.vehicleChecks),
                      child: tile(
                        icon: Icons.error_outline_rounded,
                        title: 'Rappel week-end',
                        value: 'Erreur Firestore',
                        subtitle: '${weekendSnap.error}',
                        tint: const Color(0xFFC62828),
                      ),
                    ),
                  );
                }

                if (!weekendSnap.hasData || weekendSnap.data!.docs.isEmpty) {
                  return _buildReminderCardWithEdit(
                    context: context,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _goTo(context, AppSection.vehicleChecks),
                      child: tile(
                        icon: Icons.weekend_rounded,
                        title: 'Rappel week-end',
                        value: 'Aucun rappel configuré',
                        subtitle: 'Clique sur le crayon pour en créer un',
                        tint: const Color(0xFF5E647B),
                      ),
                    ),
                  );
                }

                final weekendDoc = weekendSnap.data!.docs.first;
                final weekendData = weekendDoc.data();

                final isActive = weekendData['active'] == true;

                if (!isActive) {
                  return _buildReminderCardWithEdit(
                    context: context,
                    weekendDoc: weekendDoc,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _goTo(context, AppSection.vehicleChecks),
                      child: tile(
                        icon: Icons.weekend_rounded,
                        title: 'Rappel week-end',
                        value: 'Rappel désactivé',
                        subtitle: 'Active-le avec le crayon si besoin',
                        tint: const Color(0xFF5E647B),
                      ),
                    ),
                  );
                }

                final vehicle = (weekendData['vehicle'] ?? '').toString().trim();
                final label = (weekendData['label'] ?? 'Vérification week-end').toString().trim();
                String targetFormId = (weekendData['targetFormId'] ?? '').toString().trim();
                if (targetFormId.isEmpty) {
                  targetFormId = _vehicleToFormId(vehicle);
                }

                final startTs = weekendData['startAt'];
                final endTs = weekendData['endAt'];

                final DateTime? startAt = startTs is Timestamp ? startTs.toDate() : null;
                final DateTime? endAt = endTs is Timestamp ? endTs.toDate() : null;

                if (vehicle.isEmpty || startAt == null || endAt == null) {
                  return _buildReminderCardWithEdit(
                    context: context,
                    weekendDoc: weekendDoc,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _goTo(context, AppSection.vehicleChecks),
                      child: tile(
                        icon: Icons.weekend_rounded,
                        title: 'Rappel week-end',
                        value: 'Configuration invalide',
                        subtitle: 'Vérifie le véhicule et les dates',
                        tint: const Color(0xFF5E647B),
                      ),
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('vehicle_checks_submissions')
                      .where('formTitle', isEqualTo: vehicle)
                      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startAt))
                      .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endAt))
                      .limit(1)
                      .snapshots(),
                  builder: (context, checkSnap) {
                    final alreadyDone =
                        checkSnap.hasData && checkSnap.data != null && checkSnap.data!.docs.isNotEmpty;

                    if (alreadyDone) {
                      return _buildReminderCardWithEdit(
                        context: context,
                        weekendDoc: weekendDoc,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _openWeekendTargetForm(context, targetFormId),
                          child: tile(
                            icon: Icons.task_alt_rounded,
                            title: 'Rappel week-end',
                            value: '$vehicle vérifié',
                            subtitle: 'Contrôle effectué ce week-end',
                            tint: const Color(0xFF2E7D32),
                          ),
                        ),
                      );
                    }

                    final endText = DateFormat('dd/MM HH:mm', 'fr_FR').format(endAt);
                    final formLabel = _formIdToLabel(targetFormId);

                    return _buildReminderCardWithEdit(
                      context: context,
                      weekendDoc: weekendDoc,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _openWeekendTargetForm(context, targetFormId),
                        child: tile(
                          icon: Icons.warning_amber_rounded,
                          title: 'Rappel week-end',
                          value: vehicle,
                          subtitle: '$label • $formLabel • avant le $endText',
                          tint: const Color(0xFFB26A00),
                        ),
                      ),
                    );
                  },
                );
              },
            );

            if (isNarrow) {
              return Column(
                children: [
                  const SizedBox(height: 12),
                  weekendReminderCard,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: weekendReminderCard),
                const SizedBox(width: 12),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PinnedMessageCard extends StatelessWidget {
  final bool isAdmin;
  final User user;

  const _PinnedMessageCard({
    required this.isAdmin,
    required this.user,
  });

  Future<void> _editPinnedMessage(BuildContext context, Map<String, dynamic>? currentData) async {
    final titleCtrl = TextEditingController(text: (currentData?['title'] ?? '').toString());
    final bodyCtrl = TextEditingController(text: (currentData?['body'] ?? '').toString());
    bool isActive = currentData?['isActive'] == true;
    String? error;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Message important épinglé'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Titre',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile.adaptive(
                      value: isActive,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Afficher le message'),
                      onChanged: saving
                          ? null
                          : (v) {
                              setLocal(() => isActive = v);
                            },
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final title = titleCtrl.text.trim();
                          final body = bodyCtrl.text.trim();

                          if (title.isEmpty && body.isEmpty) {
                            setLocal(() => error = 'Renseigne au moins un titre ou un message.');
                            return;
                          }

                          setLocal(() {
                            saving = true;
                            error = null;
                          });

                          try {
                            await FirebaseFirestore.instance
                                .collection('app_settings')
                                .doc('pinned_message')
                                .set({
                              'title': title,
                              'body': body,
                              'isActive': isActive,
                              'updatedAt': FieldValue.serverTimestamp(),
                              'updatedBy': user.uid,
                            }, SetOptions(merge: true));

                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                          } catch (e) {
                            setLocal(() => error = 'Erreur : $e');
                          } finally {
                            setLocal(() => saving = false);
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('app_settings')
          .doc('pinned_message')
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final isActive = data?['isActive'] == true;
        final title = (data?['title'] ?? '').toString().trim();
        final body = (data?['body'] ?? '').toString().trim();

        if (!isActive && !isAdmin) {
          return const SizedBox.shrink();
        }

        if (!isActive && isAdmin) {
          return Card(
            elevation: 1.2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.push_pin_outlined, color: cs.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Aucun message épinglé actif.',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _editPinnedMessage(context, data),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Configurer'),
                  ),
                ],
              ),
            ),
          );
        }

        if (title.isEmpty && body.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 1.4,
          color: const Color(0xFFFFF4F4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFFFFD6D6)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.push_pin_rounded, color: Color(0xFFD32F2F)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title.isEmpty ? 'Information importante' : title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Color(0xFFB71C1C),
                        ),
                      ),
                    ),
                    if (isAdmin)
                      IconButton(
                        tooltip: 'Modifier',
                        onPressed: () => _editPinnedMessage(context, data),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                  ],
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    body,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class HomeFeedPage extends StatefulWidget {
  final bool isAdmin;
  final User user;
  const HomeFeedPage({super.key, required this.isAdmin, required this.user});

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  final ImagePicker _picker = ImagePicker();

  Future<Uint8List?> _pickImageBytes(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final raw = await picked.readAsBytes();
    final compressed = await _compressToLimit(raw); // ✅
    return compressed;
  }

  Future<void> _createPostDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _CreatePostDialog(
        userUid: widget.user.uid,
        pickImageBytes: _pickImageBytes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 170,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primaryContainer,
                      Color.alphaBlend(
                        cs.primary.withOpacity(0.08),
                      Colors.white,
                      ),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: cs.outlineVariant.withOpacity(0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                      color: Colors.black.withOpacity(0.05),
                    ),
                  ],
                ),
                child: Stack(
                  children: [

    // TITRE
                    Positioned(
                      left: 20,
                      top: 18,
                      right: 20,
                      child: Text(
                        'Infos internes CIS',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      top: 54,
                      right: 20,
                      child: Text(
                        'Tableau de bord interne',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer.withOpacity(0.75),
                        ),
                      ),
                    ),

    // LOGO CENTRÉ
                    Center(
                      child: Opacity(
                        opacity: 0.1,
                        child: Image.asset(
                          'assets/logo.PNG',
                          height: 140,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    // TEXTE BAS
                    Positioned(
                      left: 20,
                      bottom: 18,
                      right: 20,
                      child: Text(
                        'Bienvenue sur l’application du CIS Onesse',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: cs.onPrimaryContainer.withAlpha(200),
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            const _HomeDashboard(),
            const SizedBox(height: 16),
            _PinnedMessageCard(
              isAdmin: widget.isAdmin,
              user: widget.user,
            ),
            const SizedBox(height: 16),
            Text(
              'Fil d’actualité',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('news_posts')
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _ErrorCard(
                    title: 'Erreur Firestore',
                    message: 'Impossible de charger le fil d’actualité.\nDétails: ${snap.error}',
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
                }

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const _InfoCard(title: 'Aucune actu', message: 'Les posts apparaîtront ici.');
                }

                return Column(
                  children: docs.map((d) {
                    final data = d.data();
                    final title = (data['title'] ?? '').toString();
                    final body = (data['body'] ?? '').toString();
                    final imageBase64 = (data['imageBase64'] ?? '').toString();
                    final important = (data['important'] == true);

                    DateTime? createdAt;
                    final ts = data['createdAt'];
                    if (ts is Timestamp) createdAt = ts.toDate();

                    Uint8List? bytes;
                    if (imageBase64.trim().isNotEmpty) {
                      try {
                        bytes = base64Decode(imageBase64);
                      } catch (_) {
                        bytes = null;
                      }
                    }

                    final headerRow = Row(
                      children: [
                        Expanded(
                          child: (title.trim().isNotEmpty)
                              ? Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))
                              : const Text('Actu', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        ),
                        if (important)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: cs.errorContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'IMPORTANT',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: cs.onErrorContainer,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    );

                    return Card(
                      elevation: important ? 2.2 : 1.5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (bytes != null && bytes.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: Image.memory(
                                    bytes,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      child: const Center(child: Icon(Icons.broken_image_rounded)),
                                    ),
                                  ),
                                ),
                              ),
                            if (bytes != null && bytes.isNotEmpty) const SizedBox(height: 10),
                            headerRow,
                            if (body.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(body),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (createdAt != null)
                                  Expanded(
                                    child: Text(
                                      DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(createdAt),
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ),
                                  )
                                else
                                  const Spacer(),
                                if (widget.isAdmin)
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    icon: const Icon(Icons.delete_outline_rounded),
                                    onPressed: () async {
                                      final ok = await _confirmDelete(context, 'Supprimer cette actu ?');
                                      if (ok != true) return;
                                      await FirebaseFirestore.instance.collection('news_posts').doc(d.id).delete();
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
        if (widget.isAdmin)
          Positioned(
            right: 18,
            bottom: 18,
            child: FloatingActionButton.extended(
              onPressed: _createPostDialog,
              icon: const Icon(Icons.add_a_photo_rounded),
              label: const Text('Publier'),
            ),
          ),
      ],
    );
  }
}

/// Dialog création actu (Stateful + lifecycle propre)
class _CreatePostDialog extends StatefulWidget {
  final String userUid;
  final Future<Uint8List?> Function(ImageSource) pickImageBytes;

  const _CreatePostDialog({required this.userUid, required this.pickImageBytes});

  @override
  State<_CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<_CreatePostDialog> {
  late final TextEditingController titleCtrl;
  late final TextEditingController bodyCtrl;

  Uint8List? pickedBytes;
  bool important = false;

  bool saving = false;
  String? error;

  bool closing = false;

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController();
    bodyCtrl = TextEditingController();
  }



  @override
  void dispose() {
    titleCtrl.dispose();
    bodyCtrl.dispose();
    super.dispose();
  }

  void safeSet(VoidCallback fn) {
    if (!mounted || closing) return;
    setState(fn);
  }

  void closeSafely() {
    if (!mounted || closing) return;
    closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> pick(ImageSource src) async {
    if (!mounted || closing || saving) return;
    final bytes = await widget.pickImageBytes(src);
    if (!mounted || closing) return;
    if (bytes != null && bytes.isNotEmpty) {
      safeSet(() => pickedBytes = bytes);
    }
  }

  Future<void> publish() async {
    if (saving || closing) return;

    safeSet(() {
      saving = true;
      error = null;
    });

    try {
      final title = titleCtrl.text.trim();
      final body = bodyCtrl.text.trim();

      String imageBase64 = '';
      if (pickedBytes != null && pickedBytes!.isNotEmpty) {
        final b = pickedBytes!;
        if (b.lengthInBytes > 850 * 1024) {
          safeSet(() {
            error = "Image trop lourde. Essaie de recadrer ou une autre photo.";
          });
          safeSet(() => saving = false);
          return;
        }
        imageBase64 = base64Encode(b);
      }

      await FirebaseFirestore.instance.collection('news_posts').add({
        'title': title,
        'body': body,
        'imageBase64': imageBase64, // ✅ String (jamais null)
        'important': important,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.userUid,
      });

      closeSafely();
    } on FirebaseException catch (e) {
      if (!mounted || closing) return;
      safeSet(() => error = "Erreur (${e.code}) : ${e.message ?? ''}");
    } catch (e) {
      if (!mounted || closing) return;
      safeSet(() => error = "Erreur inconnue : $e");
    } finally {
      if (!mounted || closing) return;
      safeSet(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle actu'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Titre (optionnel)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bodyCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Texte (optionnel)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              value: important,
              onChanged: saving ? null : (v) => safeSet(() => important = v),
              title: const Text('Actu importante'),
              subtitle: const Text('Affichage avec badge / style spécial'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : () => pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Galerie'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: saving ? null : () => pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('Caméra'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (pickedBytes != null && pickedBytes!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.memory(
                    pickedBytes!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Center(child: Icon(Icons.broken_image_rounded)),
                    ),
                  ),
                ),
              )
            else
              const Text('Ajoute une image (optionnel).', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 10),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: (saving || closing) ? null : closeSafely,
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: (saving || closing) ? null : publish,
          child: saving
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Publier'),
        ),
      ],
    );
  }
}

Future<bool?> _confirmDelete(BuildContext context, String title) async {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: const Text('Cette action est irréversible.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
      ],
    ),
  );
}

/// ---------------------------------------------------------------------------
/// PLANNING
/// ---------------------------------------------------------------------------
class PlanningPage extends StatefulWidget {
  final bool isAdmin;
  final User user;
  const PlanningPage({super.key, required this.isAdmin, required this.user});

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime selectedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _prevMonth() {
    setState(() {
      month = DateTime(month.year, month.month - 1, 1);
      selectedDay = _dateOnly(selectedDay);
    });
  }

  void _nextMonth() {
    setState(() {
      month = DateTime(month.year, month.month + 1, 1);
      selectedDay = _dateOnly(selectedDay);
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthStart = month;
    final monthEnd = DateTime(month.year, month.month + 1, 1);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Agenda',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              if (widget.isAdmin)
                FilledButton.icon(
                  onPressed: () async {
                    await showDialog(
                      context: context,
                      builder: (_) => AddEventDialog(adminUid: widget.user.uid),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
                  .where('start', isLessThan: Timestamp.fromDate(monthEnd))
                  .orderBy('start', descending: false)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return _ErrorCard(
                    title: 'Erreur Firestore',
                    message: 'Impossible de charger le planning.\nDétails: ${snap.error}',
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(),
                  );
                }

                final docs = snap.data!.docs;

                final Map<DateTime, List<_EventLite>> byDay = {};

                  for (final d in docs) {
                    final data = d.data();

                    final startTs = data['start'];
                    final endTs = data['end'];

                    final start = startTs is Timestamp ? startTs.toDate() : null;
                    final end = endTs is Timestamp ? endTs.toDate() : null;

                    final title = (data['title'] ?? '').toString();
                    if (start == null) continue;

                    // si end est null, on considère un événement ponctuel (même jour)
                    final realEnd = end ?? start;

                    final color = (data['color'] is int) ? (data['color'] as int) : 0xFF0B3D91;
                    final createdBy = (data['createdBy'] ?? '').toString();

                    final event = _EventLite(
                      id: d.id,
                      title: title,
                      start: start,
                      end: realEnd,
                      color: color,
                      createdBy: createdBy,
                    );

                     // ✅ Répartir sur chaque jour entre start et end (inclus)
                    DateTime cur = _dateOnly(start);
                    final DateTime last = _dateOnly(realEnd);

                    // sécurité si end < start
                    final DateTime lastSafe = last.isBefore(cur) ? cur : last;

                    while (!cur.isAfter(lastSafe)) {
                      byDay.putIfAbsent(cur, () => []);
                      byDay[cur]!.add(event);
                      cur = cur.add(const Duration(days: 1));
                      cur = _dateOnly(cur);
                    }
                    for (final entry in byDay.entries) {
                      entry.value.sort((a, b) => a.start.compareTo(b.start));
                    }
                  }

                return Column(
                  children: [
                    _MonthCalendar(
                      month: month,
                      selectedDay: selectedDay,
                      hasEvents: (day) => (byDay[_dateOnly(day)]?.isNotEmpty ?? false),
                      dayDotColor: (day) {
                        final list = byDay[_dateOnly(day)];
                        if (list == null || list.isEmpty) return null;
                        return Color(list.first.color);
                      },
                      onPrevMonth: _prevMonth,
                      onNextMonth: _nextMonth,
                      onSelectDay: (d) => setState(() => selectedDay = _dateOnly(d)),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: _DayEventsList(
                        day: selectedDay,
                        events: byDay[_dateOnly(selectedDay)] ?? const [],
                        isAdmin: widget.isAdmin,
                        currentUid: widget.user.uid,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EventLite {
  final String id;
  final String title;
  final DateTime start;
  final DateTime? end;
  final int color;
  final String createdBy;

  const _EventLite({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.color,
    required this.createdBy,
  });
}

class _DayEventsList extends StatelessWidget {
  final DateTime day;
  final List<_EventLite> events;
  final bool isAdmin;
  final String currentUid;
  const _DayEventsList({required this.day, required this.events, required this.isAdmin, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    final dStr = DateFormat('EEEE dd/MM/yyyy', 'fr_FR').format(day);

    if (events.isEmpty) {
      return _InfoCard(title: dStr, message: 'Aucun événement ce jour-là.');
    }

    DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

    return ListView.separated(
      itemCount: events.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              dStr,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          );
        }

        final e = events[i - 1];

        // ✅ Affichage intelligent pour événements multi-jours
        final dayOnly = _dateOnly(day);
        final startDay = _dateOnly(e.start);
        final endDay = _dateOnly(e.end ?? e.start);

        String subtitle;

        if (startDay == endDay) {
          // même jour
          final s = DateFormat('HH:mm', 'fr_FR').format(e.start);
          final en = DateFormat('HH:mm', 'fr_FR').format(e.end ?? e.start);
          subtitle = '$s → $en';
        } else {
          // multi-jours
          final s = DateFormat('dd/MM HH:mm', 'fr_FR').format(e.start);
          final en = DateFormat('dd/MM HH:mm', 'fr_FR').format(e.end ?? e.start);

          if (dayOnly.isAfter(startDay) && dayOnly.isBefore(endDay)) {
            subtitle = 'En cours ($s → $en)';
          } else {
            subtitle = '$s → $en';
          }
        }

        final canManage = isAdmin || (e.createdBy.isNotEmpty && e.createdBy == currentUid);

        return Card(
          elevation: 1.2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ListTile(
            leading: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: Color(e.color), shape: BoxShape.circle),
            ),
            title: Text(e.title.isEmpty ? 'Événement' : e.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(subtitle),
            trailing: canManage
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Modifier',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (_) => AddEventDialog(
                              adminUid: currentUid,
                              eventId: e.id,
                              initialTitle: e.title,
                              initialStart: e.start,
                              initialEnd: e.end ?? e.start,
                              initialColor: e.color,
                            ),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () async {
                          final ok = await _confirmDelete(context, 'Supprimer cet événement ?');
                          if (ok != true) return;
                          await FirebaseFirestore.instance.collection('events').doc(e.id).delete();
                        },
                      ),
                    ],
                  )
                : null,
          ),
        );
      },
    );
  }
}

/// Calendrier visuel : petit point en bas si events (plus d'overflow)
class _MonthCalendar extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDay;
  final bool Function(DateTime day) hasEvents;
  final Color? Function(DateTime day) dayDotColor;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onSelectDay;

  const _MonthCalendar({
    required this.month,
    required this.selectedDay,
    required this.hasEvents,
    required this.dayDotColor,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onSelectDay,
  });

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final firstOfMonth = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final firstWeekday = firstOfMonth.weekday;
    final leadingEmpty = (firstWeekday + 6) % 7; // monday-start 0..6

    final cells = <DateTime?>[];
    for (int i = 0; i < leadingEmpty; i++) {
      cells.add(null);
    }
    for (int d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(month.year, month.month, d));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final monthLabel = DateFormat('MMMM yyyy', 'fr_FR').format(month);
    final monthTitle = monthLabel[0].toUpperCase() + monthLabel.substring(1);

    return Card(
      elevation: 1.2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(onPressed: onPrevMonth, icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(
                  child: Text(
                    monthTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                IconButton(onPressed: onNextMonth, icon: const Icon(Icons.chevron_right_rounded)),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Expanded(child: Center(child: Text('L', style: TextStyle(fontWeight: FontWeight.w800)))),
                Expanded(child: Center(child: Text('M', style: TextStyle(fontWeight: FontWeight.w800)))),
                Expanded(child: Center(child: Text('M', style: TextStyle(fontWeight: FontWeight.w800)))),
                Expanded(child: Center(child: Text('J', style: TextStyle(fontWeight: FontWeight.w800)))),
                Expanded(child: Center(child: Text('V', style: TextStyle(fontWeight: FontWeight.w800)))),
                Expanded(child: Center(child: Text('S', style: TextStyle(fontWeight: FontWeight.w800)))),
                Expanded(child: Center(child: Text('D', style: TextStyle(fontWeight: FontWeight.w800)))),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, idx) {
                final day = cells[idx];
                if (day == null) return const SizedBox.shrink();

                final isSelected = _dateOnly(day) == _dateOnly(selectedDay);
                final has = hasEvents(day);
                final dotColor = dayDotColor(day) ?? cs.primary;

                return InkWell(
                  onTap: () => onSelectDay(day),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primaryContainer : cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSelected ? cs.primary : cs.outlineVariant),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
                            ),
                          ),
                        ),
                        if (has)
                          Positioned(
                            bottom: 6,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AddEventDialog extends StatefulWidget {
  final String adminUid;
  final String? eventId;
  final String? initialTitle;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final int? initialColor;
  const AddEventDialog({super.key, required this.adminUid, this.eventId, this.initialTitle, this.initialStart, this.initialEnd, this.initialColor});

  @override
  State<AddEventDialog> createState() => _AddEventDialogState();
}

class _AddEventDialogState extends State<AddEventDialog> {
  final titleCtrl = TextEditingController();
  DateTime? start;
  DateTime? end;
  String? error;
  bool saving = false;

  int selectedColor = 0xFF0B3D91;

  @override
  void initState() {
    super.initState();
    titleCtrl.text = widget.initialTitle ?? '';
    start = widget.initialStart;
    end = widget.initialEnd;
    selectedColor = widget.initialColor ?? selectedColor;
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime? initial) async {
    final now = DateTime.now();
    final init = initial ?? now;

    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDate: DateTime(init.year, init.month, init.day),
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(init),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    final title = titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => error = 'Le nom de l’événement est obligatoire.');
      return;
    }
    if (start == null) {
      setState(() => error = 'Choisis une date/heure de début.');
      return;
    }
    if (end == null) {
      setState(() => error = 'Choisis une date/heure de fin.');
      return;
    }
    if (end!.isBefore(start!)) {
      setState(() => error = 'La fin doit être après le début.');
      return;
    }

    setState(() {
      saving = true;
      error = null;
    });

    try {
      final payload = {
        'title': title,
        'start': Timestamp.fromDate(start!),
        'end': Timestamp.fromDate(end!),
        'color': selectedColor,
        'createdBy': widget.adminUid,
      };
      if (widget.eventId == null) {
        await FirebaseFirestore.instance.collection('events').add({
          ...payload,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseFirestore.instance.collection('events').doc(widget.eventId).update(payload);
      }
      if (mounted) Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => error = "Erreur (${e.code}) : ${e.message ?? ''}");
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'Impossible d’enregistrer : $e');
    } finally {
      if (!mounted) return;
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(widget.eventId == null ? 'Ajouter un événement' : 'Modifier un événement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'Nom de l’événement *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            _ColorsRow(
              selected: selectedColor,
              onPick: (c) => setState(() => selectedColor = c),
            ),
            const SizedBox(height: 12),
            _DateTimeField(
              label: 'Début *',
              value: start,
              onPick: () async {
                final dt = await _pickDateTime(context, start);
                if (!mounted) return;
                if (dt != null) setState(() => start = dt);
              },
            ),
            const SizedBox(height: 12),
            _DateTimeField(
              label: 'Fin *',
              value: end,
              onPick: () async {
                final dt = await _pickDateTime(context, end ?? start);
                if (!mounted) return;
                if (dt != null) setState(() => end = dt);
              },
            ),
            const SizedBox(height: 10),
            if (error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(error!, style: TextStyle(color: cs.onErrorContainer)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: saving
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _ColorsRow extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onPick;

  const _ColorsRow({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final colors = <int>[
      0xFF0B3D91,
      0xFF2E7D32,
      0xFFC62828,
      0xFF6A1B9A,
      0xFFEF6C00,
      0xFF00838F,
      0xFF424242,
    ];

    return Row(
      children: [
        const Text('Couleur', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: colors.map((c) {
              final isSel = c == selected;
              return InkWell(
                onTap: () => onPick(c),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: isSel ? 3 : 1,
                      color: isSel ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onPick;

  const _DateTimeField({required this.label, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final txt = value == null ? 'Choisir…' : DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(value!);

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_month_rounded),
        ),
        child: Text(txt),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// VEHICLE CHECKS (Formulaires intégrés + historique admin + export PDF)
/// ---------------------------------------------------------------------------
class VehicleChecksPage extends StatelessWidget {
  final bool isAdmin;
  final User user;
  const VehicleChecksPage({super.key, required this.isAdmin, required this.user});

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      const Tab(text: 'Faire une vérif'),
      if (isAdmin) const Tab(text: 'Vérifs effectuées'),
    ];
    final views = <Widget>[
      VehicleChecksMenu(user: user),
      if (isAdmin) const AdminChecksByVehicle(),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(tabs: tabs),
          ),
          Expanded(child: TabBarView(children: views)),
        ],
      ),
    );
  }
}

/// Onglet 1 : Menu 6 formulaires
class VehicleChecksMenu extends StatelessWidget {
  final User user;
  const VehicleChecksMenu({super.key, required this.user});

  static const forms = <VehicleFormMeta>[
    VehicleFormMeta(id: 'CCF_176', title: 'CCF 176', subtitle: 'EA-449-MH'),
    VehicleFormMeta(id: 'CCF_177', title: 'CCF 177', subtitle: 'EA-385-MH'),
    VehicleFormMeta(id: 'FPTL_017', title: 'FPTL 017', subtitle: '472 PM 40'),
    VehicleFormMeta(id: 'VID_MPI_MPE_LOT_PB', title: 'VID MPI MPE LOT PB', subtitle: 'Lot PB'),
    VehicleFormMeta(id: 'VLHR_095', title: 'VLHR 095', subtitle: 'MPF / Station pompage atelier'),
    VehicleFormMeta(id: 'VSAV_065', title: 'VSAV 065', subtitle: 'EB-449-BR'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Vérifs véhicules',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        const _InfoCard(
          title: 'Historique automatique',
          message:
              'Les vérifs sont remplies dans l’app et enregistrées automatiquement.\n'
              'Les admins peuvent consulter et exporter en PDF.',
        ),
        const SizedBox(height: 12),
        ...forms.map((f) {
          return Card(
            elevation: 1.1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: const Icon(Icons.fact_check_rounded),
              title: Text(f.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(f.subtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                final hasRealForm = VehicleFormsRegistry.has(f.id);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) {
                      if (hasRealForm) {
                        return VehicleFormsRegistry.build(f.id, ctx);
                      }
                      return PlaceholderFormPage(meta: f, user: user);
                    },
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

class VehicleFormMeta {
  final String id;
  final String title;
  final String subtitle;
  const VehicleFormMeta({required this.id, required this.title, required this.subtitle});
}

/// Page placeholder (à remplacer par les 6 formulaires exacts)
class PlaceholderFormPage extends StatefulWidget {
  final VehicleFormMeta meta;
  final User user;
  const PlaceholderFormPage({super.key, required this.meta, required this.user});

  @override
  State<PlaceholderFormPage> createState() => _PlaceholderFormPageState();
}

class _PlaceholderFormPageState extends State<PlaceholderFormPage> {
  final nameCtrl = TextEditingController();
  bool saving = false;
  String? error;


  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      saving = true;
      error = null;
    });

    try {
      await FirebaseFirestore.instance.collection('vehicle_checks_submissions').add({
        'formId': widget.meta.id,
        'formTitle': widget.meta.title,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.user.uid,
        'createdByEmail': widget.user.email ?? '',
        'answers': [
          {'section': 'Général', 'question': 'Nom / Prénom', 'answer': nameCtrl.text.trim()},
        ],
      });

      if (!mounted) return;

      nameCtrl.clear();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vérif enregistrée.')));
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => error = "Erreur (${e.code}) : ${e.message ?? ''}");
    } catch (e) {
      if (!mounted) return;
      setState(() => error = 'Erreur : $e');
    } finally {
      if (!mounted) return;
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(widget.meta.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(
            title: 'Placeholder',
            message:
                'Cette page est un test pour valider l’historique + export PDF.\n'
                'Ensuite on remplace par le formulaire ${widget.meta.title} 100% identique.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Nom / Prénom', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          if (error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(12)),
              child: Text(error!, style: TextStyle(color: cs.onErrorContainer)),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: saving ? null : _submit,
              icon: const Icon(Icons.check_rounded),
              label: saving ? const Text('Envoi...') : const Text('Valider'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Onglet 2 (Admin) : vérifs effectuées, séparées par véhicule
class AdminChecksByVehicle extends StatelessWidget {
  const AdminChecksByVehicle({super.key});

  static const vehicles = <VehicleFormMeta>[
    VehicleFormMeta(id: 'CCF_176', title: 'CCF 176', subtitle: ''),
    VehicleFormMeta(id: 'CCF_177', title: 'CCF 177', subtitle: ''),
    VehicleFormMeta(id: 'FPTL_017', title: 'FPTL 017', subtitle: ''),
    VehicleFormMeta(id: 'VID_MPI_MPE_LOT_PB', title: 'VID MPI MPE LOT PB', subtitle: ''),
    VehicleFormMeta(id: 'VLHR_095', title: 'VLHR 095', subtitle: ''),
    VehicleFormMeta(id: 'VSAV_065', title: 'VSAV 065', subtitle: ''),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('vehicle_checks_submissions')
          .orderBy('createdAt', descending: true)
          .limit(300)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorCard(title: 'Erreur Firestore', message: '${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> byVehicle = {
          for (final v in vehicles) v.id: <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        };

        for (final d in docs) {
          final formId = (d.data()['formId'] ?? '').toString();
          if (byVehicle.containsKey(formId)) {
            byVehicle[formId]!.add(d);
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Vérifs effectuées',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...vehicles.map((v) {
              final list = byVehicle[v.id] ?? const [];
              return Card(
                elevation: 1.1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: ExpansionTile(
                  title: Text(v.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${list.length} vérif(s)'),
                  children: [
                    if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Aucune vérif enregistrée.'),
                      ),
                    for (final d in list) _AdminCheckTile(doc: d),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _AdminCheckTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _AdminCheckTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = (data['formTitle'] ?? 'Vérif').toString();
    final email = (data['createdByEmail'] ?? '').toString();

    DateTime? createdAt;
    final ts = data['createdAt'];
    if (ts is Timestamp) createdAt = ts.toDate();

    final subtitle = [
      if (createdAt != null) DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(createdAt),
      if (email.isNotEmpty) email,
    ].join(' • ');

    return ListTile(
      leading: const Icon(Icons.description_outlined),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminCheckDetailPage(doc: doc),
          ),
        );
      },
    );
  }
}

class AdminCheckDetailPage extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const AdminCheckDetailPage({super.key, required this.doc});

  List<Map<String, dynamic>> _answers() {
    final data = doc.data();
    final raw = data['answers'];
    if (raw is List) {
      final out = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is Map) {
          out.add(item.map((k, v) => MapEntry(k.toString(), v)));
        }
      }
      return out;
    }
    return const [];
  }

  static String _answerToString(dynamic v) {
    if (v == null) return '(vide)';
    if (v is bool) return v ? 'Oui' : 'Non';
    if (v is List) return v.isEmpty ? '(vide)' : v.map((e) => e.toString()).join(', ');
    final s = v.toString().trim();
    return s.isEmpty ? '(vide)' : s;
  }

  Future<void> _exportPdf() async {
    final data = doc.data();
    final formTitle = (data['formTitle'] ?? 'Vérification').toString();
    final createdByEmail = (data['createdByEmail'] ?? '').toString();

    DateTime? createdAt;
    final ts = data['createdAt'];
    if (ts is Timestamp) createdAt = ts.toDate();

    final answers = _answers();

    final Map<String, List<Map<String, dynamic>>> bySection = {};
    for (final a in answers) {
      final sec = (a['section'] ?? 'Général').toString();
      bySection.putIfAbsent(sec, () => []);
      bySection[sec]!.add(a);
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Text(formTitle, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('ID: ${doc.id}'),
          if (createdAt != null) pw.Text('Date: ${DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(createdAt)}'),
          if (createdByEmail.isNotEmpty) pw.Text('Email: $createdByEmail'),
          pw.SizedBox(height: 12),
          for (final entry in bySection.entries) ...[
            pw.Text(entry.key, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Divider(),
            for (final a in entry.value) ...[
              pw.Text((a['question'] ?? '').toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(_answerToString(a['answer'])),
              pw.SizedBox(height: 8),
            ],
            pw.SizedBox(height: 10),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final formTitle = (data['formTitle'] ?? 'Vérif').toString();
    final answers = _answers();

    return Scaffold(
      appBar: AppBar(
        title: Text(formTitle),
        actions: [
          IconButton(
            tooltip: 'Exporter PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1.1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text('Submission: ${doc.id}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 12),
          ...answers.map((a) {
            final section = (a['section'] ?? '').toString();
            final q = (a['question'] ?? '').toString();
            final ans = _answerToString(a['answer']);

            return Card(
              elevation: 1.1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ListTile(
                title: Text(q, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(ans),
                trailing: section.isEmpty ? null : Text(section),
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// PDF HUB (Firestore -> liens) : inchangé
/// ---------------------------------------------------------------------------
class PdfHubPage extends StatefulWidget {
  final String collection;
  final String title;
  final bool allowAdminAdd;

  const PdfHubPage({
    super.key,
    required this.collection,
    required this.title,
    this.allowAdminAdd = false,
  });

  @override
  State<PdfHubPage> createState() => _PdfHubPageState();
}

class _PdfHubPageState extends State<PdfHubPage> {
  Future<void> _addPdf() async {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (context, setLocal) {
        return AlertDialog(
          title: const Text('Ajouter un PDF (lien)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Titre', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'URL PDF', border: OutlineInputBorder()),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ]
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            FilledButton(
              onPressed: () async {
                final t = titleCtrl.text.trim();
                final u = urlCtrl.text.trim();
                if (t.isEmpty || u.isEmpty) {
                  setLocal(() => error = 'Titre et URL obligatoires.');
                  return;
                }
                await FirebaseFirestore.instance.collection(widget.collection).add({
                  'title': t,
                  'url': u,
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Ajouter'),
            )
          ],
        );
      }),
    );

    titleCtrl.dispose();
    urlCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(widget.collection).orderBy('createdAt', descending: true).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: _ErrorCard(title: 'Erreur Firestore', message: 'Impossible de charger les PDFs.\n${snap.error}'),
          );
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snap.data!.docs;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ),
                if (widget.allowAdminAdd)
                  FilledButton.icon(
                    onPressed: _addPdf,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter'),
                  )
              ],
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const _InfoCard(
                title: 'Aucun document',
                message: 'Ajoute un doc dans Firestore (title + url).',
              ),
            ...docs.map((d) {
              final data = d.data();
              final t = (data['title'] ?? '').toString();
              final u = (data['url'] ?? '').toString();
              return Card(
                elevation: 1.1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf_rounded),
                  title: Text(t, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(u, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: () async {
                    final uri = Uri.tryParse(u);
                    if (uri == null) return;
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// RESSOURCES
/// ---------------------------------------------------------------------------
class ResourcesPage extends StatelessWidget {
  const ResourcesPage({super.key});

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      ('PICA', 'https://pica.sdis40.fr/'),
      ('Cartogip', 'https://connexion.cartogip.fr/'),
      ('Outlook', 'https://outlook.office.com'),
      ('APIS', 'https://www.plateforme-apis.fr/'),
      ('SDIS40', 'https://www.sdis40.fr/'),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Ressources',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        ...items.map((e) {
          return Card(
            elevation: 1.1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: const Icon(Icons.link_rounded),
              title: Text(e.$1, style: const TextStyle(fontWeight: FontWeight.w900)),
              trailing: const Icon(Icons.open_in_new_rounded),
              onTap: () => _open(e.$2),
            ),
          );
        }),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// UI helpers
/// ---------------------------------------------------------------------------

class FuelConsumptionPage extends StatelessWidget {
  final bool isAdmin;
  final User user;
  const FuelConsumptionPage({super.key, required this.isAdmin, required this.user});

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      const Tab(text: 'Faire une conso'),
      if (isAdmin) const Tab(text: 'Consos effectuées'),
      if (isAdmin) const Tab(text: 'Tableau carburant'),
    ];
    final views = <Widget>[
      FuelConsumptionFormPage(user: user),
      if (isAdmin) const AdminFuelConsumptionsPage(),
      if (isAdmin) const FuelConsumptionTablePage(),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(tabs: tabs),
          ),
          Expanded(child: TabBarView(children: views)),
        ],
      ),
    );
  }
}

class FuelConsumptionFormPage extends StatefulWidget {
  final User user;
  const FuelConsumptionFormPage({super.key, required this.user});

  @override
  State<FuelConsumptionFormPage> createState() => _FuelConsumptionFormPageState();
}

class _FuelConsumptionFormPageState extends State<FuelConsumptionFormPage> {
  static const List<String> controleurs = [
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

  static const List<String> vehicles = [
    "Bidons",
    "CCF 176",
    "CCF 177",
    "FPTL",
    "VID",
    "VLHR",
    "VSAV",
  ];

  static const List<String> fuels = ["Gas-Oil", "SP 98"];
  static const List<String> ticketValues = ["OUI", "NON"];

  String? controleur;
  DateTime? date;
  String? vehicle;
  final TextEditingController kilometrageCtrl = TextEditingController();
  String? carburant;
  final TextEditingController quantityCtrl = TextEditingController();
  String? ticket;
  bool saving = false;
  bool submitted = false;

  @override
  void dispose() {
    kilometrageCtrl.dispose();
    quantityCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) => "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  bool get _isValid =>
      controleur != null &&
      date != null &&
      vehicle != null &&
      kilometrageCtrl.text.trim().isNotEmpty &&
      carburant != null &&
      quantityCtrl.text.trim().isNotEmpty &&
      ticket != null;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('fr', 'FR'),
      initialDate: date ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null && mounted) setState(() => date = picked);
  }

  Future<void> _submit() async {
    setState(() => submitted = true);
    if (!_isValid) return;

    setState(() => saving = true);
    try {
      await FirebaseFirestore.instance.collection('fuel_consumption_submissions').add({
        'formTitle': 'Consommation Carburant',
        'fullName': controleur,
        'date': Timestamp.fromDate(date!),
        'vehicle': vehicle,
        'kilometrage': kilometrageCtrl.text.trim(),
        'fuelType': carburant,
        'quantityLiters': quantityCtrl.text.trim(),
        'ticket': ticket,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.user.uid,
        'createdByEmail': widget.user.email ?? '',
        'answers': [
          {'section': 'Général', 'question': 'Nom-Prénom', 'answer': controleur ?? ''},
          {'section': 'Général', 'question': 'Date', 'answer': _fmtDate(date!)},
          {'section': 'Consommation', 'question': 'Véhicule', 'answer': vehicle ?? ''},
          {'section': 'Consommation', 'question': 'Kilométrage', 'answer': kilometrageCtrl.text.trim()},
          {'section': 'Consommation', 'question': 'Carburant', 'answer': carburant ?? ''},
          {'section': 'Consommation', 'question': 'Quantité en litre', 'answer': quantityCtrl.text.trim()},
          {'section': 'Consommation', 'question': 'Ticket', 'answer': ticket ?? ''},
        ],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Consommation carburant enregistrée.')));
      setState(() {
        controleur = null;
        date = null;
        vehicle = null;
        carburant = null;
        ticket = null;
        submitted = false;
        kilometrageCtrl.clear();
        quantityCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _reset() {
    setState(() {
      controleur = null;
      date = null;
      vehicle = null;
      carburant = null;
      ticket = null;
      submitted = false;
      kilometrageCtrl.clear();
      quantityCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _FuelFormSectionCard(
          title: 'Nom-Prénom',
          requiredField: true,
          hasError: submitted && controleur == null,
          child: DropdownButtonFormField<String>(
            value: controleur,
            decoration: const InputDecoration(hintText: 'Sélectionner'),
            items: controleurs.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
            onChanged: saving ? null : (v) => setState(() => controleur = v),
          ),
        ),
        const SizedBox(height: 12),
        _FuelFormSectionCard(
          title: 'Date',
          requiredField: true,
          hasError: submitted && date == null,
          child: InkWell(
            onTap: saving ? null : _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date', suffixIcon: Icon(Icons.calendar_today_outlined)),
              child: Text(date == null ? 'jj/mm/aaaa' : _fmtDate(date!)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _FuelFormSectionCard(
          title: 'Véhicule',
          requiredField: true,
          hasError: submitted && vehicle == null,
          child: DropdownButtonFormField<String>(
            value: vehicle,
            decoration: const InputDecoration(hintText: 'Sélectionner'),
            items: vehicles.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
            onChanged: saving ? null : (v) => setState(() => vehicle = v),
          ),
        ),
        const SizedBox(height: 12),
        _FuelFormSectionCard(
          title: 'Kilométrage',
          requiredField: true,
          hasError: submitted && kilometrageCtrl.text.trim().isEmpty,
          child: TextField(
            controller: kilometrageCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Votre réponse'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 12),
        _FuelFormSectionCard(
          title: 'Carburant',
          requiredField: true,
          hasError: submitted && carburant == null,
          child: DropdownButtonFormField<String>(
            value: carburant,
            decoration: const InputDecoration(hintText: 'Sélectionner'),
            items: fuels.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
            onChanged: saving ? null : (v) => setState(() => carburant = v),
          ),
        ),
        const SizedBox(height: 12),
        _FuelFormSectionCard(
          title: 'Quantité en litre',
          requiredField: true,
          hasError: submitted && quantityCtrl.text.trim().isEmpty,
          child: TextField(
            controller: quantityCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: 'Votre réponse'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 12),
        _FuelFormSectionCard(
          title: 'Ticket',
          requiredField: true,
          hasError: submitted && ticket == null,
          child: DropdownButtonFormField<String>(
            value: ticket,
            decoration: const InputDecoration(hintText: 'Sélectionner'),
            items: ticketValues.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
            onChanged: saving ? null : (v) => setState(() => ticket = v),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton(
              onPressed: saving ? null : _submit,
              child: saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Envoyer'),
            ),
            const Spacer(),
            TextButton(
              onPressed: saving ? null : _reset,
              child: const Text('Effacer le formulaire'),
            ),
          ],
        ),
      ],
    );
  }
}

class _FuelFormSectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool requiredField;
  final bool hasError;
  const _FuelFormSectionCard({
    required this.title,
    required this.child,
    this.requiredField = false,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: hasError ? const Color(0xFFEA4335) : const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title${requiredField ? ' *' : ''}', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          child,
          if (hasError) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFEA4335)),
                SizedBox(width: 8),
                Text('Cette question est obligatoire.', style: TextStyle(color: Color(0xFFEA4335), fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class AdminFuelConsumptionsPage extends StatelessWidget {
  const AdminFuelConsumptionsPage({super.key});

  static const vehicles = <String>[
    "Bidons",
    "CCF 176",
    "CCF 177",
    "FPTL",
    "VID",
    "VLHR",
    "VSAV",
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('fuel_consumption_submissions')
          .orderBy('createdAt', descending: true)
          .limit(300)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorCard(title: 'Erreur Firestore', message: '${snap.error}');
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> byVehicle = {
          for (final v in vehicles) v: <QueryDocumentSnapshot<Map<String, dynamic>>>[],
        };
        for (final d in docs) {
          final vehicle = (d.data()['vehicle'] ?? '').toString();
          if (byVehicle.containsKey(vehicle)) {
            byVehicle[vehicle]!.add(d);
          }
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Consommations enregistrées',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            ...vehicles.map((v) {
              final list = byVehicle[v] ?? const [];
              return Card(
                elevation: 1.1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: ExpansionTile(
                  title: Text(v, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text('${list.length} saisie(s)'),
                  children: [
                    if (list.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Aucune saisie enregistrée.'),
                      ),
                    for (final d in list) _FuelSubmissionTile(doc: d),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class FuelConsumptionTablePage extends StatelessWidget {
  const FuelConsumptionTablePage({super.key});

  String _fmtDateOnly(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  String _fmtDateTime(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} "
      "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";


  Future<void> _exportExcel(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final excelFile = excel.Excel.createExcel();
    final sheet = excelFile['Consommation carburant'];

    String fmtDateOnly(DateTime d) =>
        "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

    String fmtDateTime(DateTime d) =>
        "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} "
        "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

    final headers = [
      'Horodateur',
      'Nom-Prénom',
      'Date',
      'Véhicule',
      'Kilométrage',
      'Carburant',
      'Quantité en litre',
      'Ticket',
    ];

    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = excel.TextCellValue(headers[i]);
      cell.cellStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
        verticalAlign: excel.VerticalAlign.Center,
        backgroundColorHex: excel.ExcelColor.fromHexString('#DCE6F1'),
        leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
      );
    }

    for (int row = 0; row < docs.length; row++) {
      final data = docs[row].data();

      DateTime? createdAt;
      final createdAtTs = data['createdAt'];
      if (createdAtTs is Timestamp) createdAt = createdAtTs.toDate();

      DateTime? fuelDate;
      final fuelDateTs = data['date'];
      if (fuelDateTs is Timestamp) fuelDate = fuelDateTs.toDate();

      final values = [
        createdAt != null ? fmtDateTime(createdAt) : '',
        (data['fullName'] ?? '').toString(),
        fuelDate != null ? fmtDateOnly(fuelDate) : '',
        (data['vehicle'] ?? '').toString(),
        (data['kilometrage'] ?? '').toString(),
        (data['fuelType'] ?? '').toString(),
        (data['quantityLiters'] ?? '').toString(),
        (data['ticket'] ?? '').toString(),
      ];

      for (int col = 0; col < values.length; col++) {
        final cell = sheet.cell(excel.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row + 1));
        cell.value = excel.TextCellValue(values[col]);
        cell.cellStyle = excel.CellStyle(
          horizontalAlign: excel.HorizontalAlign.Left,
          verticalAlign: excel.VerticalAlign.Center,
          leftBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
          rightBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
          topBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
          bottomBorder: excel.Border(borderStyle: excel.BorderStyle.Thin),
        );
      }
    }

    sheet.setColumnWidth(0, 22);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 14);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 14);
    sheet.setColumnWidth(5, 14);
    sheet.setColumnWidth(6, 18);
    sheet.setColumnWidth(7, 10);

    final bytes = excelFile.encode();
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/tableau_carburant.xlsx');
    await file.writeAsBytes(bytes, flush: true);

    await OpenFilex.open(file.path);
  }
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('fuel_consumption_submissions')
          .orderBy('createdAt', descending: true)
          .limit(500)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorCard(
            title: 'Erreur Firestore',
            message: '${snap.error}',
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _InfoCard(
                title: 'Aucune donnée',
                message: 'Aucune consommation carburant enregistrée pour le moment.',
              ),
            ],
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tableau carburant',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _exportExcel(docs),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Exporter Excel'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columnSpacing: 18,
                    headingRowHeight: 52,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 64,
                    columns: const [
                      DataColumn(label: Text('Horodateur')),
                      DataColumn(label: Text('Nom-Prénom')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Véhicule')),
                      DataColumn(label: Text('Kilométrage')),
                      DataColumn(label: Text('Carburant')),
                      DataColumn(label: Text('Quantité en litre')),
                      DataColumn(label: Text('Ticket')),
                    ],
                    rows: docs.map((d) {
                      final data = d.data();

                      DateTime? createdAt;
                      final createdAtTs = data['createdAt'];
                      if (createdAtTs is Timestamp) createdAt = createdAtTs.toDate();

                      DateTime? fuelDate;
                      final fuelDateTs = data['date'];
                      if (fuelDateTs is Timestamp) fuelDate = fuelDateTs.toDate();

                      return DataRow(
                        cells: [
                          DataCell(Text(createdAt != null ? _fmtDateTime(createdAt) : '')),
                          DataCell(Text((data['fullName'] ?? '').toString())),
                          DataCell(Text(fuelDate != null ? _fmtDateOnly(fuelDate) : '')),
                          DataCell(Text((data['vehicle'] ?? '').toString())),
                          DataCell(Text((data['kilometrage'] ?? '').toString())),
                          DataCell(Text((data['fuelType'] ?? '').toString())),
                          DataCell(Text((data['quantityLiters'] ?? '').toString())),
                          DataCell(Text((data['ticket'] ?? '').toString())),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FuelSubmissionTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _FuelSubmissionTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final vehicle = (data['vehicle'] ?? 'Consommation').toString();
    final email = (data['createdByEmail'] ?? '').toString();
    final fuelType = (data['fuelType'] ?? '').toString();
    final quantity = (data['quantityLiters'] ?? '').toString();

    DateTime? createdAt;
    final ts = data['createdAt'];
    if (ts is Timestamp) createdAt = ts.toDate();

    final subtitle = [
      if (createdAt != null) DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(createdAt),
      if (fuelType.isNotEmpty) fuelType,
      if (quantity.isNotEmpty) '$quantity L',
      if (email.isNotEmpty) email,
    ].join(' • ');

    return ListTile(
      leading: const Icon(Icons.local_gas_station_rounded),
      title: Text(vehicle, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => FuelConsumptionDetailPage(doc: doc)),
        );
      },
    );
  }
}

class NumerosUtilesPage extends StatelessWidget {
  const NumerosUtilesPage({super.key});

  Widget phoneTile(String title, String number) {
    return Card(
      elevation: 1.1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: const Icon(Icons.phone_rounded),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(number),
        trailing: IconButton(
          icon: const Icon(Icons.call),
          onPressed: () async {
            final uri = Uri.parse("tel:$number");
            await launchUrl(uri);
          },
        ),
      ),
    );
  }

  Widget codeTile(BuildContext context, String title, String code) {
    return Card(
      elevation: 1.1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: const Icon(Icons.lock_outline_rounded),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(code),
        trailing: IconButton(
          icon: const Icon(Icons.copy_rounded),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Code copié")),
            );
          },
        ),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Colors.red,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [

        /// NUMEROS UTILES
        sectionTitle("NUMÉROS UTILES"),

        phoneTile("CODIS", "0558515650"),
        phoneTile("Officier CODIS", "0558457909"),
        phoneTile("PC FEU", "0558515654"),
        phoneTile("CSP DAX", "0558563757"),
        phoneTile("CSP MARSAN", "0558515686"),
        phoneTile("Mairie Onesse", "0558073010"),
        phoneTile("Astreinte Mairie", "0649580292"),

        /// CONSEILLERS TECHNIQUES
        sectionTitle("CONSEILLERS TECHNIQUES"),

        phoneTile("Dupin François", "0673680207"),
        phoneTile("Larrouy Jean", "0607651618"),
        phoneTile("De Lestapis Hugues", "0608067868"),
        phoneTile("Duluc Jean", "0749623121"),
        phoneTile("Larrouy Arnaud", "0683411352"),
        phoneTile("Menaut Sébastien", "0681577481"),

        // AGRICULTEURS
        sectionTitle("AGRICULTEURS CONVENTIONNES"),

        phoneTile("Fabien Saubion (Cantaloube)", "0648470864"),
        phoneTile("Thierry Vandame", "0689865856"),
        phoneTile("Nicolas Jacquet", "0609829004"),
        phoneTile("Christel Patay", "0677201656"),
        phoneTile("Arnaud Larrouy", "0683411352"),


        // Actifs
        sectionTitle("Actifs Centre"),

        phoneTile("Aillerie Robin", "0665234105"),
        phoneTile('Sanguina Dominique', "0630567363"),
        phoneTile('Sanguina Thierry', "0685763019"),
        phoneTile('Condro Alexis (Alias La piquouze)', "0637633798"),
        phoneTile('Dahan Stéphane', "0685438048"),
        phoneTile('Limouzi Rémy', "0684486822"),
        phoneTile('Bellegarde Nathalie', "0678614645"),
        phoneTile('Fournié Benjamin', "0689321150"),
        phoneTile('Fournié Julien', "0671147025"),
        phoneTile('Dubourg Sylvie', "0688115274"),
        phoneTile('Duvignac Julien', "0678938071"),
        phoneTile('Ducout Margaux', "0683151234"),
        phoneTile('Etcheverry Jérôme', "0673293311"),
        phoneTile('Fernandez Nicolas', "0610282091"),
        phoneTile('Tallon Nicolas', "0670350883"),
        phoneTile('Gauthé David', "0615478750"),
        phoneTile('Geffroy Audrey', "0625296570"),
        phoneTile('Guyou Laurent', "0684451784"),
        phoneTile('Lapiè Rémy', "0633556888"),
        phoneTile('Lasserre Jérémy', "0687575967"),
        phoneTile('Marsan Sylvain', "0558043203"),
        phoneTile('Moussu Mathilde', "0681686527"),
        phoneTile('Paillou Frédéric', "0687491482"),




        /// CODES
        sectionTitle("CODES"),

        codeTile(context, "CH DAX", "4820A"),
        codeTile(context, "PORTAIL SDIS", "301840"),
        codeTile(context, "CSP DAX", "1840"),
        codeTile(context, "EPHAD", "1932 A"),
        codeTile(context, "BARRIÈRE CAMPING", "154 puis flèche"),
        codeTile(context, "PORTAIL STEP", "4011"),
      ],
    );
  }
}

class FuelConsumptionDetailPage extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const FuelConsumptionDetailPage({super.key, required this.doc});

  List<Map<String, dynamic>> _answers() {
    final data = doc.data();
    final raw = data['answers'];
    if (raw is List) {
      final out = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is Map) {
          out.add(item.map((k, v) => MapEntry(k.toString(), v)));
        }
      }
      return out;
    }
    return const [];
  }

  static String _answerToString(dynamic v) {
    if (v == null) return '(vide)';
    if (v is bool) return v ? 'Oui' : 'Non';
    if (v is List) return v.isEmpty ? '(vide)' : v.map((e) => e.toString()).join(', ');
    final s = v.toString().trim();
    return s.isEmpty ? '(vide)' : s;
  }

  Future<void> _exportPdf() async {
    final data = doc.data();
    final title = (data['formTitle'] ?? 'Consommation Carburant').toString();
    final createdByEmail = (data['createdByEmail'] ?? '').toString();
    final vehicle = (data['vehicle'] ?? '').toString();
    final fullName = (data['fullName'] ?? '').toString();

    DateTime? createdAt;
    final createdAtTs = data['createdAt'];
    if (createdAtTs is Timestamp) createdAt = createdAtTs.toDate();

    DateTime? fuelDate;
    final fuelDateTs = data['date'];
    if (fuelDateTs is Timestamp) fuelDate = fuelDateTs.toDate();

    final answers = _answers();

    final Map<String, List<Map<String, dynamic>>> bySection = {};
    for (final a in answers) {
      final sec = (a['section'] ?? 'Général').toString();
      bySection.putIfAbsent(sec, () => []);
      bySection[sec]!.add(a);
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (vehicle.isNotEmpty) pw.Text('Véhicule : $vehicle'),
          if (fullName.isNotEmpty) pw.Text('Nom-Prénom : $fullName'),
          if (fuelDate != null) pw.Text('Date de conso : ${DateFormat('dd/MM/yyyy', 'fr_FR').format(fuelDate)}'),
          if (createdAt != null) pw.Text('Enregistré le : ${DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(createdAt)}'),
          if (createdByEmail.isNotEmpty) pw.Text('Créé par : $createdByEmail'),
          pw.SizedBox(height: 12),
          for (final entry in bySection.entries) ...[
            pw.Text(
              entry.key,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            for (final a in entry.value) ...[
              pw.Text(
                (a['question'] ?? '').toString(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(_answerToString(a['answer'])),
              pw.SizedBox(height: 8),
            ],
            pw.SizedBox(height: 10),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = (data['formTitle'] ?? 'Consommation Carburant').toString();
    final answers = _answers();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Exporter PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1.1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Submission: ${doc.id}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...answers.map((a) {
            final q = (a['question'] ?? '').toString();
            final ans = _answerToString(a['answer']);
            return Card(
              elevation: 1.1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ListTile(
                title: Text(q, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(ans),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String title;
  final String message;
  const _ErrorCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: cs.onErrorContainer)),
            const SizedBox(height: 6),
            Text(message, style: TextStyle(color: cs.onErrorContainer)),
          ],
        ),
      ),
    );
  }
}

class _AmicaleHomePage extends StatelessWidget {
  const _AmicaleHomePage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _InfoCard(
          title: 'Amicale',
          message: 'Choisis une sous-section dans le menu pour afficher les documents.',
        ),
      ],
    );
  }
}

class _AstreinteAssetsPage extends StatelessWidget {
  const _AstreinteAssetsPage();

  static const List<PdfItem> items = [
    PdfItem(title: "Astreinte 2026", assetPath: "assets/pdfs/astreintes/Astreinte CIS 2026.pdf"),
  ];

  Future<void> _openAssetPdf(BuildContext context, PdfItem item) async {
    try {
      await openPdfAsset(item.assetPath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir le PDF : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _InfoCard(title: "Astreinte CIS", message: "Aucun document pour l’instant."),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          "Astreinte CIS",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        ...items.map((p) {
          return Card(
            elevation: 1.1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(p.assetPath, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.download_rounded),
              onTap: () => _openAssetPdf(context, p),
            ),
          );
        }),
      ],
    );
  }
}

class _MobilhomeHomePage extends StatelessWidget {
  const _MobilhomeHomePage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _InfoCard(
          title: 'Mobil-homme',
          message:
              'Choisis une sous-section :\n'
              '- Réservation\n'
              '- Consignes Arrivée / Départ\n'
              '- Règlement Mobil-home',
        ),
      ],
    );
  }
}

class MobilhomeReservationPage extends StatefulWidget {
  final User user;
  const MobilhomeReservationPage({super.key, required this.user});

  @override
  State<MobilhomeReservationPage> createState() => _MobilhomeReservationPageState();
}

class _MobilhomeReservationPageState extends State<MobilhomeReservationPage> {
  static const List<String> membres = [
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

  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController personsCtrl = TextEditingController();

  String? selectedName;
  DateTime? startDate;
  DateTime? endDate;

  bool submitted = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    emailCtrl.text = widget.user.email ?? '';
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    personsCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  bool get _isValid =>
      emailCtrl.text.trim().isNotEmpty &&
      selectedName != null &&
      startDate != null &&
      endDate != null &&
      personsCtrl.text.trim().isNotEmpty;

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null && mounted) {
      setState(() {
        startDate = picked;
        if (endDate != null && endDate!.isBefore(startDate!)) {
          endDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final initial = endDate ?? startDate ?? now;
    final first = startDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null && mounted) {
      setState(() => endDate = picked);
    }
  }

  Future<void> _submit() async {
    setState(() => submitted = true);
    if (!_isValid) return;

    if (endDate!.isBefore(startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La date de fin doit être après la date de début.')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      await FirebaseFirestore.instance.collection('mobilhome_reservations').add({
        'formTitle': 'Réservation Mobil-home',
        'email': emailCtrl.text.trim(),
        'fullName': selectedName,
        'startDate': Timestamp.fromDate(startDate!),
        'endDate': Timestamp.fromDate(endDate!),
        'personsCount': personsCtrl.text.trim(),
        'status': 'en_attente',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.user.uid,
        'createdByEmail': widget.user.email ?? '',
        'answers': [
          {'section': 'Réservation', 'question': 'E-mail', 'answer': emailCtrl.text.trim()},
          {'section': 'Réservation', 'question': 'Nom Prénom', 'answer': selectedName ?? ''},
          {'section': 'Réservation', 'question': 'Date souhaitée début de réservation', 'answer': _fmtDate(startDate!)},
          {'section': 'Réservation', 'question': 'Date souhaitée fin de réservation', 'answer': _fmtDate(endDate!)},
          {'section': 'Réservation', 'question': 'Nombre de personne', 'answer': personsCtrl.text.trim()},
        ],
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande de réservation envoyée.')),
      );

      setState(() {
        submitted = false;
        selectedName = null;
        startDate = null;
        endDate = null;
        personsCtrl.clear();
        emailCtrl.text = widget.user.email ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _InfoCard(
          title: 'Réservation Mobil-home',
          message:
              'Une fois la réservation validée, Laurent ou Thierry vous le confirmerons.\n'
              'La réservation sera ajoutée à l’agenda.',
        ),
        const SizedBox(height: 12),

        _FuelFormSectionCard(
          title: 'E-mail',
          requiredField: true,
          hasError: submitted && emailCtrl.text.trim().isEmpty,
          child: TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'Votre e-mail'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 12),

        _FuelFormSectionCard(
          title: 'Nom Prénom',
          requiredField: true,
          hasError: submitted && selectedName == null,
          child: DropdownButtonFormField<String>(
            value: selectedName,
            decoration: const InputDecoration(hintText: 'Sélectionner'),
            items: membres
                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                .toList(),
            onChanged: saving ? null : (v) => setState(() => selectedName = v),
          ),
        ),
        const SizedBox(height: 12),

        _FuelFormSectionCard(
          title: 'Date souhaitée début de réservation',
          requiredField: true,
          hasError: submitted && startDate == null,
          child: InkWell(
            onTap: saving ? null : _pickStartDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(startDate == null ? 'jj/mm/aaaa' : _fmtDate(startDate!)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        _FuelFormSectionCard(
          title: 'Date souhaitée fin de réservation',
          requiredField: true,
          hasError: submitted && endDate == null,
          child: InkWell(
            onTap: saving ? null : _pickEndDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(endDate == null ? 'jj/mm/aaaa' : _fmtDate(endDate!)),
            ),
          ),
        ),
        const SizedBox(height: 12),

        _FuelFormSectionCard(
          title: 'Nombre de personne',
          requiredField: true,
          hasError: submitted && personsCtrl.text.trim().isEmpty,
          child: TextField(
            controller: personsCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Votre réponse'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            FilledButton(
              onPressed: saving ? null : _submit,
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Envoyer'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AmicaleCategoryAssetsPage extends StatelessWidget {
  final String title;
  final List<PdfItem> items;

  const _AmicaleCategoryAssetsPage({
    required this.title,
    required this.items,
  });

  Future<void> _openAssetPdf(BuildContext context, PdfItem item) async {
    try {
      await openPdfAsset(item.assetPath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d\'ouvrir le PDF : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(title: title, message: 'Aucun document pour l’instant.'),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        ...items.map((p) {
          return Card(
            elevation: 1.1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf_rounded),
              title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(p.assetPath, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.download_rounded),
              onTap: () => _openAssetPdf(context, p),
            ),
          );
        }),
      ],
    );
  }
}

class MobilhomeReservationSection extends StatelessWidget {
  final bool isAdmin;
  final User user;

  const MobilhomeReservationSection({
    super.key,
    required this.isAdmin,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      const Tab(text: 'Réservation'),
      if (isAdmin) const Tab(text: 'Demandes reçues'),
    ];

    final views = <Widget>[
      MobilhomeReservationPage(user: user),
      if (isAdmin) const AdminMobilhomeReservationsPage(),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(tabs: tabs),
          ),
          Expanded(
            child: TabBarView(children: views),
          ),
        ],
      ),
    );
  }
}

class AdminMobilhomeReservationsPage extends StatelessWidget {
  const AdminMobilhomeReservationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('mobilhome_reservations')
          .orderBy('createdAt', descending: true)
          .limit(300)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorCard(
            title: 'Erreur Firestore',
            message: '${snap.error}',
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _InfoCard(
                title: 'Aucune demande',
                message: 'Aucune réservation Mobil-home enregistrée pour le moment.',
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Demandes de réservation',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            ...docs.map((d) => _MobilhomeReservationTile(doc: d)),
          ],
        );
      },
    );
  }
}

class _MobilhomeReservationTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _MobilhomeReservationTile({required this.doc});

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  @override
  Widget build(BuildContext context) {
    final data = doc.data();

    final fullName = (data['fullName'] ?? '').toString();
    final email = (data['email'] ?? '').toString();
    final personsCount = (data['personsCount'] ?? '').toString();
    final status = (data['status'] ?? 'en_attente').toString();

    DateTime? startDate;
    final startTs = data['startDate'];
    if (startTs is Timestamp) startDate = startTs.toDate();

    DateTime? endDate;
    final endTs = data['endDate'];
    if (endTs is Timestamp) endDate = endTs.toDate();

    final subtitleParts = <String>[
      if (startDate != null) "Début : ${_fmtDate(startDate)}",
      if (endDate != null) "Fin : ${_fmtDate(endDate)}",
      if (personsCount.isNotEmpty) "$personsCount pers.",
      if (email.isNotEmpty) email,
    ];

    return Card(
      elevation: 1.1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: const Icon(Icons.holiday_village_rounded),
        title: Text(
          fullName.isEmpty ? 'Réservation Mobil-home' : fullName,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(subtitleParts.join(' • ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chevron_right_rounded),
            Text(
              status,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MobilhomeReservationDetailPage(doc: doc),
            ),
          );
        },
      ),
    );
  }
}

class MobilhomeReservationDetailPage extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const MobilhomeReservationDetailPage({super.key, required this.doc});

  List<Map<String, dynamic>> _answers() {
    final data = doc.data();
    final raw = data['answers'];

    if (raw is List) {
      final out = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is Map) {
          out.add(item.map((k, v) => MapEntry(k.toString(), v)));
        }
      }
      return out;
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = (data['formTitle'] ?? 'Réservation Mobil-home').toString();
    final answers = _answers();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1.1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Submission: ${doc.id}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...answers.map((a) {
            final q = (a['question'] ?? '').toString();
            final ans = (a['answer'] ?? '').toString();

            return Card(
              elevation: 1.1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ListTile(
                title: Text(q, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(ans),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class RetourInterVsavPage extends StatelessWidget {
  final bool isAdmin;
  final User user;

  const RetourInterVsavPage({
    super.key,
    required this.isAdmin,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      const Tab(text: 'Faire un retour'),
      if (isAdmin) const Tab(text: 'Retours effectués'),
    ];

    final views = <Widget>[
      RetourInterVsavFormPage(user: user),
      if (isAdmin) const AdminRetourInterVsavPage(),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(tabs: tabs),
          ),
          Expanded(
            child: TabBarView(children: views),
          ),
        ],
      ),
    );
  }
}

class AdminRetourInterVsavPage extends StatelessWidget {
  const AdminRetourInterVsavPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('vsav_return_submissions')
          .orderBy('createdAt', descending: true)
          .limit(300)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorCard(
            title: 'Erreur Firestore',
            message: '${snap.error}',
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _InfoCard(
                title: 'Aucun retour VSAV',
                message: 'Aucun formulaire Retour Inter VSAV enregistré pour le moment.',
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Retours Inter VSAV',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            ...docs.map((d) => _RetourInterVsavTile(doc: d)),
          ],
        );
      },
    );
  }
}

class _RetourInterVsavTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _RetourInterVsavTile({required this.doc});

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  String _fmtDateTime(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} "
      "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final data = doc.data();

    final interventionNumber = (data['interventionNumber'] ?? '').toString();
    final fullName = (data['fullName'] ?? '').toString();
    final email = (data['createdByEmail'] ?? '').toString();

    DateTime? createdAt;
    final createdAtTs = data['createdAt'];
    if (createdAtTs is Timestamp) createdAt = createdAtTs.toDate();

    DateTime? interventionDate;
    final interventionDateTs = data['interventionDate'];
    if (interventionDateTs is Timestamp) {
      interventionDate = interventionDateTs.toDate();
    }

    final subtitleParts = <String>[
      if (interventionDate != null) "Inter : ${_fmtDate(interventionDate)}",
      if (createdAt != null) "Saisi : ${_fmtDateTime(createdAt)}",
      if (email.isNotEmpty) email,
    ];

    return Card(
      elevation: 1.1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: const Icon(Icons.medical_services_rounded),
        title: Text(
          interventionNumber.isEmpty
              ? (fullName.isEmpty ? 'Retour Inter VSAV' : fullName)
              : "Intervention n° $interventionNumber",
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(subtitleParts.join(' • ')),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RetourInterVsavDetailPage(doc: doc),
            ),
          );
        },
      ),
    );
  }
}

class RetourInterVsavDetailPage extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const RetourInterVsavDetailPage({super.key, required this.doc});

  List<Map<String, dynamic>> _answers() {
    final data = doc.data();
    final raw = data['answers'];

    if (raw is List) {
      final out = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is Map) {
          out.add(item.map((k, v) => MapEntry(k.toString(), v)));
        }
      }
      return out;
    }
    return const [];
  }

  static String _answerToString(dynamic v) {
    if (v == null) return '(vide)';
    if (v is bool) return v ? 'Oui' : 'Non';
    if (v is List) return v.isEmpty ? '(vide)' : v.map((e) => e.toString()).join(', ');
    final s = v.toString().trim();
    return s.isEmpty ? '(vide)' : s;
  }

  Future<void> _exportPdf() async {
    final data = doc.data();
    final formTitle = (data['formTitle'] ?? 'Retour Inter VSAV').toString();
    final createdByEmail = (data['createdByEmail'] ?? '').toString();
    final fullName = (data['fullName'] ?? '').toString();
    final interventionNumber = (data['interventionNumber'] ?? '').toString();

    DateTime? createdAt;
    final createdAtTs = data['createdAt'];
    if (createdAtTs is Timestamp) createdAt = createdAtTs.toDate();

    DateTime? interventionDate;
    final interventionDateTs = data['interventionDate'];
    if (interventionDateTs is Timestamp) interventionDate = interventionDateTs.toDate();

    final answers = _answers();

    final Map<String, List<Map<String, dynamic>>> bySection = {};
    for (final a in answers) {
      final sec = (a['section'] ?? 'Général').toString();
      bySection.putIfAbsent(sec, () => []);
      bySection[sec]!.add(a);
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Text(
            formTitle,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (interventionNumber.isNotEmpty) pw.Text('Numéro intervention : $interventionNumber'),
          if (fullName.isNotEmpty) pw.Text('Nom prénom du CA : $fullName'),
          if (interventionDate != null)
            pw.Text(
              'Date de l’intervention : ${DateFormat('dd/MM/yyyy', 'fr_FR').format(interventionDate)}',
            ),
          if (createdAt != null)
            pw.Text(
              'Enregistré le : ${DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(createdAt)}',
            ),
          if (createdByEmail.isNotEmpty) pw.Text('Créé par : $createdByEmail'),
          pw.SizedBox(height: 12),
          for (final entry in bySection.entries) ...[
            pw.Text(
              entry.key,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            for (final a in entry.value) ...[
              pw.Text(
                (a['question'] ?? '').toString(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(_answerToString(a['answer'])),
              pw.SizedBox(height: 8),
            ],
            pw.SizedBox(height: 10),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final formTitle = (data['formTitle'] ?? 'Retour Inter VSAV').toString();
    final answers = _answers();

    return Scaffold(
      appBar: AppBar(
        title: Text(formTitle),
        actions: [
          IconButton(
            tooltip: 'Exporter PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1.1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Submission: ${doc.id}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...answers.map((a) {
            final section = (a['section'] ?? '').toString();
            final q = (a['question'] ?? '').toString();
            final ans = _answerToString(a['answer']);

            return Card(
              elevation: 1.1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ListTile(
                title: Text(q, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(ans),
                trailing: section.isEmpty ? null : Text(section),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _VsavMatrixSection {
  final String section;
  final List<String> columns;
  final List<String> rows;

  const _VsavMatrixSection({
    required this.section,
    required this.columns,
    required this.rows,
  });
}

class RetourInterVsavFormPage extends StatefulWidget {
  final User user;
  const RetourInterVsavFormPage({super.key, required this.user});

  @override
  State<RetourInterVsavFormPage> createState() => _RetourInterVsavFormPageState();
}

class _RetourInterVsavFormPageState extends State<RetourInterVsavFormPage> {
  static const List<String> controllers = [
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

  static const Set<String> optionalSections = {
    'SAC ROUGE POCHE AVANT',
    'SAC ROUGE POCHETTE JAUNE',
    'SAC ROUGE POCHE DROITE',
    'SAC ROUGE POCHE GAUCHE',
    'SAC ROUGE POCHETTE VERTE',
    'SAC ROUGE POCHETTE ROUGE',
    'SAC ROUGE POCHETTE CENTRALE',
    'CELLULE',
    'CABINE CONDUCTEUR',
    'SAC ATTELLES',
    'SAC PEDIATRIQUE',
    'POCHETTE ASU',
    'PLACARD HAUT DROIT',
    'PLACARD HAUT GAUCHE',
    'PLACARD DESSUS CABINE',
    'TIROIR VERT',
    'TIROIR JAUNE',
    'TIROIR BLEU',
    'TIROIR BLANC',
    'TIROIR ROUGE',
    'PLACARD BLANC',
    'SAC ROUGE POCHE PRINCIPALE',
    'SAC ROUGE POCHETTE VIOLETTE',
    'SAC ROUGE POCHETTE BLEUE',
  };

  bool _isOptionalSection(String section) => optionalSections.contains(section);

  DateTime? interventionDate;
  final TextEditingController interventionNumberCtrl = TextEditingController();
  String? selectedController;

  String? bteO25LSac;
  String? bteO25LCellule;
  String? bteO215LCellule;

  final TextEditingController surfaniosCtrl = TextEditingController();
  final TextEditingController commentairesCtrl = TextEditingController();

  bool saving = false;
  bool submitted = false;

  final Map<String, String> _matrixAnswers = {};

  static const List<_VsavMatrixSection> matrixSections = [
    _VsavMatrixSection(
      section: 'SAC ROUGE',
      columns: ['Fonctionne', 'HS'],
      rows: ['Détecteur CO'],
    ),
    _VsavMatrixSection(
      section: 'SAC ROUGE POCHE AVANT',
      columns: ['Pris au stock/Mis sac', 'Pas en stock'],
      rows: ['Bavu usage unique', 'Sacs Dasri'],
    ),
    _VsavMatrixSection(
      section: 'SAC ROUGE POCHETTE JAUNE',
      columns: ['Pris au stock/Mis sac', 'Pas en stock'],
      rows: ['Canule guedel t. 2', 'Canule guedel t. 3', 'Canule guedel t. 4'],
    ),
    _VsavMatrixSection(
      section: 'SAC ROUGE POCHE DROITE',
      columns: ['Pris au stock/Mis sac', 'Pas en stock'],
      rows: ['Poches à froid', 'Poches vomix', 'Echarpes'],
    ),
    _VsavMatrixSection(
      section: 'SAC ROUGE POCHETTE BLEUE',
      columns: ['Pris stock/Mis sac', 'Pas en stock'],
      rows: ['Masque HC adulte', 'Lunettes O2'],
    ),
    _VsavMatrixSection(
      section: 'SAC ROUGE POCHETTE VIOLETTE',
      columns: ['Pris au stock/Mis sac', 'Pas en stock', 'Fonctionne', 'HS'],
      rows: ['Appareil glycémie', 'Bandelette glycémie', 'Lancette auto piqueur'],
    ),
    _VsavMatrixSection(
      section: 'SAC ROUGE POCHE GAUCHE',
      columns: ['Pris au stock/Mis sac', 'Pas en stock'],
      rows: ['Compresses brûlures', 'Pansements américain'],
    ),
    _VsavMatrixSection(
      section: 'SAC ROUGE POCHETTE VERTE',
      columns: ['Pris au stock/Mis sac', 'Pas en stock'],
      rows: ['C.H.U.T', 'Bandes 7cm'],
    ),
    _VsavMatrixSection(
      section: 'SAC ROUGE POCHETTE ROUGE',
      columns: ['Pris au stock/Mis sac', 'Pas en stock'],
      rows: [
        'Chlorure sodium 10 ml',
        'Chlorure sodium 45 ml',
        'Dacudose',
        'Sangle garrot',
        'Sparadrap',
        'Ciseaux GESCO',
        'Compresses non stérile',
        'Compresses stérile',
        'Garrot tourniquet',
      ],
    ),
    _VsavMatrixSection(
      section: 'SAC ROUGE POCHETTE CENTRALE',
      columns: ['Pris au stock/Mis sac', 'Pas en stock'],
      rows: ['Couverture bleue', 'Masques FFP 2', 'Lunettes'],
    ),
    _VsavMatrixSection(
      section: 'SAC ROUGE POCHE PRINCIPALE',
      columns: ['Pas en stock'],
      rows: ['Collier cervical adulte', 'Collier cervical enfant'],
    ),
    _VsavMatrixSection(
      section: 'PLACARD BLANC',
      columns: ['Pris dans Vsav', 'Pas en stock'],
      rows: [
        'Sangle araignée',
        'Sangles orange',
        'Sangles plan dur',
        'Bloque tête',
        'Brancard souple',
        'Pompy',
      ],
    ),
    _VsavMatrixSection(
      section: 'TIROIR ROUGE',
      columns: ['Pris stock/Mis dans tiroir', 'Manque tiroir rouge'],
      rows: [
        'Compresses stérile',
        'Compresses non stérile',
        'Chlorure sodium 45ml',
        'Chlorure sodium 10ml',
        'Dacudose/Dacryosérum',
        'Sparadrap',
        'Pince à épiler',
        'Ciseaux GESCO',
        'Ciseaux rouge',
        'Sangle garrot',
      ],
    ),
    _VsavMatrixSection(
      section: 'TIROIR BLANC',
      columns: ['Pris stock/Mis tiroir', 'Manque tiroir blanc'],
      rows: [
        'Elastoplaste',
        'Filet tubulaire petit',
        'Filet tubulaire moyen',
        'Filet tubulaire grand',
        'Bandes 3 ou 4m x 7cm',
        'Bandes 3m x 5cm',
        'Bandes 3m x 10cm',
        'Pansement absorbant',
        'Champ de soin',
        'Echarpes',
      ],
    ),
    _VsavMatrixSection(
      section: 'TIROIR BLEU',
      columns: ['Pris stock/Mis tiroir', 'Manque tiroir bleu'],
      rows: ['Masque H.C adulte', 'Lunettes O2'],
    ),
    _VsavMatrixSection(
      section: 'TIROIR JAUNE',
      columns: ['Pris stock/Mis tiroir', 'Manque tiroir jaune'],
      rows: [
        'Filtre aspirateur mucosités',
        'Canule yankauer',
        'Canule guédel T2',
        'Canule guédel T3',
        'Canule guédel T4',
        'Raccord biconique',
      ],
    ),
    _VsavMatrixSection(
      section: 'TIROIR VERT',
      columns: ['Pris stock/Mis tiroir', 'Manque tiroir vert'],
      rows: ['Tensiomètre manuel', 'Minuteur', 'Stéthoscope', 'Boite masques chirurgicaux'],
    ),
    _VsavMatrixSection(
      section: 'PLACARD DESSUS CABINE',
      columns: ['Pris stock/Mis placard', 'Manque dessus cabine'],
      rows: [
        'Sacs D.A.S.R.I jaune',
        'Lot risques infectieux',
        'Lingettes',
        'Anios surface',
        'Kit A.E.S',
        'Haricot',
        'Scotch orange',
      ],
    ),
    _VsavMatrixSection(
      section: 'PLACARD HAUT GAUCHE',
      columns: ['Pris stock/Mis placard', 'Manque placard haut G'],
      rows: [
        'C.H.U.T',
        'Poches à froid',
        'Couverture de survie',
        'Brulstop',
        'BAVU usage unique',
        'Couverture bleue',
        'Collier cervical adulte',
        'Chasubles',
        'Pompe à dépression',
        'Pochette ASU',
      ],
    ),
    _VsavMatrixSection(
      section: 'PLACARD HAUT DROIT',
      columns: ['Pris stock/Mis placard', 'Manque placard haut D'],
      rows: ['Draps jetables', 'Poche membres', 'Draps'],
    ),
    _VsavMatrixSection(
      section: 'POCHETTE ASU',
      columns: ['Utilisé lors de l\'inter', 'Commande pharmacie faite', 'Copie commande Audrey et Dominique'],
      rows: [
        'Kit perfusion',
        'Kit ASU asthme adulte',
        'Kit ASU asthme enfant',
        'Adrénaline 30kg et plus',
        'Adrénaline moins de 30kg',
        'Doliprane orodispersible',
        'Efferalgan Med 250mg',
        'Alcomed Pads',
      ],
    ),
    _VsavMatrixSection(
      section: 'SAC PEDIATRIQUE',
      columns: ['Pris au stock/Mis sac', 'Manque sac pédia'],
      rows: [
        'Bavu usage unique',
        'Masque bavu taille 1',
        'Masque bavu taille 2',
        'Masque bavu taille 3',
        'Kit accouchement',
        'Jersey',
        'Masque HC enfant',
        'Canule guedel t. 00',
        'Canule guedel t. 0',
        'Canule guedel t. 1',
        'Champs de soins NN',
      ],
    ),
    _VsavMatrixSection(
      section: 'SAC ATTELLES',
      columns: ['Manque sac attelles'],
      rows: ['Petit modèle', 'Moyen modèle', 'Grand modèle'],
    ),
    _VsavMatrixSection(
      section: 'CABINE CONDUCTEUR',
      columns: ['Pris stock/Mis Vsav', 'Manque dans cabine'],
      rows: [
        'Fiches bilans',
        'Lot tuerie de masse',
        'Malette NOVI',
        'Embouts détecteur CO',
        'Gants XL',
        'Gants L',
      ],
    ),
    _VsavMatrixSection(
      section: 'CELLULE',
      columns: ['Pris au stock/Mis cellule', 'Manque dans cellule'],
      rows: [
        'Canule yankauer',
        'Solution hydroalcoolique',
        'Poches vomix',
        'Gants S 6/7',
        'Gants M 7/8',
        'Gants L 8/9',
        'Gants XL 9/10',
        'Electrodes DSA',
        'Rasoirs',
        'Masques chirurgicaux',
      ],
    ),
    _VsavMatrixSection(
      section: 'DESINFECTION',
      columns: ['Fait et inscrit sur cahier'],
      rows: [
        'Désinfection niveau 1 inscrit sur cahier',
        'Désinfection niveau 2 inscrit sur cahier',
        'Désinfection niveau 3 inscrit sur cahier'
      ],
    ),
    _VsavMatrixSection(
      section: 'CHARGE DU MATERIEL',
      columns: ['Chargé', 'En charge', 'Piles remplacées'],
      rows: ['Tensiomètre', 'Oxymètre', 'DSA', 'Thermomètre'],
    ),
  ];

  @override
  void dispose() {
    interventionNumberCtrl.dispose();
    surfaniosCtrl.dispose();
    commentairesCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  bool _hasMissingMatrixAnswer() {
    for (final section in matrixSections) {
      if (optionalSections.contains(section.section)) {
        continue;
      }

      if (section.section == 'DESINFECTION') {
        final selectedCount = section.rows
            .where((row) =>
                (_matrixAnswers['${section.section}|||$row'] ?? '').trim().isNotEmpty)
            .length;

        if (selectedCount != 1) {
          return true;
        }
        continue;
      }

      for (final row in section.rows) {
        final key = '${section.section}|||$row';
        if ((_matrixAnswers[key] ?? '').trim().isEmpty) {
          return true;
        }
      }
    }

    return false;
  }

  bool get _isValid =>
      interventionDate != null &&
      interventionNumberCtrl.text.trim().isNotEmpty &&
      selectedController != null &&
      bteO25LSac != null &&
      bteO25LCellule != null &&
      bteO215LCellule != null &&
      surfaniosCtrl.text.trim().isNotEmpty &&
      commentairesCtrl.text.trim().isNotEmpty &&
      !_hasMissingMatrixAnswer();

  Future<void> _pickInterventionDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: interventionDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null && mounted) {
      setState(() => interventionDate = picked);
    }
  }

  List<Map<String, dynamic>> _buildAnswers() {
    final answers = <Map<String, dynamic>>[
      {
        'section': 'Général',
        'question': 'DATE DE L\'INTERVENTION',
        'answer': interventionDate != null ? _fmtDate(interventionDate!) : '',
      },
      {
        'section': 'Général',
        'question': 'NUMERO DE L\'INTERVENTION',
        'answer': interventionNumberCtrl.text.trim(),
      },
      {
        'section': 'Général',
        'question': 'NOM PRENOM DU CA',
        'answer': selectedController ?? '',
      },
      {
        'section': 'Bouteilles O2',
        'question': 'Bte O2 5L du sac',
        'answer': bteO25LSac ?? '',
      },
      {
        'section': 'Bouteilles O2',
        'question': 'Bte O2 5L cellule',
        'answer': bteO25LCellule ?? '',
      },
      {
        'section': 'Bouteilles O2',
        'question': 'Bte O2 15L cellule',
        'answer': bteO215LCellule ?? '',
      },
    ];

    for (final section in matrixSections) {
      for (final row in section.rows) {
        final key = '${section.section}|||$row';
        answers.add({
          'section': section.section,
          'question': row,
          'answer': _matrixAnswers[key] ?? '',
        });
      }
    }

    answers.add({
      'section': 'Stocks',
      'question': 'Nombre dose SURFANIOS en stock',
      'answer': surfaniosCtrl.text.trim(),
    });
    answers.add({
      'section': 'Commentaires',
      'question': 'COMMENTAIRE FINAL',
      'answer': commentairesCtrl.text.trim(),
    });

    return answers;
  }

  Future<void> _submit() async {
    setState(() => submitted = true);
    if (!_isValid) return;

    setState(() => saving = true);

    try {
      await FirebaseFirestore.instance.collection('vsav_return_submissions').add({
        'formTitle': 'PRODUITS MATERIELS UTILISES VSAV',
        'interventionDate': Timestamp.fromDate(interventionDate!),
        'interventionNumber': interventionNumberCtrl.text.trim(),
        'fullName': selectedController,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.user.uid,
        'createdByEmail': widget.user.email ?? '',
        'answers': _buildAnswers(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Retour Inter VSAV enregistré.')),
      );

      setState(() {
        submitted = false;
        saving = false;
        interventionDate = null;
        selectedController = null;
        bteO25LSac = null;
        bteO25LCellule = null;
        bteO215LCellule = null;
        interventionNumberCtrl.clear();
        surfaniosCtrl.clear();
        commentairesCtrl.clear();
        _matrixAnswers.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
      setState(() => saving = false);
      return;
    }

    if (mounted) {
      setState(() => saving = false);
    }
  }

  Widget _buildSingleChoiceMatrix({
    required String title,
    required Map<String, String?> values,
    required List<String> columns,
    required void Function(String row, String? value) onChanged,
  }) {
    return FormMatrix(
      title: title,
      columns: columns,
      values: values,
      onChanged: onChanged,
    );
  }

  Widget _buildFormMatrixSection(_VsavMatrixSection section) {
    final isOptional = _isOptionalSection(section.section);

    if (section.section == 'DESINFECTION') {
      String? selectedRow;
      for (final row in section.rows) {
        final key = '${section.section}|||$row';
        if ((_matrixAnswers[key] ?? '').trim().isNotEmpty) {
          selectedRow = row;
          break;
        }
      }

      return Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isOptional ? section.section : '${section.section} *',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 12),
              ...section.rows.map((row) {
                final missing = submitted && !isOptional && selectedRow == null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RadioListTile<String>(
                      value: row,
                      groupValue: selectedRow,
                      title: Text(row),
                      contentPadding: EdgeInsets.zero,
                      onChanged: saving
                          ? null
                          : (value) {
                              setState(() {
                                for (final r in section.rows) {
                                  final key = '${section.section}|||$r';
                                  _matrixAnswers[key] =
                                      r == value ? 'Fait et inscrit sur cahier' : '';
                                }
                              });
                            },
                    ),
                    if (missing && row == section.rows.last)
                      const Padding(
                        padding: EdgeInsets.only(left: 16, bottom: 8),
                        child: Text(
                          'Réponse manquante',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      );
    }

    final Map<String, String?> values = {
      for (final row in section.rows) row: _matrixAnswers['${section.section}|||$row'],
    };

    return FormMatrix(
      title: section.section,
      columns: section.columns,
      values: values,
      required: !isOptional,
      showErrors: submitted && !isOptional,
      onChanged: (row, value) {
        setState(() {
          _matrixAnswers['${section.section}|||$row'] = value;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
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
                    const Text(
                      "PRODUITS MATERIELS UTILISES VSAV",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "A REMPLIR APRES TOUTES LES INTERVENTIONS",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "DATE DE L'INTERVENTION *",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : _pickInterventionDate,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(
                          interventionDate == null
                              ? "Choisir la date"
                              : _fmtDate(interventionDate!),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "NUMERO DE L'INTERVENTION *",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: interventionNumberCtrl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Votre réponse",
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "NOM PRENOM DU CA *",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedController,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: controllers
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: saving ? null : (v) => setState(() => selectedController = v),
                    ),
                    if (submitted &&
                        (interventionDate == null ||
                            interventionNumberCtrl.text.trim().isEmpty ||
                            selectedController == null)) ...[
                      const SizedBox(height: 10),
                      Text(
                        "Merci de compléter les champs obligatoires.",
                        style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _buildSingleChoiceMatrix(
              title: "Bte O2 5L du sac",
              values: {"Bte O2 5L du sac": bteO25LSac},
              columns: const ["Supérieur à 50B", "Moins de 50B"],
              onChanged: (row, value) => setState(() => bteO25LSac = value),
            ),
            _buildSingleChoiceMatrix(
              title: "Bte O2 5L cellule",
              values: {"Bte O2 5L cellule": bteO25LCellule},
              columns: const ["Supérieur à 50B", "Moins de 50B"],
              onChanged: (row, value) => setState(() => bteO25LCellule = value),
            ),
            _buildSingleChoiceMatrix(
              title: "Bte O2 15L cellule",
              values: {"Bte O2 15L cellule": bteO215LCellule},
              columns: const ["Supérieur à 50B", "Moins de 50B"],
              onChanged: (row, value) => setState(() => bteO215LCellule = value),
            ),
            ...matrixSections.expand((section) {
              return [
                _buildFormMatrixSection(section),
                const SizedBox(height: 10),
              ];
            }),
            _VsavSimpleTextCard(
              title: "Nombre dose SURFANIOS en stock *",
              controller: surfaniosCtrl,
              keyboardType: TextInputType.number,
            ),
            _VsavTextCommentCard(
              label: "COMMENTAIRE FINAL *",
              controller: commentairesCtrl,
            ),
            const SizedBox(height: 14),
            if (submitted && _hasMissingMatrixAnswer())
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  "Certaines sections obligatoires ne sont pas complétées.",
                  style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text("ENVOYER"),
                onPressed: saving ? null : _submit,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: saving
                    ? null
                    : () {
                        setState(() {
                          submitted = false;
                          interventionDate = null;
                          selectedController = null;
                          bteO25LSac = null;
                          bteO25LCellule = null;
                          bteO215LCellule = null;
                          interventionNumberCtrl.clear();
                          surfaniosCtrl.clear();
                          commentairesCtrl.clear();
                          _matrixAnswers.clear();
                        });
                      },
                child: const Text("EFFACER LE FORMULAIRE"),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
class _VsavTextCommentCard extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _VsavTextCommentCard({
    required this.label,
    required this.controller,
  });

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

class _VsavSimpleTextCard extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const _VsavSimpleTextCard({
    required this.title,
    required this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Votre réponse",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SacPromptSecoursPage extends StatelessWidget {
  final bool isAdmin;
  final User user;

  const SacPromptSecoursPage({
    super.key,
    required this.isAdmin,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      const Tab(text: 'Faire un retour'),
      if (isAdmin) const Tab(text: 'Retours effectués'),
    ];

    final views = <Widget>[
      SacPromptSecoursFormPage(user: user),
      if (isAdmin) const AdminSacPromptSecoursPage(),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(tabs: tabs),
          ),
          Expanded(
            child: TabBarView(children: views),
          ),
        ],
      ),
    );
  }
}

class AdminSacPromptSecoursPage extends StatelessWidget {
  const AdminSacPromptSecoursPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('prompt_secours_submissions')
          .orderBy('createdAt', descending: true)
          .limit(300)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return _ErrorCard(
            title: 'Erreur Firestore',
            message: '${snap.error}',
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _InfoCard(
                title: 'Aucun retour',
                message: 'Aucun formulaire Sac Prompt Secours enregistré pour le moment.',
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Retours Sac Prompt Secours',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            ...docs.map((d) => _SacPromptSecoursTile(doc: d)),
          ],
        );
      },
    );
  }
}

class _SacPromptSecoursTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const _SacPromptSecoursTile({required this.doc});

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  String _fmtDateTime(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} "
      "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final data = doc.data();

    final interventionNumber = (data['interventionNumber'] ?? '').toString();
    final fullName = (data['fullName'] ?? '').toString();
    final email = (data['createdByEmail'] ?? '').toString();

    DateTime? createdAt;
    final createdAtTs = data['createdAt'];
    if (createdAtTs is Timestamp) createdAt = createdAtTs.toDate();

    DateTime? interventionDate;
    final interventionDateTs = data['interventionDate'];
    if (interventionDateTs is Timestamp) {
      interventionDate = interventionDateTs.toDate();
    }

    final subtitleParts = <String>[
      if (interventionDate != null) "Inter : ${_fmtDate(interventionDate)}",
      if (createdAt != null) "Saisi : ${_fmtDateTime(createdAt)}",
      if (email.isNotEmpty) email,
    ];

    return Card(
      elevation: 1.1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListTile(
        leading: const Icon(Icons.emergency_rounded),
        title: Text(
          interventionNumber.isEmpty
              ? (fullName.isEmpty ? 'Sac Prompt Secours' : fullName)
              : "Intervention n° $interventionNumber",
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(subtitleParts.join(' • ')),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SacPromptSecoursDetailPage(doc: doc),
            ),
          );
        },
      ),
    );
  }
}

class SacPromptSecoursDetailPage extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;

  const SacPromptSecoursDetailPage({super.key, required this.doc});

  List<Map<String, dynamic>> _answers() {
    final data = doc.data();
    final raw = data['answers'];

    if (raw is List) {
      final out = <Map<String, dynamic>>[];
      for (final item in raw) {
        if (item is Map) {
          out.add(item.map((k, v) => MapEntry(k.toString(), v)));
        }
      }
      return out;
    }
    return const [];
  }

  static String _answerToString(dynamic v) {
    if (v == null) return '(vide)';
    if (v is bool) return v ? 'Oui' : 'Non';
    if (v is List) return v.isEmpty ? '(vide)' : v.map((e) => e.toString()).join(', ');
    final s = v.toString().trim();
    return s.isEmpty ? '(vide)' : s;
  }

  Future<void> _exportPdf() async {
    final data = doc.data();
    final formTitle = (data['formTitle'] ?? 'Sac Prompt Secours').toString();
    final createdByEmail = (data['createdByEmail'] ?? '').toString();
    final fullName = (data['fullName'] ?? '').toString();
    final interventionNumber = (data['interventionNumber'] ?? '').toString();

    DateTime? createdAt;
    final createdAtTs = data['createdAt'];
    if (createdAtTs is Timestamp) createdAt = createdAtTs.toDate();

    DateTime? interventionDate;
    final interventionDateTs = data['interventionDate'];
    if (interventionDateTs is Timestamp) interventionDate = interventionDateTs.toDate();

    final answers = _answers();

    final Map<String, List<Map<String, dynamic>>> bySection = {};
    for (final a in answers) {
      final sec = (a['section'] ?? 'Général').toString();
      bySection.putIfAbsent(sec, () => []);
      bySection[sec]!.add(a);
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Text(
            formTitle,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (interventionNumber.isNotEmpty) pw.Text('Numéro intervention : $interventionNumber'),
          if (fullName.isNotEmpty) pw.Text('Nom du CA : $fullName'),
          if (interventionDate != null)
            pw.Text(
              'Date de l’intervention : ${DateFormat('dd/MM/yyyy', 'fr_FR').format(interventionDate)}',
            ),
          if (createdAt != null)
            pw.Text(
              'Enregistré le : ${DateFormat('dd/MM/yyyy HH:mm', 'fr_FR').format(createdAt)}',
            ),
          if (createdByEmail.isNotEmpty) pw.Text('Créé par : $createdByEmail'),
          pw.SizedBox(height: 12),
          for (final entry in bySection.entries) ...[
            pw.Text(
              entry.key,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            for (final a in entry.value) ...[
              pw.Text(
                (a['question'] ?? '').toString(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(_answerToString(a['answer'])),
              pw.SizedBox(height: 8),
            ],
            pw.SizedBox(height: 10),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final formTitle = (data['formTitle'] ?? 'Sac Prompt Secours').toString();
    final answers = _answers();

    return Scaffold(
      appBar: AppBar(
        title: Text(formTitle),
        actions: [
          IconButton(
            tooltip: 'Exporter PDF',
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1.1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Submission: ${doc.id}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...answers.map((a) {
            final section = (a['section'] ?? '').toString();
            final q = (a['question'] ?? '').toString();
            final ans = _answerToString(a['answer']);

            return Card(
              elevation: 1.1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              child: ListTile(
                title: Text(q, style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(ans),
                trailing: section.isEmpty ? null : Text(section),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _PromptMatrixSection {
  final String section;
  final List<String> columns;
  final List<String> rows;

  const _PromptMatrixSection({
    required this.section,
    required this.columns,
    required this.rows,
  });
}

class SacPromptSecoursFormPage extends StatefulWidget {
  final User user;
  const SacPromptSecoursFormPage({super.key, required this.user});

  @override
  State<SacPromptSecoursFormPage> createState() => _SacPromptSecoursFormPageState();
}

class _SacPromptSecoursFormPageState extends State<SacPromptSecoursFormPage> {
  static const List<String> controllers = [
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

  static const Set<String> optionalSections = {
    'POCHETTE JAUNE',
    'POCHETTE ROUGE',
    'SAC ROUGE',
  };

  DateTime? interventionDate;
  final TextEditingController interventionNumberCtrl = TextEditingController();
  String? selectedController;
  String? bouteilleO2;

  final TextEditingController commentairesCtrl = TextEditingController();

  bool saving = false;
  bool submitted = false;

  final Map<String, String> _matrixAnswers = {};

  static const List<String> twoChoicesBottle = [
    'Supérieur à 50B',
    'Inférieur à 50B',
  ];

  static const List<_PromptMatrixSection> matrixSections = [
    _PromptMatrixSection(
      section: 'SAC ROUGE',
      columns: ['Pris stock/Mis sac', 'Manque dans sac'],
      rows: [
        'Collier cervical adulte',
        'Collier cervical enfant',
        'Bavu adulte',
        'Bavu enfant',
        'Masque HC adulte',
        'Lunettes O2',
        'Masque HC enfant',
        'Couverture de survie',
        'Poche à froid',
        'Pansements absorbants',
        'Poche vomix',
        'Canule guedel T.00',
        'Canule guedel T. 0',
        'Canule guedel T. 1',
        'Canule guedel T. 2',
        'Canule guedel T. 3',
        'Canule guedel T. 4',
        'Couverture bleue',
        'Compresses brulures',
        'Gants / 3 masques chir.',
        'Lunettes + FFP2',
        'Fiches bilan',
        'Poches DASRI jaunes',
        'DSA',
        'Electrodes',
        'Rasoirs',
      ],
    ),
    _PromptMatrixSection(
      section: 'POCHETTE JAUNE',
      columns: ['Chargé', 'En charge'],
      rows: ['Tensiomètre', 'Oxymètre'],
    ),
    _PromptMatrixSection(
      section: 'POCHETTE ROUGE',
      columns: ['Pris au stock/Mis sac', 'Pas en stock'],
      rows: [
        'Echarpes triangulaire',
        'Ciseaux GESCO',
        'Chlorure sodium 10 ml',
        'Chlorure sodium 45 ml',
        'Bande 7cm',
        'Filet tubulaire tête',
        'Dacudose',
        'C.H.U.T',
        'Sparadrap',
        'Compresses stériles',
        'Sangle garrot',
        'Garrot tourniquet',
      ],
    ),
  ];

  @override
  void dispose() {
    interventionNumberCtrl.dispose();
    commentairesCtrl.dispose();
    super.dispose();
  }

  bool _isOptionalSection(String section) => optionalSections.contains(section);

  String _fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";

  bool _hasMissingMatrixAnswer() {
    for (final section in matrixSections) {
      if (_isOptionalSection(section.section)) {
        continue;
      }

      for (final row in section.rows) {
        final key = '${section.section}|||$row';
        if ((_matrixAnswers[key] ?? '').trim().isEmpty) {
          return true;
        }
      }
    }

    return false;
  }

  bool get _isValid =>
      interventionDate != null &&
      interventionNumberCtrl.text.trim().isNotEmpty &&
      selectedController != null &&
      bouteilleO2 != null &&
      commentairesCtrl.text.trim().isNotEmpty &&
      !_hasMissingMatrixAnswer();

  Future<void> _pickInterventionDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: interventionDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null && mounted) {
      setState(() => interventionDate = picked);
    }
  }

  List<Map<String, dynamic>> _buildAnswers() {
    final answers = <Map<String, dynamic>>[
      {
        'section': 'Général',
        'question': 'Date de l\'intervention',
        'answer': interventionDate != null ? _fmtDate(interventionDate!) : '',
      },
      {
        'section': 'Général',
        'question': 'Numéro de l\'intervention',
        'answer': interventionNumberCtrl.text.trim(),
      },
      {
        'section': 'Général',
        'question': 'Nom du CA',
        'answer': selectedController ?? '',
      },
      {
        'section': 'BOUTEILLES O2',
        'question': 'BOUTEILLES O2',
        'answer': bouteilleO2 ?? '',
      },
    ];

    for (final section in matrixSections) {
      for (final row in section.rows) {
        final key = '${section.section}|||$row';
        answers.add({
          'section': section.section,
          'question': row,
          'answer': _matrixAnswers[key] ?? '',
        });
      }
    }

    answers.add({
      'section': 'Commentaires',
      'question': 'COMMENTAIRE FINAL',
      'answer': commentairesCtrl.text.trim(),
    });

    return answers;
  }

  Future<void> _submit() async {
    setState(() => submitted = true);
    if (!_isValid) return;

    setState(() => saving = true);

    try {
      await FirebaseFirestore.instance.collection('prompt_secours_submissions').add({
        'formTitle': 'Sac Prompt Secours',
        'interventionDate': Timestamp.fromDate(interventionDate!),
        'interventionNumber': interventionNumberCtrl.text.trim(),
        'fullName': selectedController,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': widget.user.uid,
        'createdByEmail': widget.user.email ?? '',
        'answers': _buildAnswers(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sac Prompt Secours enregistré.')),
      );

      setState(() {
        submitted = false;
        saving = false;
        interventionDate = null;
        selectedController = null;
        bouteilleO2 = null;
        interventionNumberCtrl.clear();
        commentairesCtrl.clear();
        _matrixAnswers.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
      setState(() => saving = false);
      return;
    }

    if (mounted) {
      setState(() => saving = false);
    }
  }

  Widget _buildSingleChoiceMatrix({
    required String title,
    required Map<String, String?> values,
    required List<String> columns,
    required void Function(String row, String? value) onChanged,
  }) {
    return FormMatrix(
      title: title,
      columns: columns,
      values: values,
      onChanged: onChanged,
    );
  }

  Widget _buildFormMatrixSection(_PromptMatrixSection section) {
    final isOptional = _isOptionalSection(section.section);

    final Map<String, String?> values = {
      for (final row in section.rows) row: _matrixAnswers['${section.section}|||$row'],
    };

    return FormMatrix(
      title: section.section,
      columns: section.columns,
      values: values,
      required: !isOptional,
      showErrors: submitted && !isOptional,
      onChanged: (row, value) {
        setState(() {
          _matrixAnswers['${section.section}|||$row'] = value;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
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
                    const Text(
                      "SAC PROMPT SECOURS",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Date de l'intervention *",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: saving ? null : _pickInterventionDate,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(
                          interventionDate == null
                              ? "Choisir la date"
                              : _fmtDate(interventionDate!),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Numéro de l'intervention *",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: interventionNumberCtrl,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Votre réponse",
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Nom du CA *",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: selectedController,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: controllers
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: saving ? null : (v) => setState(() => selectedController = v),
                    ),
                    if (submitted &&
                        (interventionDate == null ||
                            interventionNumberCtrl.text.trim().isEmpty ||
                            selectedController == null)) ...[
                      const SizedBox(height: 10),
                      Text(
                        "Merci de compléter les champs obligatoires.",
                        style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _buildSingleChoiceMatrix(
              title: "BOUTEILLES O2",
              values: {"BOUTEILLES O2": bouteilleO2},
              columns: twoChoicesBottle,
              onChanged: (row, value) => setState(() => bouteilleO2 = value),
            ),
            const SizedBox(height: 10),
            ...matrixSections.expand((section) {
              return [
                _buildFormMatrixSection(section),
                const SizedBox(height: 10),
              ];
            }),
            _VsavTextCommentCard(
              label: "COMMENTAIRE FINAL *",
              controller: commentairesCtrl,
            ),
            const SizedBox(height: 14),
            if (submitted && _hasMissingMatrixAnswer())
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  "Certaines sections obligatoires ne sont pas complétées.",
                  style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text("ENVOYER"),
                onPressed: saving ? null : _submit,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: saving
                    ? null
                    : () {
                        setState(() {
                          submitted = false;
                          interventionDate = null;
                          selectedController = null;
                          bouteilleO2 = null;
                          interventionNumberCtrl.clear();
                          commentairesCtrl.clear();
                          _matrixAnswers.clear();
                        });
                      },
                child: const Text("EFFACER LE FORMULAIRE"),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class TicketCreatePage extends StatefulWidget {
  const TicketCreatePage({super.key});

  @override
  State<TicketCreatePage> createState() => _TicketCreatePageState();
}

class _TicketCreatePageState extends State<TicketCreatePage>
    with SingleTickerProviderStateMixin {
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController messageCtrl = TextEditingController();

  late final TabController _tabController;

  String ticketType = 'Idée';
  bool saving = false;
  bool submitted = false;
  bool isAdmin = false;
  bool loadingAdmin = true;

  static const List<String> ticketTypes = [
    'Idée',
    'Remarque',
    'Réclamation',
    'Bug',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAdminStatus();
  }

  Future<void> _loadAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        isAdmin = false;
        loadingAdmin = false;
      });
      return;
    }

    final admin = await AdminService.isAdmin(user.uid);

    if (!mounted) return;
    setState(() {
      isAdmin = admin;
      loadingAdmin = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    titleCtrl.dispose();
    messageCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      titleCtrl.text.trim().isNotEmpty &&
      messageCtrl.text.trim().isNotEmpty;

  Future<void> _submit() async {
    setState(() => submitted = true);
    if (!_isValid) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => saving = true);

    try {
      await FirebaseFirestore.instance.collection('tickets').add({
        'title': titleCtrl.text.trim(),
        'message': messageCtrl.text.trim(),
        'type': ticketType,
        'status': 'ouvert',
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.uid,
        'createdByEmail': user.email ?? '',
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ticket envoyé.')),
      );

      setState(() {
        submitted = false;
        saving = false;
        ticketType = 'Idée';
        titleCtrl.clear();
        messageCtrl.clear();
      });

      if (isAdmin) {
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
      setState(() => saving = false);
    }
  }

  Widget _buildCreateTab(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Idée / Réclamation',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 10),
        const _InfoCard(
          title: 'Boîte à idées',
          message:
              'Tu peux envoyer ici une idée, une remarque, une réclamation ou signaler un bug. '
              'Le message sera transmis aux administrateurs.',
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 1.1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: ticketType,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                  ),
                  items: ticketTypes
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e,
                          child: Text(e),
                        ),
                      )
                      .toList(),
                  onChanged: saving
                      ? null
                      : (v) {
                          if (v != null) {
                            setState(() => ticketType = v);
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  enabled: !saving,
                  decoration: InputDecoration(
                    labelText: 'Titre *',
                    border: const OutlineInputBorder(),
                    errorText: submitted && titleCtrl.text.trim().isEmpty
                        ? 'Champ obligatoire'
                        : null,
                  ),
                  onChanged: (_) {
                    if (submitted) setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageCtrl,
                  enabled: !saving,
                  minLines: 6,
                  maxLines: 10,
                  decoration: InputDecoration(
                    labelText: 'Message *',
                    alignLabelWithHint: true,
                    border: const OutlineInputBorder(),
                    errorText: submitted && messageCtrl.text.trim().isEmpty
                        ? 'Champ obligatoire'
                        : null,
                  ),
                  onChanged: (_) {
                    if (submitted) setState(() {});
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: saving ? null : _submit,
                    icon: saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(saving ? 'Envoi...' : 'Envoyer'),
                  ),
                ),
                if (submitted && !_isValid) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Merci de compléter les champs obligatoires.',
                    style: TextStyle(
                      color: cs.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminTicketsTab(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('tickets')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ErrorCard(
                title: 'Erreur Firestore',
                message: '${snap.error}',
              ),
            ],
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;

        if (docs.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _InfoCard(
                title: 'Tickets',
                message: 'Aucun ticket reçu pour le moment.',
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Tickets reçus',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            ...docs.map((doc) {
              final data = doc.data();
              final title = (data['title'] ?? '').toString().trim();
              final message = (data['message'] ?? '').toString().trim();
              final type = (data['type'] ?? 'Ticket').toString().trim();
              final status = (data['status'] ?? 'ouvert').toString().trim();
              final email = (data['createdByEmail'] ?? '').toString().trim();

              DateTime? createdAt;
              final ts = data['createdAt'];
              if (ts is Timestamp) createdAt = ts.toDate();

              Color statusColor() {
                switch (status) {
                  case 'traite':
                    return const Color(0xFF2E7D32);
                  case 'ferme':
                    return const Color(0xFF5E647B);
                  default:
                    return const Color(0xFFB26A00);
                }
              }

              Future<void> setStatus(String newStatus) async {
                try {
                  await doc.reference.update({
                    'status': newStatus,
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ticket marqué "$newStatus".')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e')),
                  );
                }
              }

              Future<void> deleteTicket() async {
                try {
                  await doc.reference.delete();

                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ticket supprimé.')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur : $e')),
                  );
                }
              }

              return Card(
                elevation: 1.1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title.isEmpty ? '(Sans titre)' : title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor().withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor(),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        type,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(message.isEmpty ? '(Vide)' : message),
                      const SizedBox(height: 10),
                      Text(
                        [
                          if (email.isNotEmpty) email,
                          if (createdAt != null)
                            DateFormat('dd/MM/yyyy HH:mm', 'fr_FR')
                                .format(createdAt),
                        ].join(' • '),
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => setStatus('ouvert'),
                            child: const Text('Ouvrir'),
                          ),
                          OutlinedButton(
                            onPressed: () => setStatus('traite'),
                            child: const Text('Traité'),
                          ),
                          OutlinedButton(
                            onPressed: () => setStatus('ferme'),
                            child: const Text('Fermé'),
                          ),
                          OutlinedButton.icon(
                            onPressed: deleteTicket,
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Supprimer'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loadingAdmin) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!isAdmin) {
      return _buildCreateTab(context);
    }

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Envoyer'),
              Tab(text: 'Tickets reçus'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCreateTab(context),
              _buildAdminTicketsTab(context),
            ],
          ),
        ),
      ],
    );
  }
}





class _InfoCard extends StatelessWidget {
  final String title;
  final String message;
  const _InfoCard({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 1.1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: cs.primary)),
            const SizedBox(height: 6),
            Text(message),
          ],
        ),
      ),
    );
  }
}
