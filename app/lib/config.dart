/// Réglages choisis à la construction (D-127).
///
/// - `--dart-define=NAUTILINK_MODE=demo|reel` : démonstration (données
///   d'exemple, rien n'est envoyé ; par défaut, pour le site et le workflow
///   « Site GitHub Pages ») ou vraie application branchée sur le serveur.
/// - `--dart-define=NAUTILINK_API=<adresse>` : point d'entrée de l'API
///   (08-architecture.md §4), sans `/v1` final.
library;

enum ModeApplication { demo, reel }

const String _mode = String.fromEnvironment(
  'NAUTILINK_MODE',
  defaultValue: 'demo',
);

/// Mode choisi à la construction ; toute valeur autre que `reel` donne la démonstration.
const ModeApplication kMode = _mode == 'reel'
    ? ModeApplication.reel
    : ModeApplication.demo;

/// Adresse de l'API du serveur central (D-62, 08-architecture.md §4).
const String kApiUrl = String.fromEnvironment(
  'NAUTILINK_API',
  defaultValue: 'https://vdl.moulard.org/nautilink/api',
);

/// Achat unique de 10 ans, même identifiant sur Google Play et l'App Store
/// (RG-ECO-06, `NAUTILINK_PRODUIT` du serveur).
const String kProduit = String.fromEnvironment(
  'NAUTILINK_PRODUIT',
  defaultValue: 'nautilink_abonnement_10_ans',
);

/// Connexion par Google (RG-CPT-02, RG-CPT-11) : identifiant client OAuth de
/// type Web, que le serveur accepte (`NAUTILINK_GOOGLE_CLIENTS`) ; sur iPhone,
/// aussi l'identifiant client iOS. Vide : bouton désactivé.
const String kGoogleServeur = String.fromEnvironment(
  'NAUTILINK_GOOGLE_SERVEUR',
);
const String kGoogleClientIos = String.fromEnvironment('NAUTILINK_GOOGLE_IOS');

/// Connexion par Apple sur iPhone : `--dart-define=NAUTILINK_APPLE=1` une
/// fois la capacité « Sign in with Apple » ajoutée à l'application.
const bool kAppleConnexion = bool.fromEnvironment('NAUTILINK_APPLE');

/// Notifications push (RG-IOS-06, RG-AND-08) : application Firebase de la
/// plateforme ; vides : pas de notifications. Sur iPhone, le jeton APNs est
/// envoyé au serveur, qui passe par APNs (D-86).
const String kFcmCle = String.fromEnvironment('NAUTILINK_FCM_CLE');
const String kFcmApplication = String.fromEnvironment(
  'NAUTILINK_FCM_APPLICATION',
);
const String kFcmExpediteur = String.fromEnvironment(
  'NAUTILINK_FCM_EXPEDITEUR',
);
const String kFcmProjet = String.fromEnvironment('NAUTILINK_FCM_PROJET');
