import 'dart:io';

Future<List<int>> lireFichier(String chemin) => File(chemin).readAsBytes();
