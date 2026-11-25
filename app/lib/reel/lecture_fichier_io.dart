import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<List<int>> lireFichier(String chemin) => File(chemin).readAsBytes();

Future<String> dossierEnvois() async {
  final d = Directory(
    '${(await getApplicationDocumentsDirectory()).path}/envois',
  );
  await d.create(recursive: true);
  return d.path;
}

Future<int> tailleFichier(String chemin) => File(chemin).length();

Future<void> effacerFichier(String chemin) async {
  final f = File(chemin);
  if (await f.exists()) await f.delete();
}
