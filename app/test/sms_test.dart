import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:nautilink/data.dart';
import 'package:nautilink/depot/depot.dart';
import 'package:nautilink/l10n/app_localizations.dart';
import 'package:nautilink/reel/conduite.dart';
import 'package:nautilink/reel/sms.dart';
import 'package:nautilink/reel/sms_navigation.dart';

import 'faux_serveur.dart';

/// Circuit SMS de l'application Android (RG-SMS-01 à RG-SMS-09, RG-SOS-05 à
/// RG-SOS-08, RG-SOS-12, RG-SOS-16).
void main() {
  var n = 0;
  String id() => 'id${n++}';

  NavigationLocale navigation({ParametresGeneraux? parametres}) =>
      NavigationLocale(
        id: 'nav1',
        nom: 'Alizé — Houat',
        bateauId: 'b1',
        bateauNom: 'Alizé',
        debut: DateTime(2026, 11, 26, 9),
        frequenceMinutes: 60,
        personnesABord: 2,
        destination: 'Houat',
        personnesAlertees: const ['c1', 'c2', 'c3'],
        parametres: parametres,
      );

  const contacts = [
    ContactNl(id: 'c1', nom: 'Claire', telephone: '+33611111111'),
    // Refuse les SMS dans son profil (RG-SMS-01).
    ContactNl(
      id: 'c2',
      nom: 'Paul',
      telephone: '+33622222222',
      recevoirSms: false,
    ),
    // Décoché au démarrage (RG-NAV-25).
    ContactNl(id: 'c4', nom: 'Léa', telephone: '+33644444444'),
  ];

  late FauxSms canal;
  late EnvoisSms envois;
  late SmsNavigation sms;
  late List<(String, List<Map<String, Object?>>)> statuts;

  void monter() {
    canal = FauxSms();
    envois = EnvoisSms(canal: canal, nouvelId: id);
    statuts = [];
    sms = SmsNavigation(
      canal: canal,
      envois: envois,
      profil: () => const ProfilNl(
        email: 'marin@example.org',
        nom: 'Marin',
        emailVerifie: true,
        telephone: '+33600000000',
        langue: 'fr',
      ),
      contacts: () => contacts,
      bateaux: () => const [],
      langue: () => 'fr',
      pageNavigation: (id) => 'https://essai.example/navigations/$id',
      statutsSos: (a, s) async => statuts.add((a, s)),
    );
  }

  setUp(monter);

  test('amis de la navigation : numéro, « Recevoir les SMS », cochés (RG-SMS-01, RG-NAV-25, D-176)', () {
    expect(sms.amisSms(navigation()).map((d) => d.contactId), ['c1']);
    expect(sms.amisSos(navigation()).map((d) => d.contactId), ['c1', 'c2']);
    // Hors navigation : tous les amis avec un numéro.
    expect(sms.amisSos(null).length, 3);
    // D-176 : les anciens rôles ne comptent plus, chaque contact est un ami.
    final ancien = SmsNavigation(
      canal: canal,
      envois: envois,
      profil: () => null,
      contacts: () => const [
        ContactNl(
          id: 'c1',
          nom: 'Jo',
          telephone: '+33633333333',
        ),
      ],
      bateaux: () => const [],
      langue: () => 'fr',
      pageNavigation: (id) => 'https://essai.example/navigations/$id',
      statutsSos: (a, s) async {},
    );
    expect(ancien.amisSms(navigation()).length, 1);
    expect(ancien.amisSos(navigation()).length, 1);
  });

  test('heures envoyées : heure locale puis UTC (RG-PRM-07, D-146)', () async {
    await initializeDateFormatting('fr');
    await initializeDateFormatting('en');
    final fr = lookupAppLocalizations(const Locale('fr'));
    final en = lookupAppLocalizations(const Locale('en'));
    const hiver = Duration(hours: 1);
    final t = DateTime.utc(2026, 11, 26, 13, 32);
    expect(heureEnvoyee(fr, t, decalage: hiver), '14:32 (13:32 UTC)');
    expect(heureEnvoyee(en, t, decalage: hiver), '14:32 (13:32 UTC)');
    expect(
      heureEnvoyee(fr, t, decalage: hiver, avecDate: true),
      '26 nov. 2026, 14:32 (13:32 UTC)',
    );
    // Jour local différent du jour UTC : date UTC dans la parenthèse.
    expect(
      heureEnvoyee(
        fr,
        DateTime.utc(2026, 11, 26, 23, 30),
        decalage: hiver,
        avecDate: true,
      ),
      '27 nov. 2026, 00:30 (26 nov. 2026, 23:30 UTC)',
    );
    expect(
      heureEnvoyee(
        fr,
        DateTime.utc(2026, 7, 1, 2, 5),
        decalage: const Duration(hours: -4),
      ),
      '22:05 (02:05 UTC)',
    );
    // Sans décalage donné : celui du téléphone.
    final ici = DateTime(2026, 11, 26, 9, 15);
    expect(heureEnvoyee(fr, ici), '09:15 (${fmtTime(ici.toUtc())} UTC)');
    expect(
      sms.texte(navigation(), 'position_manuelle', heure: ici),
      startsWith(
        'NautiLink Alizé — position à 09:15 (${fmtTime(ici.toUtc())} UTC).',
      ),
    );
  });

  test('texte : position ou « GPS NON DISPONIBLE », liens (RG-SMS-04, RG-SMS-06, RG-SMS-09)', () {
    final p = PositionGps(
      latitude: 47.38,
      longitude: -2.95,
      heureAcquisition: DateTime(2026, 11, 26, 10),
    );
    final debut = sms.texte(navigation(), 'debut', position: p);
    expect(debut, contains('début de navigation'));
    expect(debut, contains('Destination : Houat.'));
    expect(debut, contains('https://maps.google.com/?q=47.38000,-2.95000'));
    expect(
      debut,
      contains('Suivre la navigation : https://essai.example/navigations/nav1'),
    );
    expect(
      sms.texte(navigation(), 'position_manuelle'),
      contains('GPS NON DISPONIBLE'),
    );
    expect(
      sms.texte(navigation(), 'note_vocale', evenementId: 'e9'),
      contains(
        'Note vocale : https://essai.example/navigations/nav1#evenement-e9',
      ),
    );
  });

  test('SMS prérempli : amis et copie au navigateur ; type désactivé (RG-SMS-02, RG-SMS-03, RG-SMS-08)', () async {
    final (i, nombre) = await sms.ordinaire(
      navigation(),
      'note',
      note: 'Cap au 270',
    );
    expect(i, IssueSms.prerempli);
    expect(nombre, 2);
    expect(canal.preremplis.single.$1, ['+33611111111', '+33600000000']);
    final off = navigation(
      parametres: const ParametresGeneraux(
        smsActifs: true,
        smsParType: {'notes': false},
        photoEnMms: false,
        frequenceParDefaut: 60,
      ),
    );
    // Type désactivé pour les amis : le navigateur reçoit quand même le
    // SMS, pour la trace (RG-SMS-08, D-159).
    final r = await sms.ordinaire(off, 'note', note: 'x');
    expect(r.$1, IssueSms.prerempli);
    expect(canal.preremplis.last.$1, ['+33600000000']);
  });

  test('trace : sans ami, SMS au navigateur seul, positions automatiques comprises (D-159)', () async {
    canal.autorisee = true;
    final sansAmi = NavigationLocale(
      id: 'nav2',
      nom: 'Solo',
      bateauId: 'b1',
      bateauNom: 'Alizé',
      debut: DateTime(2026, 11, 26, 9),
      frequenceMinutes: 60,
      personnesABord: 1,
      parametres: const ParametresGeneraux(
        smsActifs: false,
        smsParType: {},
        photoEnMms: false,
        frequenceParDefaut: 60,
      ),
    );
    final e = EvenementLocal(
      id: 'e1',
      type: 'position_automatique',
      heure: DateTime(2026, 11, 26, 10),
    );
    expect(await sms.positionAutomatique(sansAmi, e), IssueSms.automatique);
    expect((await sms.ordinaire(sansAmi, 'fin')).$1, IssueSms.automatique);
    expect(canal.envoyes.map((s) => s.$2), ['+33600000000', '+33600000000']);
  });

  test('photo : MMS prévu, sinon SMS avec le lien (RG-SMS-05, D-49)', () async {
    final mms = navigation(
      parametres: const ParametresGeneraux(
        smsActifs: true,
        smsParType: {},
        photoEnMms: true,
        frequenceParDefaut: 60,
      ),
    );
    var r = await sms.ordinaire(
      mms,
      'photo',
      evenementId: 'e1',
      photo: '/tmp/p.jpg',
    );
    expect(r.$1, IssueSms.mms);
    expect(canal.preremplis.last.$3, '/tmp/p.jpg');
    canal.ouvre = false;
    r = await sms.ordinaire(
      mms,
      'photo',
      evenementId: 'e1',
      photo: '/tmp/p.jpg',
    );
    expect(r.$1, IssueSms.echec);
  });

  test('position automatique : sans permission, rien (D-91) ; avec, envoi automatique (RG-SMS-03)', () async {
    final e = EvenementLocal(
      id: 'e1',
      type: 'position_automatique',
      heure: DateTime(2026, 11, 26, 10),
    );
    expect(
      await sms.positionAutomatique(navigation(), e),
      IssueSms.sansPermission,
    );
    expect(canal.envoyes, isEmpty);
    canal.autorisee = true;
    expect(
      await sms.positionAutomatique(navigation(), e),
      IssueSms.automatique,
    );
    expect(canal.envoyes.map((s) => s.$2), ['+33611111111', '+33600000000']);
    expect(canal.envoyes.first.$3, contains('GPS NON DISPONIBLE'));
  });

  test('SMS de position automatique en échec : 3 essais, puis « Réessayer » (RG-SMS-07)', () {
    fakeAsync((f) {
      // Minuteries des nouveaux essais dans l'horloge simulée.
      monter();
      canal
        ..autorisee = true
        ..reponse = EtatSms.echec;
      envois.envoyer(
        'position:e1',
        [const DestinataireSms('+33611111111')],
        ['x'],
      );
      f.flushMicrotasks();
      expect(canal.envoyes.length, 1);
      f.elapse(const Duration(minutes: 1));
      f.flushMicrotasks();
      f.elapse(const Duration(minutes: 1));
      f.flushMicrotasks();
      expect(canal.envoyes.length, 3);
      expect(envois.echecsPosition.length, 1);
      f.elapse(const Duration(minutes: 5));
      expect(canal.envoyes.length, 3); // plus d'essai automatique
      canal.reponse = EtatSms.acceptePourEnvoi;
      envois.reessayer(envois.echecsPosition.single);
      f.flushMicrotasks();
      expect(canal.envoyes.length, 4);
      expect(envois.echecsPosition, isEmpty);
    });
  });

  test('SMS SOS : deux SMS, copie, statuts au serveur, nouvel essai chaque minute jusqu\'à l\'arrêt (RG-SOS-07, RG-SOS-08, RG-SOS-12, RG-SMS-07)', () {
    fakeAsync((f) {
      // Minuteries des nouveaux essais dans l'horloge simulée.
      monter();
      canal
        ..autorisee = true
        ..reponse = EtatSms.echec;
      sms.sos(
        alerteId: 'a1',
        navigation: navigation(),
        premier: 'SOS 1',
        second: 'SOS 2',
      );
      f.flushMicrotasks();
      // 2 amis cochés + copie au navigateur, deux SMS chacun.
      expect(canal.envoyes.length, 6);
      expect(envois.sosRetentes('sos:a1'), isTrue);
      final dernier = statuts.last;
      expect(dernier.$1, 'a1');
      expect(dernier.$2.where((s) => s['rang'] == 2).length, 3);
      expect(
        dernier.$2.firstWhere((s) => s['contactId'] == null)['telephone'],
        '+33600000000',
      );
      expect(dernier.$2.every((s) => s['statut'] == 'echec'), isTrue);
      f.elapse(const Duration(minutes: 1));
      f.flushMicrotasks();
      expect(canal.envoyes.length, 12);
      f.elapse(const Duration(minutes: 1));
      f.flushMicrotasks();
      expect(canal.envoyes.length, 18); // jusqu'à la réussite ou l'arrêt
      envois.arreterSos('sos:a1');
      f.elapse(const Duration(minutes: 3));
      f.flushMicrotasks();
      expect(canal.envoyes.length, 18);
    });
  });

  test('accusé de réception : « livraison confirmée » ne revient pas en arrière (RG-SOS-12)', () async {
    canal.autorisee = true;
    await sms.sos(
      alerteId: 'a2',
      navigation: null,
      premier: 'SOS',
      second: 'suite',
    );
    await Future<void>.delayed(Duration.zero);
    final premier = envois.groupe('sos:a2').first;
    canal.etat(premier.id, EtatSms.livraisonConfirmee);
    await Future<void>.delayed(Duration.zero);
    canal.etat(premier.id, EtatSms.acceptePourEnvoi);
    await Future<void>.delayed(Duration.zero);
    expect(envois.groupe('sos:a2').first.etat, EtatSms.livraisonConfirmee);
    expect(statuts.last.$2.first['statut'], 'livraison_confirmee');
  });

  test('sans permission : SMS SOS prérempli, les deux textes (RG-AND-04, RG-SOS-23)', () async {
    final (i, nombre) = await sms.sos(
      alerteId: 'a3',
      navigation: navigation(),
      premier: 'SOS 1',
      second: 'SOS 2',
    );
    expect(i, IssueSms.prerempli);
    expect(nombre, 3);
    expect(canal.preremplis.single.$2, 'SOS 1\nSOS 2');
  });

  test('second SMS SOS : fiche du bateau (RG-SOS-08)', () {
    const b = BateauNl(
      id: 'b1',
      nom: 'Alizé',
      type: 'voilier',
      portAttache: 'La Trinité-sur-Mer',
      moteur: 'Volvo 20 ch',
      autonomie: '30 h',
      capaciteCarburantLitres: 40,
      vitesseNoeuds: 6.5,
      tirantEauMetres: 1.8,
    );
    final t = sms.secondSos(b, 'Alizé');
    expect(t, contains("Port d'attache : La Trinité-sur-Mer."));
    expect(t, contains('Carburant : 40 L.'));
    expect(t, contains('Vitesse : 6.5 nd.'));
    expect(t, contains("Tirant d'eau : 1.8 m."));
  });

  test('avec la permission : SMS ordinaire envoyé automatiquement, avec la copie (D-158, RG-SMS-03)', () async {
    canal.autorisee = true;
    final (i, nombre) = await sms.ordinaire(
      navigation(),
      'note',
      note: 'Cap au 270',
      evenementId: 'e5',
    );
    expect(i, IssueSms.automatique);
    expect(nombre, 2);
    expect(canal.preremplis, isEmpty);
    expect(canal.envoyes.map((s) => s.$2), ['+33611111111', '+33600000000']);
    expect(canal.envoyes.first.$3, contains('Note : Cap au 270'));
  });

  test('photo avec la permission : SMS automatique avec le lien, MMS prérempli en plus si prévu (RG-SMS-05, D-158)', () async {
    canal.autorisee = true;
    final mms = navigation(
      parametres: const ParametresGeneraux(
        smsActifs: true,
        smsParType: {},
        photoEnMms: true,
        frequenceParDefaut: 60,
      ),
    );
    final r = await sms.ordinaire(
      mms,
      'photo',
      evenementId: 'e7',
      photo: '/tmp/p.jpg',
    );
    expect(r.$1, IssueSms.automatiqueEtMms);
    expect(
      canal.envoyes.first.$3,
      contains('Photo : https://essai.example/navigations/nav1#evenement-e7'),
    );
    expect(canal.preremplis.single.$3, '/tmp/p.jpg');
  });

  test('invitation par SMS : automatique avec la permission, sinon préremplie (RG-PAR-11, D-158)', () async {
    var r = await sms.invitation(
      'i1',
      '+33655555555',
      'Marin vous invite : https://l',
      contactId: 'c9',
    );
    expect(r.$1, IssueSms.prerempli);
    expect(canal.preremplis.single.$1, ['+33655555555', '+33600000000']);
    canal.autorisee = true;
    r = await sms.invitation(
      'i2',
      '+33655555555',
      'Marin vous invite : https://l',
      contactId: 'c9',
    );
    expect(r.$1, IssueSms.automatique);
    expect(canal.envoyes.map((s) => s.$2), ['+33655555555', '+33600000000']);
  });

  test('SMS ordinaire automatique en échec : 3 essais puis « Réessayer » (RG-SMS-07, D-158)', () {
    fakeAsync((f) {
      monter();
      canal
        ..autorisee = true
        ..reponse = EtatSms.echec;
      sms.ordinaire(navigation(), 'fin');
      f.flushMicrotasks();
      f.elapse(const Duration(minutes: 3));
      f.flushMicrotasks();
      // 2 destinataires, 3 essais chacun.
      expect(canal.envoyes.length, 6);
      expect(envois.echecsPosition.length, 2);
    });
  });
}
