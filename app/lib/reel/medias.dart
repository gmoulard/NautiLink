import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import 'lecture_fichier.dart' as fichiers;

/// Fichier d'une photo ou d'une note vocale, gardé sur le téléphone jusqu'à
/// son dépôt sur le serveur (`PUT /v1/fichiers/{id}`).
class FichierMedia {
  const FichierMedia(this.chemin, this.tailleOctets);
  final String chemin;
  final int tailleOctets;
}

/// Photos et notes vocales du téléphone (TODO-5.4).
abstract class Medias {
  /// « Photo » : appareil photo du téléphone (RG-AND-06), photo réduite pour
  /// approcher 1 Mo (RG-JRN-08) ; vide si le navigateur annule.
  Future<FichierMedia?> photo(String evenementId);

  /// « Vocal » : commence l'enregistrement, AAC dans un fichier `.m4a`
  /// (RG-JRN-04, D-53) ; faux si le micro est refusé.
  Future<bool> commencerVocal(String evenementId);

  /// Arrête l'enregistrement et rend son fichier.
  Future<FichierMedia?> arreterVocal();

  /// Abandonne l'enregistrement en cours.
  Future<void> annulerVocal();

  /// Efface la copie gardée sur le téléphone, une fois le fichier déposé.
  Future<void> oublier(String evenementId);
}

/// Appareil photo (paquet `image_picker`, sans autorisation `CAMERA` :
/// l'application appareil photo du téléphone prend la photo, RG-AND-06) et
/// micro (paquet `record`, autorisation `RECORD_AUDIO` demandée au premier
/// « Vocal », RG-AND-02).
class MediasTelephone implements Medias {
  final _photos = ImagePicker();
  AudioRecorder? _micro;
  String? _cheminVocal;

  @override
  Future<FichierMedia?> photo(String evenementId) async {
    final x = await _photos.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 80,
    );
    if (x == null) return null;
    final chemin = '${await fichiers.dossierEnvois()}/$evenementId.jpg';
    await x.saveTo(chemin);
    return FichierMedia(chemin, await fichiers.tailleFichier(chemin));
  }

  @override
  Future<bool> commencerVocal(String evenementId) async {
    final m = _micro ??= AudioRecorder();
    if (!await m.hasPermission()) return false;
    final chemin = '${await fichiers.dossierEnvois()}/$evenementId.m4a';
    // Mono, 32 kbit/s : environ 240 ko par minute (étude des notes vocales).
    await m.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 22050,
        numChannels: 1,
      ),
      path: chemin,
    );
    _cheminVocal = chemin;
    return true;
  }

  @override
  Future<FichierMedia?> arreterVocal() async {
    final chemin = await _micro?.stop() ?? _cheminVocal;
    _cheminVocal = null;
    if (chemin == null) return null;
    try {
      return FichierMedia(chemin, await fichiers.tailleFichier(chemin));
    } catch (e) {
      debugPrint('Note vocale : $e');
      return null;
    }
  }

  @override
  Future<void> annulerVocal() async {
    _cheminVocal = null;
    await _micro?.cancel();
  }

  @override
  Future<void> oublier(String evenementId) async {
    try {
      final d = await fichiers.dossierEnvois();
      await fichiers.effacerFichier('$d/$evenementId.jpg');
      await fichiers.effacerFichier('$d/$evenementId.m4a');
    } catch (e) {
      debugPrint('Effacement du fichier : $e');
    }
  }
}
