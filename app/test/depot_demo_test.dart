import 'package:flutter_test/flutter_test.dart';
import 'package:nautilink/config.dart';
import 'package:nautilink/data.dart';
import 'package:nautilink/depot/depot_demo.dart';

void main() {
  test('construction par défaut : mode démonstration (D-127)', () {
    expect(kMode, ModeApplication.demo);
    expect(kApiUrl, 'https://vdl.moulard.org/nautilink/api');
  });

  test('dépôt de démonstration : vue des données d\'exemple de lib/data.dart', () {
    final s = AppState();
    final d = DepotDemo(s);
    expect(d.demonstration, isTrue);
    expect(d.navigations.length, s.voyages.length);
    // En cours d'abord : la navigation suivie de Paul.
    expect(d.navigations.first.enCours, isTrue);
    expect(d.navigations.first.commeSuiveur, isTrue);
    expect(d.navigationEnCours, isNull);
    expect(d.quota.disponibleMinutes, AppState.quotaMinutes - s.usedMinutes);
    expect(d.contacts.map((c) => c.nom), contains('Claire (sœur)'));
    expect(d.parametres.frequenceParDefaut, s.defaultFrequency);
    expect(d.parametres.smsParType['debut'], isTrue);

    var notifie = 0;
    d.addListener(() => notifie++);
    s.startVoyage(boat: s.boats.first, frequency: 30);
    expect(notifie, greaterThan(0));
    expect(d.navigationEnCours?.nom, startsWith('Alizé — '));
    s.endVoyage();
    expect(d.navigationEnCours, isNull);
  });

  test('envois simulés : identifiants UUID v4 et numéros d\'ordre par navigation', () async {
    final e = EnvoisDemo();
    final uuid = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    expect(e.nouvelId(), matches(uuid));
    final a = await e.evenement('n1', {'type': 'note'});
    final b = await e.evenement('n1', {'type': 'note'});
    final c = await e.evenement('n2', {'type': 'note'});
    expect([a['numeroOrdre'], b['numeroOrdre'], c['numeroOrdre']], [1, 2, 1]);
    expect(e.envoyes.length, 3);
    expect(await e.enAttente(), 0);
  });
}
