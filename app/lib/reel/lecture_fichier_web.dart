Future<List<int>> lireFichier(String chemin) =>
    Future.error(UnsupportedError('Pas de fichiers locaux sur le Web'));

Future<String> dossierEnvois() =>
    Future.error(UnsupportedError('Pas de fichiers locaux sur le Web'));

Future<int> tailleFichier(String chemin) async => 0;
