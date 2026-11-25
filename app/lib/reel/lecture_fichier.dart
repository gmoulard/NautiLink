import 'lecture_fichier_web.dart'
    if (dart.library.io) 'lecture_fichier_io.dart'
    as impl;

/// Lit le fichier d'une photo ou d'une note vocale à déposer sur le serveur.
Future<List<int>> lireFichier(String chemin) => impl.lireFichier(chemin);

/// Dossier des photos et notes vocales en attente d'envoi, gardé jusqu'à leur
/// dépôt sur le serveur (dossier de l'application, pas le cache).
Future<String> dossierEnvois() => impl.dossierEnvois();

/// Taille du fichier, en octets.
Future<int> tailleFichier(String chemin) => impl.tailleFichier(chemin);

/// Efface un fichier déposé sur le serveur ; sans erreur s'il n'existe plus.
Future<void> effacerFichier(String chemin) => impl.effacerFichier(chemin);
