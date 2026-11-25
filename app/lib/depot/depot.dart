import 'package:flutter/widgets.dart';

import 'modeles.dart';

export 'modeles.dart';

/// État de la session de l'utilisateur sur le téléphone (RG-CPT-08, RG-CPT-12).
enum EtatSession { chargement, deconnecte, connecte }

/// Envoi réussi par le circuit Internet : réponse 200 ou 201 du serveur
/// (08-architecture.md §5, « Chronomètre du dernier envoi », RG-NAV-10).
class EnvoiReussi {
  const EnvoiReussi(this.operation, this.id, this.navigationId, this.statut);
  final String operation;
  final String id;
  final String? navigationId;
  final int statut;
}

/// Envois du téléphone vers le serveur, tous par la file d'attente
/// (RG-COM-05, 08-architecture.md §5) : chaque envoi est enregistré sur le
/// téléphone avant toute tentative, avec un identifiant UUID v4 et un numéro
/// d'ordre par navigation.
///
/// Interface prévue pour le démarrage (TODO-5.2), les positions et le journal
/// (TODO-5.3, TODO-5.4), la fin (TODO-5.6) et le SOS (TODO-5.5) ; les contenus
/// sont les corps JSON des appels unitaires de `docs/api/openapi.yaml`.
abstract class Envois {
  /// Nouvel identifiant UUID v4, tiré par le téléphone (navigation, événement, alerte).
  String nouvelId();

  /// Démarrage (`PUT /v1/navigations/{id}`, opération `demarrage`) ; contenu
  /// `DemarrageNavigation`. L'événement `debut` reçoit son identifiant et le
  /// numéro d'ordre 1 s'il n'en a pas. Rend le contenu complété.
  Future<Map<String, Object?>> demarrage(
    String navigationId,
    Map<String, Object?> contenu,
  );

  /// Événement du journal (`PUT /v1/navigations/{n}/evenements/{e}`, opération
  /// `evenement`) ; schéma `Evenement`. `id` et `numeroOrdre` sont ajoutés s'ils
  /// manquent. Rend l'événement complété.
  Future<Map<String, Object?>> evenement(
    String navigationId,
    Map<String, Object?> evenement,
  );

  /// Fin de navigation (`PUT /v1/navigations/{id}/fin`, opération `fin`), avec
  /// son heure réelle (RG-NAV-14). Rend l'événement complété.
  Future<Map<String, Object?>> fin(
    String navigationId,
    Map<String, Object?> evenement,
  );

  /// Alerte SOS (`PUT /v1/alertes-sos/{id}`) : part avant tout le reste.
  Future<void> alerteSos(String alerteId, Map<String, Object?> alerte);

  /// Statuts des SMS SOS (`PUT /v1/alertes-sos/{id}/sms`, opération `statuts_sms`).
  Future<void> statutsSms(String alerteId, List<Map<String, Object?>> statuts);

  /// Fichier d'une photo (`image/jpeg`) ou d'une note vocale (`audio/mp4`),
  /// déposé après les éléments légers et après son événement (`PUT /v1/fichiers/{id}`).
  Future<void> fichier(String evenementId, String chemin, String typeMedia);

  /// Relance la file : retour de la connexion, ouverture de l'application.
  Future<void> relancer();

  /// Éléments encore à envoyer.
  Future<int> enAttente();

  /// Envois réussis, pour le chronomètre du dernier envoi (RG-NAV-10).
  Stream<EnvoiReussi> get reussis;
}

/// Position du téléphone (RG-GPS-01, RG-SOS-09 à RG-SOS-11). Interface prévue
/// pour les positions automatiques (TODO-5.3) et le SOS (TODO-5.5).
abstract class SourcePosition {
  /// Position actuelle, ou vide si le GPS ne répond pas.
  Future<PositionGps?> positionActuelle();

  /// Dernière position connue, si le GPS a déjà répondu.
  PositionGps? get derniereConnue;
}

/// Dépôt de données de l'application : navigations, bateaux, contacts,
/// paramètres, quota et alertes SOS, avec la session de l'utilisateur.
///
/// Deux implémentations (D-127) : [demonstration] vrai pour les données
/// d'exemple du prototype (`lib/data.dart`, rien n'est envoyé), faux pour la
/// vraie application branchée sur le serveur, avec sa base locale et sa file
/// d'attente (`lib/reel/`).
abstract class Depot extends ChangeNotifier {
  bool get demonstration;

  EtatSession get etatSession;

  /// Vrai quand le dernier échange avec le serveur a échoué faute de
  /// connexion : l'application montre ses données locales (RG-COM-06).
  bool get horsConnexion;

  /// Heure du dernier échange réussi avec le serveur.
  DateTime? get actualiseLe;

  ProfilNl? get profil;

  /// Navigations du compte : en cours d'abord, puis de la plus récente à la plus ancienne.
  List<ResumeNavigation> get navigations;

  /// Navigation en cours du navigateur sur ce téléphone (« Reprendre la dernière navigation », RG-NAV-12).
  ResumeNavigation? get navigationEnCours {
    for (final n in navigations) {
      if (n.enCours && !n.commeSuiveur) return n;
    }
    return null;
  }

  List<BateauNl> get bateaux;
  List<ContactNl> get contacts;
  ParametresGeneraux? get parametres;
  EtatQuota? get quota;
  List<AlerteSosResume> get alertes;

  Envois get envois;
  SourcePosition get positions;

  /// Charge les données locales, puis lance une actualisation.
  Future<void> ouvrir();

  /// Relit le serveur (accueil, quota, contacts, paramètres) ; hors connexion,
  /// garde les données locales.
  Future<void> actualiser();

  /// Ferme la session ; la file d'attente reste (RG-CPT-08).
  Future<void> deconnecter();
}

/// Donne le dépôt à tous les écrans.
class DepotScope extends InheritedNotifier<Depot> {
  const DepotScope({super.key, required Depot depot, required super.child})
    : super(notifier: depot);

  static Depot of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DepotScope>()!.notifier!;
}
