import 'package:flutter_test/flutter_test.dart';
import 'package:nautilink/depot/depot.dart';
import 'package:nautilink/reel/api.dart';
import 'package:nautilink/reel/base_locale.dart';
import 'package:nautilink/reel/stockage_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'faux_serveur.dart';

void main() {
  late FauxServeurNautiLink serveur;
  late BaseLocale base;
  late StockageSession session;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    session = await StockageSession.ouvrir();
    base = BaseMemoire();
    serveur = FauxServeurNautiLink();
  });

  test('connexion : session gardée, téléphone enregistré puis associé aux bateaux sans téléphone, accueil rempli', () async {
    final d = serveur.depot(session, base);
    await d.ouvrir();
    expect(d.etatSession, EtatSession.deconnecte);

    await d.connexion(' Marin@Example.org ', 'secret123');
    expect(d.etatSession, EtatSession.connecte);
    expect(session.jetonAcces, 'A1');
    expect(session.compteEmail, 'marin@example.org');

    final id = await session.appareilId();
    expect(
      serveur.appels,
      containsAllInOrder([
        'POST /v1/sessions',
        'PUT /v1/appareils/$id',
        'GET /v1/bateaux',
        'PUT /v1/bateaux/b1/telephone',
        'GET /v1/compte',
      ]),
    );
    expect(serveur.appels, isNot(contains('PUT /v1/bateaux/b2/telephone')));
    expect(serveur.corps['PUT /v1/appareils/$id'], {
      'plateforme': 'android',
      'nom': 'Essai',
      'versionApplication': '1.0.0',
    });
    expect(serveur.corps['PUT /v1/bateaux/b1/telephone'], {'appareilId': id});

    expect(d.navigationEnCours?.nom, 'Alizé — Houat');
    expect(d.navigations.length, 2);
    expect(d.quota?.disponibleMinutes, 1140);
    expect(d.quota?.prochainesMinutes, 240);
    expect(d.contacts.single.nom, 'Claire');
    expect(d.parametres?.frequenceParDefaut, 60);
    expect(d.bateaux.map((b) => b.nom), ['Alizé', 'Petit Pingouin']);
    expect(d.horsConnexion, isFalse);
  });

  test('hors connexion : la session reste ouverte et l\'application s\'ouvre sur ses données locales (RG-COM-06)', () async {
    final d = serveur.depot(session, base);
    await d.ouvrir();
    await d.connexion('marin@example.org', 'secret123');
    d.dispose();

    serveur.coupe = true;
    final d2 = serveur.depot(await StockageSession.ouvrir(), base);
    await d2.ouvrir();
    expect(d2.etatSession, EtatSession.connecte);
    await d2.actualiser();
    expect(d2.horsConnexion, isTrue);
    expect(d2.navigationEnCours?.id, 'n1');
    expect(d2.quota?.disponibleMinutes, 1140);
    expect(d2.quota?.recuLe, isNotNull); // dernier état reçu, avec son heure
    expect(d2.contacts.single.nom, 'Claire');
    expect(d2.navigationsRecuesLe, isNotNull);

    // Retour de la connexion.
    serveur.coupe = false;
    await d2.actualiser();
    expect(d2.horsConnexion, isFalse);
  });

  test('connexion impossible sans Internet', () async {
    serveur.coupe = true;
    final d = serveur.depot(session, base);
    await d.ouvrir();
    await expectLater(
      d.connexion('marin@example.org', 'secret123'),
      throwsA(isA<HorsConnexion>()),
    );
    expect(d.etatSession, EtatSession.deconnecte);
  });

  test('mot de passe faux : erreur du serveur rendue telle quelle', () async {
    final d = serveur.depot(session, base);
    await d.ouvrir();
    await expectLater(
      d.connexion('marin@example.org', 'faux'),
      throwsA(
        isA<ErreurApi>().having(
          (e) => e.message,
          'message',
          'Adresse e-mail ou mot de passe incorrect.',
        ),
      ),
    );
  });

  test('avertissement changé : 428 puis connexion avec la version acceptée (RG-CPT-07)', () async {
    serveur.avertissementChange = true;
    serveur.avertissement = '2027-01-01';
    final d = serveur.depot(session, base);
    await d.ouvrir();
    await expectLater(
      d.connexion('marin@example.org', 'secret123'),
      throwsA(isA<ErreurApi>().having((e) => e.statut, 'statut', 428)),
    );
    final v = await d.versionAvertissement();
    await d.connexion(
      'marin@example.org',
      'secret123',
      avertissementVersion: v,
    );
    expect(d.etatSession, EtatSession.connecte);
  });

  test('création du compte avec la version de l\'avertissement acceptée (RG-CPT-06)', () async {
    final d = serveur.depot(session, base);
    await d.ouvrir();
    await d.creerCompte(
      nom: 'Marin',
      email: 'marin@example.org',
      motDePasse: 'secret123',
      avertissementVersion: await d.versionAvertissement(),
      langue: 'fr',
    );
    expect(serveur.corps['POST /v1/comptes'], {
      'nom': 'Marin',
      'email': 'marin@example.org',
      'motDePasse': 'secret123',
      'langue': 'fr',
      'avertissementVersion': '2026-11-24',
    });
    expect(d.etatSession, EtatSession.connecte);
    expect(d.profil?.emailVerifie, isFalse);
  });

  test('« Mot de passe oublié ? » : demande du lien (RG-CPT-10)', () async {
    final d = serveur.depot(session, base);
    await d.motDePasseOublie(' marin@example.org ');
    expect(serveur.corps['POST /v1/compte/mot-de-passe/oubli'], {
      'email': 'marin@example.org',
    });
  });

  test('session fermée par le serveur : retour à la connexion, file gardée (RG-CPT-08)', () async {
    final d = serveur.depot(session, base);
    await d.ouvrir();
    await d.connexion('marin@example.org', 'secret123');
    serveur.coupe = true;
    await d.envois.evenement('n1', {'type': 'note', 'texte': 'en attente'});
    serveur.coupe = false;
    serveur.sessionsFermees = true;
    await d.actualiser();
    expect(d.etatSession, EtatSession.deconnecte);
    expect(d.sessionExpiree, isTrue);
    expect(await d.envois.enAttente(), 1);
    expect(d.navigationEnCours?.id, 'n1'); // données locales gardées

    // Reconnexion du même compte : la file part.
    serveur.sessionsFermees = false;
    await d.connexion('marin@example.org', 'secret123');
    await d.file.attendrePasse();
    expect(await d.envois.enAttente(), 0);
  });

  test('déconnexion : jetons oubliés, file d\'attente gardée ; autre compte : copies locales effacées (Q-82)', () async {
    final d = serveur.depot(session, base);
    await d.ouvrir();
    await d.connexion('marin@example.org', 'secret123');
    serveur.coupe = true;
    await d.envois.evenement('n1', {'type': 'note'});
    await d.file.attendrePasse();
    await d.deconnecter();
    expect(session.ouverte, isFalse);
    expect(d.etatSession, EtatSession.deconnecte);
    expect(await d.envois.enAttente(), 1);

    Uri dernierContacts() =>
        serveur.adresses.lastWhere((u) => u.path.endsWith('/v1/contacts'));
    serveur.coupe = false;
    await d.connexion('marin@example.org', 'secret123');
    expect(
      dernierContacts().queryParameters['depuis'],
      'k1',
    ); // même compte : seulement les changements
    await d.file.attendrePasse();
    expect(await d.envois.enAttente(), 0);

    await d.deconnecter();
    await d.connexion('autre@example.org', 'secret123');
    expect(
      dernierContacts().queryParameters.containsKey('depuis'),
      isFalse,
    ); // autre compte : tout relu
  });
}
