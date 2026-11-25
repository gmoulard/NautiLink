import 'lecture_fichier_web.dart'
    if (dart.library.io) 'lecture_fichier_io.dart'
    as impl;

/// Lit le fichier d'une photo ou d'une note vocale à déposer sur le serveur.
Future<List<int>> lireFichier(String chemin) => impl.lireFichier(chemin);
