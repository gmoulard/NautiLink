import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nautilink/main.dart';
import 'package:nautilink/reel/api.dart';
import 'package:nautilink/reel/base_locale.dart';
import 'package:nautilink/reel/depot_reel.dart';
import 'package:nautilink/reel/file_attente.dart';
import 'package:nautilink/reel/stockage_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'faux_serveur.dart';

/// Faux serveur avec les contacts, les invitations, les accès, les
/// paramètres et l'historique des alertes SOS tenus en mémoire (TODO-5.7).
class FauxServeurCompte extends FauxServeurNautiLink {
  final contacts = <String, Map<String, Object?>>{
    'c1': {
      'id': 'c1',
      'nom': 'Claire',
      'telephone': '+33612345678',
      'email': 'claire@example.org',
      'suiveur': true,
      'contactSos': true,
      'perimetre': 'navigateur',
      'etatInvitation': 'acceptee',
      'utilisateurId': 'u2',
    },
  };
  final invitations = <Map<String, Object?>>[];
  final acces = <Map<String, Object?>>[
    {
      'id': 'a1',
      'suiveur': {'id': 'u2', 'nom': 'Claire'},
      'perimetre': 'navigateur',
      'navigationId': null,
    },
  ];
  final parametres = <String, Object?>{
    'smsActifs': true,
    'smsParType': <String, Object?>{'debut': true, 'notes': true},
    'photoEnMms': false,
    'frequenceParDefaut': 60,
  };

  /// Code d'erreur 5xx rendu aux modifications (serveur en panne).
  int? panne;

  http.Response? _compte(http.Request r, String chemin, Object? c) {
    if (!(r.headers['Authorization'] ?? '').startsWith('Bearer A')) {
      return null;
    }
    final m = c is Map ? c.cast<String, Object?>() : <String, Object?>{};
    final ecriture = r.method != 'GET';
    if (ecriture && panne != null && chemin.startsWith('/v1/contacts')) {
      return erreur(panne!, 'erreur_interne', 'Panne.');
    }
    if (chemin == '/v1/contacts' && r.method == 'GET') {
      return reponse(200, {
        'contacts': contacts.values.toList(),
        'supprimes': [],
        'curseur': 'k${contacts.length}',
      });
    }
    if (chemin == '/v1/contacts' && r.method == 'POST') {
      final id = m['id'] as String;
      if (contacts.containsKey(id)) return reponse(200, contacts[id]);
      if (m['suiveur'] != false && !emailVerifie) {
        return erreur(
          403,
          'email_non_verifie',
          'Confirmez d\'abord votre adresse e-mail.',
        );
      }
      if (m['suiveur'] != false && m['perimetre'] == null) {
        return erreur(422, 'invalide', 'Choisissez ce que le suiveur verra.');
      }
      final k = {
        ...m,
        'contactSos': m['contactSos'] != false && m['telephone'] != null,
        'suiveur': m['suiveur'] != false,
        'etatInvitation': m['suiveur'] != false ? 'envoyee' : 'aucune',
      };
      contacts[id] = k;
      return reponse(201, k);
    }
    if (chemin.startsWith('/v1/contacts/')) {
      final id = chemin.split('/').last;
      final k = contacts[id];
      if (k == null) return erreur(404, 'introuvable', 'Introuvable.');
      if (r.method == 'DELETE') {
        contacts.remove(id);
        return reponse(204);
      }
      if (m['contactSos'] == true &&
          (m.containsKey('telephone') ? m['telephone'] : k['telephone']) ==
              null) {
        return erreur(
          422,
          'contact_sos_sans_telephone',
          'Un contact SOS doit avoir un numéro de téléphone.',
        );
      }
      k.addAll(m);
      if (m['suiveur'] == false) k['etatInvitation'] = 'aucune';
      return reponse(200, k);
    }
    if (chemin == '/v1/invitations' && r.method == 'GET') {
      return reponse(200, invitations);
    }
    if (chemin == '/v1/invitations' && r.method == 'POST') {
      final k = contacts[m['contactId']]!;
      for (final i in invitations) {
        if (i['contactId'] == m['contactId'] && i['etat'] == 'envoyee') {
          i['etat'] = 'annulee';
        }
      }
      final i = {
        ...m,
        'id': 'i${invitations.length + 1}',
        'telephone': k['telephone'],
        'email': k['email'],
        'lien':
            'https://essai.example/nautilink/invitation?jeton=J${invitations.length + 1}',
        'etat': 'envoyee',
      };
      invitations.add(i);
      k['suiveur'] = true;
      k['etatInvitation'] = 'envoyee';
      k['perimetre'] = m['perimetre'];
      return reponse(201, i);
    }
    if (chemin.startsWith('/v1/invitations/') && r.method == 'DELETE') {
      final i = invitations.firstWhere(
        (i) => i['id'] == chemin.split('/').last,
      );
      i['etat'] = 'annulee';
      contacts[i['contactId']]!['etatInvitation'] = 'annulee';
      return reponse(204);
    }
    if (chemin == '/v1/acces') return reponse(200, acces);
    if (chemin.startsWith('/v1/acces/')) {
      final id = chemin.split('/').last;
      final a = acces.firstWhere((a) => a['id'] == id);
      if (r.method == 'DELETE') {
        acces.remove(a);
        for (final k in contacts.values) {
          if (k['utilisateurId'] == (a['suiveur'] as Map)['id']) {
            k['suiveur'] = false;
            k['etatInvitation'] = 'aucune';
          }
        }
        return reponse(204);
      }
      a.addAll(m);
      for (final k in contacts.values) {
        if (k['utilisateurId'] == (a['suiveur'] as Map)['id']) {
          k['perimetre'] = m['perimetre'];
        }
      }
      return reponse(200, a);
    }
    if (chemin == '/v1/parametres') {
      if (r.method == 'PATCH') {
        final t = m['smsParType'];
        final types = parametres['smsParType'] as Map<String, Object?>;
        parametres.addAll({...m}..remove('smsParType'));
        if (t is Map) types.addAll(t.cast<String, Object?>());
      }
      return reponse(200, parametres);
    }
    return null;
  }

