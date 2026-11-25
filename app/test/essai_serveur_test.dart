import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nautilink/depot/depot.dart';
import 'package:nautilink/reel/api.dart';
import 'package:nautilink/reel/base_locale.dart';
import 'package:nautilink/reel/depot_reel.dart';
import 'package:nautilink/reel/stockage_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Essai de bout en bout contre un vrai serveur NautiLink lancé à part
/// (`server/`, base PostgreSQL jetable), sauté sans `NAUTILINK_API_ESSAI` :
///
/// ```bash
/// NAUTILINK_API_ESSAI=http://127.0.0.1:8091/nautilink/api \
/// NAUTILINK_BASE_ESSAI='postgres://nautilink@127.0.0.1:5451/nautilink' \
///   flutter test test/essai_serveur_test.dart
/// ```
///
/// `NAUTILINK_BASE_ESSAI` (facultatif, `psql` requis) confirme l'adresse du
/// compte créé, pour essayer aussi le démarrage par la file d'attente.
final adresse = Platform.environment['NAUTILINK_API_ESSAI'];
final baseEssai = Platform.environment['NAUTILINK_BASE_ESSAI'];

void main() {
  test(
    'bout en bout : compte, téléphone, bateau, accueil, file d\'attente, renouvellement',
    () async {
      SharedPreferences.setMockInitialValues({});
      final session = await StockageSession.ouvrir();
      final d = DepotReel(
        api: ClientApi(base: adresse!, session: session),
        session: session,
        base: BaseMemoire(),
        plateforme: 'android',
        nomAppareil: 'Essai de bout en bout',
      );
      await d.ouvrir();
      expect(d.etatSession, EtatSession.deconnecte);

      final email = 'essai${DateTime.now().microsecondsSinceEpoch}@example.org';
      await d.creerCompte(
        nom: 'Essai',
        email: email,
        motDePasse: 'motdepasse-essai',
        avertissementVersion: await d.versionAvertissement(),
        langue: 'fr',
      );
      expect(d.etatSession, EtatSession.connecte);
      expect(d.profil?.email, email);
      expect(d.profil?.emailVerifie, isFalse);
      expect(d.quota, isNotNull);

      // Bateau créé après le compte, puis associé à ce téléphone (Q-81).
      final bateau = await d.api.appelObjet(
        'POST',
        '/v1/bateaux',
        json: {'nom': 'Alizé', 'type': 'voilier'},
      );
      await d.associerTelephone();
      expect(d.erreurAssociation, isNull);
      final appareil = await session.appareilId();
      final fiche = await d.api.appelObjet(
        'GET',
        '/v1/bateaux/${bateau['id']}',
      );
      expect(fiche['appareilAssocieId'], appareil);

      // Session : jeton d'accès refusé, renouvelé une fois (RG-CPT-12).
      await session.enregistrer({
        'jetonAcces': 'jeton-faux',
        'jetonRenouvellement': session.jetonRenouvellement,
      });
      await d.actualiser();
      expect(d.horsConnexion, isFalse);
      expect(session.jetonAcces, isNot('jeton-faux'));
      expect(d.bateaux.single.nom, 'Alizé');

      // Déconnexion puis reconnexion par e-mail et mot de passe.
      await d.deconnecter();
      expect(d.etatSession, EtatSession.deconnecte);
      await d.connexion(email, 'motdepasse-essai');
      expect(d.etatSession, EtatSession.connecte);
      await d.motDePasseOublie(email);

      if (baseEssai == null) return;
      final r = await Process.run('psql', [
        baseEssai!,
        '-c',
        "UPDATE utilisateurs SET email_verifie_le = now() WHERE email = '$email'",
      ]);
      expect(r.exitCode, 0, reason: '${r.stderr}');

      // File d'attente : démarrage, événements, alerte SOS et fin (RG-COM-05).
      final nav = d.envois.nouvelId();
      final t0 = DateTime.now().subtract(const Duration(minutes: 20));
      Map<String, Object?> pos(int m) => {
        'latitude': 47.48 - m / 1000,
        'longitude': -3.10,
        'heureAcquisition': heureRfc3339(t0.add(Duration(minutes: m))),
      };
      await d.envois.demarrage(nav, {
        'bateauId': bateau['id'],
        'appareilId': appareil,
        'frequenceMinutes': 15,
        'personnesABord': 2,
        'personnesAlertees': <String>[],
        'debut': {
          'type': 'debut',
          'heureAcquisition': heureRfc3339(t0),
          'position': pos(0),
          'gpsDisponible': true,
        },
      });
      await d.envois.evenement(nav, {
        'type': 'position_automatique',
        'heureAcquisition': heureRfc3339(t0.add(const Duration(minutes: 5))),
        'position': pos(5),
        'gpsDisponible': true,
      });
      final note = await d.envois.evenement(nav, {
        'type': 'note',
        'texte': 'Tout va bien',
        'heureAcquisition': heureRfc3339(t0.add(const Duration(minutes: 8))),
      });
      await d.envois.alerteSos(d.envois.nouvelId(), {
        'bateauId': bateau['id'],
        'navigationId': nav,
        'appareilId': appareil,
        'heureDeclenchement': heureRfc3339(t0.add(const Duration(minutes: 10))),
        'position': pos(10),
        'naturePosition': 'actuelle',
        'problemeRencontre': 'Essai de bout en bout',
        'personnesABord': 2,
      });
      await d.envois.fin(nav, {
        'heureAcquisition': heureRfc3339(t0.add(const Duration(minutes: 15))),
        'position': pos(15),
        'gpsDisponible': true,
      });
      await d.file.attendrePasse();
      await d.file.envoyer();
      expect(await d.base.elementsMisDeCote(), isEmpty);
      expect(await d.envois.enAttente(), 0);

      // Un renvoi (réponse perdue) ne crée pas de doublon : 200 (08-architecture.md §5).
      final statuts = <int>[];
      final abonnement = d.envois.reussis.listen((e) => statuts.add(e.statut));
      await d.envois.evenement(nav, note);
      await d.file.attendrePasse();
      await abonnement.cancel();
      expect(statuts, [200]);
      final journal = await d.api.appelObjet(
        'GET',
        '/v1/navigations/$nav/evenements',
      );
      final notes = (journal['evenements'] as List).where(
        (e) => (e as Map)['type'] == 'note',
      );
      expect(notes.length, 1);

      await d.actualiser();
      final n = d.navigations.firstWhere((n) => n.id == nav);
      expect(n.enCours, isFalse);
      expect(d.navigationEnCours, isNull);
      expect(d.quota!.consommeMinutes, greaterThanOrEqualTo(15));
      expect(
        d.alertes.map((a) => a.problemeRencontre),
        contains('Essai de bout en bout'),
      );
    },
    skip: adresse == null
        ? 'NAUTILINK_API_ESSAI non défini : pas de serveur à essayer'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