  @override
  MockClient get client {
    final parent = super.client;
    return MockClient((r) async {
      if (coupe) throw http.ClientException('pas de réseau');
      final chemin = r.url.path.replaceFirst(RegExp(r'^.*/api'), '');
      final c = r.body.isEmpty ? null : jsonDecode(r.body);
      final rep = _compte(r, chemin, c);
      if (rep != null) {
        appels.add('${r.method} $chemin');
        corps['${r.method} $chemin'] = c;
        return rep;
      }
      final copie = http.Request(r.method, r.url)
        ..headers.addAll(r.headers)
        ..bodyBytes = r.bodyBytes;
      return http.Response.fromStream(await parent.send(copie));
    });
  }

  DepotReel depotSur(
    StockageSession session,
    BaseLocale base, {
    String plateforme = 'android',
  }) {
    final api = ClientApi(
      base: 'https://essai.example/nautilink/api',
      session: session,
      client: client,
    );
    return DepotReel(
      api: api,
      session: session,
      base: base,
      plateforme: plateforme,
      file: FileAttente(
        base: base,
        api: api,
        appareilId: session.appareilId,
        planifier: (_, _) {},
      ),
    );
  }
}

void setPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).hitTestable();
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(text).hitTestable().first);
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  late FauxServeurCompte serveur;
  late BaseLocale base;
  late StockageSession session;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    session = await StockageSession.ouvrir();
    base = BaseMemoire();
    serveur = FauxServeurCompte();
  });

  group('dépôt', () {
    test('contact ajouté hors connexion : visible tout de suite (SOS compris), envoyé au retour sans doublon (RG-COM-06, RG-CTC-03)', () async {
      final d = serveur.depotSur(session, base);
      await d.ouvrir();
      await d.connexion('marin@example.org', 'secret123');
      expect(d.contacts.single.nom, 'Claire');

      serveur.coupe = true;
      final id = await d.compte.ajouterContact(
        nom: 'Marc',
        telephone: '+33698765432',
        suiveur: false,
      );
      await d.modifierContact('c1', {'contactSos': false});
      final marc = d.contacts.firstWhere((c) => c.id == id);
      expect(marc.contactSos, isTrue);
      expect(marc.enAttente, isTrue);
      expect(d.contacts.firstWhere((c) => c.id == 'c1').contactSos, isFalse);
      expect(d.compte.enAttente.length, 2);

      // Après un redémarrage de l'application, toujours là.
      final d2 = serveur.depotSur(session, base);
      await d2.ouvrir();
      expect(d2.contacts.map((c) => c.nom), ['Claire', 'Marc']);
      expect(d2.contacts.where((c) => c.contactSos).map((c) => c.nom), [
        'Marc',
      ]);

      serveur.coupe = false;
      await d2.actualiser();
      expect(d2.compte.enAttente, isEmpty);
      expect(serveur.corps['POST /v1/contacts'], containsPair('id', id));
      expect(serveur.corps['PATCH /v1/contacts/c1'], {'contactSos': false});
      expect(serveur.contacts[id]!['nom'], 'Marc');
      expect(d2.contacts.every((c) => !c.enAttente), isTrue);

      // Renvoi du même ajout : pas de doublon (200).
      await d2.compte.ajouterContact(
        nom: 'X',
        email: 'x@example.org',
        suiveur: false,
      );
      expect(serveur.contacts.length, 3);
      d.dispose();
      d2.dispose();
    });

    test('erreur 5xx : modification gardée ; refus 4xx : retirée avec son message (Q-86)', () async {
      final d = serveur.depotSur(session, base);
      await d.ouvrir();
      await d.connexion('marin@example.org', 'secret123');
      serveur.panne = 503;
      await d.modifierContact('c1', {'nom': 'Claire M.'});
      expect(d.compte.enAttente.length, 1);
      expect(d.contacts.single.nom, 'Claire M.');
      serveur.panne = null;
      await d.compte.envoyer();
      expect(serveur.contacts['c1']!['nom'], 'Claire M.');
      expect(d.compte.enAttente, isEmpty);

      await d.modifierContact('c1', {'telephone': null, 'contactSos': true});
      expect(d.compte.enAttente, isEmpty);
      expect(
        d.compte.dernierRefus,
        'Un contact SOS doit avoir un numéro de téléphone.',
      );
      d.dispose();
    });

    test('adresse non confirmée : le suiveur n\'est pas invité, le contact SOS est gardé (RG-CPT-09)', () async {
      final d = serveur.depotSur(session, base);
      await d.ouvrir();
      await d.connexion('marin@example.org', 'secret123');
      serveur.emailVerifie = false;
      final id = await d.compte.ajouterContact(
        nom: 'Marc',
        telephone: '06 98 76 54 32',
        perimetre: 'navigateur',
      );
      expect(serveur.contacts[id]!['suiveur'], false);
      expect(serveur.contacts[id]!['contactSos'], true);
      expect(d.compte.dernierRefus, 'Confirmez d\'abord votre adresse e-mail.');
      d.dispose();
    });

    test('paramètres : seuls les champs changés partent, hors connexion gardés (RG-PRM-01, RG-COM-04)', () async {
      final d = serveur.depotSur(session, base);
      await d.ouvrir();
      await d.connexion('marin@example.org', 'secret123');
      await d.modifierParametres({'frequenceParDefaut': 120});
      expect(serveur.corps['PATCH /v1/parametres'], {
        'frequenceParDefaut': 120,
      });
      expect(d.parametres?.frequenceParDefaut, 120);

      serveur.coupe = true;
      await d.modifierParametres({
        'smsParType': {'notes': false},
      });
      expect(d.parametres?.smsParType['notes'], isFalse);
      expect(d.parametres?.smsParType['debut'], isTrue);
      // Modifié sur le Web entre-temps : la fréquence du Web reste.
      serveur.parametres['frequenceParDefaut'] = 30;
      serveur.coupe = false;
      await d.actualiser();
      expect(serveur.corps['PATCH /v1/parametres'], {
        'smsParType': {'notes': false},
      });
      expect(d.parametres?.frequenceParDefaut, 30);
      expect(d.parametres?.smsParType['notes'], isFalse);
      d.dispose();
    });

    test('invitation par téléphone, annulation, périmètre, retrait (RG-PAR-02 à RG-PAR-06)', () async {
      final d = serveur.depotSur(session, base);
      await d.ouvrir();
      await d.connexion('marin@example.org', 'secret123');
      final id = await d.compte.ajouterContact(
        nom: 'Marc',
        telephone: '+33698765432',
        suiveur: false,
      );
      final i = await d.compte.inviter(
        contactId: id,
        canal: 'telephone',
        perimetre: 'navigation',
        navigationId: 'n0',
      );
      expect(i.lien, contains('/invitation?jeton='));
      expect(serveur.corps['POST /v1/invitations'], {
        'contactId': id,
        'canal': 'telephone',
        'perimetre': 'navigation',
        'navigationId': 'n0',
      });
      expect(
        d.contacts.firstWhere((c) => c.id == id).etatInvitation,
        'envoyee',
      );
      await d.compte.annulerInvitation(i.id);
      expect(
        d.contacts.firstWhere((c) => c.id == id).etatInvitation,
        'annulee',
      );

      await d.compte.changerPerimetre('a1', 'navigation', navigationId: 'n1');
      expect(serveur.corps['PATCH /v1/acces/a1'], {
        'perimetre': 'navigation',
        'navigationId': 'n1',
      });
      await d.compte.retirerAcces('a1');
      expect(d.contacts.firstWhere((c) => c.id == 'c1').suiveur, isFalse);

      serveur.coupe = true;
      await expectLater(d.compte.invitations(), throwsA(isA<HorsConnexion>()));
      d.dispose();
    });
  });

  group('écrans', () {
    Future<DepotReel> ouvrir(
      WidgetTester tester, {
      String plateforme = 'android',
    }) async {
      setPhone(tester);
      final d = serveur.depotSur(session, base, plateforme: plateforme);
      await tester.runAsync(
        () => d.connexion('marin@example.org', 'secret123'),
      );
      await tester.pumpWidget(NautiLinkApp(depot: d));
      await tester.pumpAndSettle();
      return d;
    }

    Future<void> menu(WidgetTester tester, String entree) async {
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tapText(tester, entree);
    }

    testWidgets(
      'contacts : cases, ajout avec le périmètre, invitation par téléphone par SMS',
      (tester) async {
        await ouvrir(tester);
        await menu(tester, 'Contacts');
        expect(find.text('Claire'), findsOneWidget);
        expect(find.text('Suiveur : invitation acceptée'), findsOneWidget);

        // « Contact SOS » décoché : envoyé champ par champ.
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Contact SOS'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(serveur.corps['PATCH /v1/contacts/c1'], {'contactSos': false});

        await tapKey(tester, 'contact-add');
        await tester.enterText(find.byKey(const Key('contact-name')), 'Marc');
        await tester.enterText(
          find.byKey(const Key('contact-phone')),
          '+33698765432',
        );
        await tester.pumpAndSettle();
        await tapKey(tester, 'contact-save');
        // Suiveur coché par défaut : choix du périmètre (RG-CTC-04, RG-PAR-02).
        expect(find.text('Ce que le suiveur voit'), findsOneWidget);
        await tapKey(tester, 'scope-navigation');
        await tapKey(tester, 'scope-ok');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        final post = serveur.corps['POST /v1/contacts'] as Map;
        expect(post['perimetre'], 'navigation');
        expect(post['navigationId'], 'n1');
        expect(find.text('Marc'), findsOneWidget);

        // Fiche du contact : invitation par téléphone, lien et SMS (Android).
        await tapText(tester, 'Marc');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        await tapKey(tester, 'invite-phone');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('invitation-link')), findsOneWidget);
        expect(find.byKey(const Key('invitation-sms')), findsOneWidget);
        expect(find.byKey(const Key('invitation-cancel')), findsOneWidget);
      },
    );

    testWidgets(
      'contacts hors connexion : liste locale, message ; iPhone : lien sans SMS',
      (tester) async {
        final d = await ouvrir(tester, plateforme: 'ios');
        serveur.coupe = true;
        await tester.runAsync(d.actualiser);
        await tester.pumpAndSettle();
        await menu(tester, 'Contacts');
        expect(find.byKey(const Key('contacts-offline')), findsOneWidget);
        expect(find.text('Claire'), findsOneWidget);
        serveur.coupe = false;
        await tester.runAsync(d.actualiser);
        await tester.pumpAndSettle();
        await tapText(tester, 'Claire');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        // Accès accepté : périmètre et retrait, pas de nouvelle invitation.
        expect(find.byKey(const Key('invite-phone')), findsNothing);
        expect(find.byKey(const Key('scope-change')), findsOneWidget);
        expect(find.byKey(const Key('follower-remove')), findsOneWidget);
      },
    );

    testWidgets(
      'paramètres : interrupteur et types envoyés au serveur ; iPhone : SMS sans effet (RG-IOS-02)',
      (tester) async {
        await ouvrir(tester, plateforme: 'ios');
        await menu(tester, 'Paramètres');
        expect(find.byKey(const Key('settings-iphone')), findsOneWidget);
        expect(find.text('1 heure'), findsOneWidget);
        await tester.tap(find.widgetWithText(SwitchListTile, 'Notes écrites'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(serveur.corps['PATCH /v1/parametres'], {
          'smsParType': {'notes': false},
        });
        await tapKey(tester, 'photo-mms');
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle();
        expect(serveur.corps['PATCH /v1/parametres'], {'photoEnMms': true});
      },
    );
  });
}
