import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../depot/depot.dart';
import '../l10n/app_localizations.dart';
import '../reel/api.dart';
import '../reel/conduite.dart';
import '../reel/depot_reel.dart';
import '../reel/file_attente.dart';
import '../reel/gps.dart';
import '../reel/medias.dart';
import '../reel/sms.dart';
import '../reel/sms_navigation.dart';
import '../reel/telephone.dart';
import '../theme.dart';
import 'pied.dart';
import 'connexion.dart';
import 'dashboard.dart' show SeaMap;
import 'home.dart';
import 'navigation.dart';
import 'suivi_reel.dart';

/// Écrans de la navigation de la vraie application (D-127) : mêmes écrans que
/// la démonstration (`navigation.dart`), branchés sur le serveur par
/// [ConduiteNavigation] et la file d'attente.

DepotReel _depot(BuildContext context) => DepotScope.of(context) as DepotReel;

/// Résultat de chaque circuit d'un envoi, affiché dans la fenêtre « OK »
/// (RG-COM-03) : serveur, puis SMS (Android seulement, RG-IOS-02).
List<String> lignesResultat(
  AppLocalizations l,
  EtatEnvoi etat, {
  (IssueSms, int)? sms,
}) => [
  if (etat.refuse)
    l.voyageRefused(
      etat.refus!.message.isEmpty ? l.errorGeneric : etat.refus!.message,
    )
  else
    etat.recu ? l.serverSent : l.serverQueued,
  if (sms != null) ?ligneSms(l, sms.$1, nombre: sms.$2),
];

/// Explication puis demande de l'autorisation d'envoi de SMS, au démarrage
/// d'une navigation et non au premier SOS (RG-AND-02, étude des
/// autorisations § 4), quand un contact SOS a un numéro ou que des SMS de
/// positions automatiques sont prévus.
Future<void> demanderSms(
  BuildContext context,
  DepotReel depot, {
  required bool positionsAutomatiques,
}) async {
  final canal = depot.canalSms;
  if (!canal.disponible || await canal.autorise()) return;
  final utile =
      positionsAutomatiques ||
      depot.contacts.any(
        (c) => c.contactSos && (c.telephone?.isNotEmpty ?? false),
      );
  if (!utile || !context.mounted) return;
  final l = AppLocalizations.of(context);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.sms_outlined, color: NlColors.teal, size: 36),
      title: Text(l.smsPermissionTitle),
      content: Text(l.smsPermissionExplain),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok)),
      ],
    ),
  );
  await canal.demander();
}

/// Au premier démarrage d'une navigation sur Android : explication, réglages
/// de la marque du téléphone, puis demande d'exclusion de l'optimisation de
/// la batterie (RG-GPS-05) ; autorisation des notifications (Android 13 et
/// plus), sans laquelle la notification de la navigation n'apparaît pas.
Future<void> proposerBatterie(BuildContext context, DepotReel depot) async {
  final tel = depot.telephone;
  if (tel == null) return;
  try {
    if (!await tel.notificationsAutorisees()) await tel.demanderNotifications();
    if (depot.session.batterieProposee || await tel.batterieExclue()) return;
    final marque = marqueBatterie(await tel.fabricant());
    if (!context.mounted) return;
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.battery_alert, color: NlColors.teal, size: 36),
        title: Text(l.batteryTitle),
        content: Text(
          '${l.batteryExplain}\n\n${switch (marque) {
            'samsung' => l.batterySamsung,
            'xiaomi' => l.batteryXiaomi,
            _ => l.batteryOther,
          }}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.later),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.batteryOpen),
          ),
        ],
      ),
    );
    await depot.session.proposerBatterie();
    if (ok == true) await tel.demanderExclusionBatterie();
  } catch (e) {
    debugPrint('Batterie : $e');
  }
}

// ---------------------------------------------------------------- démarrage

/// « Démarrer navigation » de la vraie application : rappel avant la première
/// navigation sur ce téléphone (RG-NAV-23), puis écran de démarrage.
Future<void> openStartReel(BuildContext context) async {
  final depot = _depot(context);
  final l = AppLocalizations.of(context);
  if (!depot.session.rappelPremiereNavigationVu) {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l.firstVoyageTitle),
        content: Text(l.firstVoyageText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.understood),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await depot.session.voirRappelPremiereNavigation();
  }
  final bateaux = await depot.bateauxDuTelephone();
  if (!context.mounted) return;
  if (bateaux.isEmpty) {
    // Compte sans bateau : la fiche se crée sur le Web (D-132, D-141).
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.noBoatYet),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok)),
        ],
      ),
    );
    return;
  }
  await Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => StartReelScreen(bateaux: bateaux)));
}

/// Écran de démarrage (cahier des charges §5.3) de la vraie application.
class StartReelScreen extends StatefulWidget {
  const StartReelScreen({super.key, required this.bateaux});
  final List<BateauNl> bateaux;

  @override
  State<StartReelScreen> createState() => _StartReelScreenState();
}

class _StartReelScreenState extends State<StartReelScreen> {
  int bateau = 0;
  int? frequence;
  int? personnes;

  /// Personnes cochées « E-mail » (alertes du serveur : e-mails et
  /// notifications) et « SMS » (SMS du téléphone), toutes cochées au départ
  /// (RG-NAV-25, Q-102).
  Set<String>? alertees;
  Set<String>? alerteesSms;
  Map<String, bool>? smsParType;
  bool? smsActifs;
  bool envoi = false;
  final destination = TextEditingController();

  /// Personnes ajoutées par « Ajouter une personne » (RG-NAV-26) : nouveaux
  /// contacts, cochés, enregistrés au démarrage avec le périmètre choisi
  /// (RG-PAR-02) ; « Cette navigation seulement » vise la navigation qui
  /// démarre.
  final nouvelles = <({String id, Contact c, String perimetre})>[];

  /// Destination choisie sur une carte (RG-NAV-04).
  PositionGps? destinationPoint;

  /// Permission d'envoi de SMS (D-91 : sans elle, l'écran de démarrage dit
  /// que les positions automatiques partent au serveur seulement).
  bool? smsAutorise;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final canal = _depot(context).canalSms;
      if (!canal.disponible) return;
      final ok = await canal.autorise();
      if (mounted) setState(() => smsAutorise = ok);
    });
  }

  @override
  void dispose() {
    destination.dispose();
    super.dispose();
  }

  List<ContactNl> _alertables(Depot d) =>
      d.contacts.where((c) => c.suiveur || c.contactSos).toList();

  /// « E-mail » possible : adresse connue ou compte du suiveur (notifications).
  static bool _emailPossible(ContactNl c) =>
      (c.email?.trim().isNotEmpty ?? false) || c.utilisateurId != null;

  /// « SMS » possible : numéro connu (RG-SMS-01, RG-SOS-05).
  static bool _smsPossible(ContactNl c) =>
      c.telephone?.trim().isNotEmpty ?? false;

  /// Paramètres de cette navigation seulement (RG-NAV-06) : copie des
  /// paramètres généraux, modifiée par « Paramètres de cette navigation ».
  ParametresGeneraux? _parametres(Depot d) {
    final p = d.parametres;
    if (p == null && smsActifs == null) return null;
    return ParametresGeneraux(
      smsActifs: smsActifs ?? p?.smsActifs ?? true,
      smsParType: {...?p?.smsParType, ...?smsParType},
      photoEnMms: p?.photoEnMms ?? false,
      frequenceParDefaut: p?.frequenceParDefaut ?? 30,
    );
  }

  static const _typesSms = {
    'debut': SmsType.start,
    'positionsAutomatiques': SmsType.autoPosition,
    'positionsManuelles': SmsType.manualPosition,
    'notes': SmsType.note,
    'photos': SmsType.photo,
    'notesVocales': SmsType.voice,
    'incidents': SmsType.incident,
    'fin': SmsType.end,
  };

  Future<void> _reglages(Depot d) async {
    final l = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final p = _parametres(d);
          final actifs = p?.smsActifs ?? true;
          void changer(void Function() f) {
            setState(f);
            setSheet(() {});
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(
                      l.smsEnabled,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    value: actifs,
                    onChanged: (v) => changer(() => smsActifs = v),
                  ),
                  for (final e in _typesSms.entries)
                    SwitchListTile(
                      title: Text(smsTypeLabel(l, e.value)),
                      value: p?.smsParType[e.key] ?? true,
                      onChanged: actifs
                          ? (v) => changer(() => (smsParType ??= {})[e.key] = v)
                          : null,
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.sosAlwaysSent),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Explication avant la demande d'autorisation de localisation (RG-AND-02).
  Future<void> _expliquerPosition() async {
    final l = AppLocalizations.of(context);
    final gps = _depot(context).positions;
    if (gps is! GpsTelephone || await gps.autorisee() || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.my_location, color: NlColors.teal, size: 36),
        title: Text(l.locationTitle),
        content: Text(l.locationExplain),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok)),
        ],
      ),
    );
  }

  /// « Ajouter une personne » (RG-NAV-26) : nom, téléphone ou e-mail, puis
  /// ce que la personne verra comme suiveur (RG-PAR-02).
  Future<void> _ajouterPersonne() async {
    final l = AppLocalizations.of(context);
    final c = await Navigator.of(
      context,
    ).push<Contact>(MaterialPageRoute(builder: (_) => const AddPersonScreen()));
    if (c == null || !mounted) return;
    final perimetre = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l.scopeTitle),
        children: [
          SimpleDialogOption(
            key: const Key('add-scope-voyage'),
            onPressed: () => Navigator.pop(ctx, 'navigation'),
            child: Text(l.scopeThisVoyage),
          ),
          SimpleDialogOption(
            key: const Key('add-scope-navigator'),
            onPressed: () => Navigator.pop(ctx, 'navigateur'),
            child: Text(l.scopeNavigator),
          ),
        ],
      ),
    );
    if (perimetre == null || !mounted) return;
    final id = _depot(context).file.nouvelId();
    setState(() {
      nouvelles.add((id: id, c: c, perimetre: perimetre));
      if (c.email?.trim().isNotEmpty ?? false) alertees!.add(id);
      if (c.phone?.trim().isNotEmpty ?? false) alerteesSms!.add(id);
    });
  }

  /// Nouveaux contacts enregistrés une fois la navigation démarrée : suiveur
  /// avec le périmètre choisi (sauf adresse non confirmée, RG-CPT-09) et
  /// contact SOS s'il a un numéro (RG-CTC-01, RG-CTC-05).
  Future<void> _enregistrerNouvelles(
    DepotReel depot,
    String navigationId,
  ) async {
    final verifie = depot.profil?.emailVerifie != false;
    for (final x in nouvelles) {
      await depot.compte.ajouterContact(
        id: x.id,
        nom: x.c.name,
        telephone: x.c.phone,
        email: x.c.email,
        suiveur: verifie,
        perimetre: x.perimetre,
        navigationId: navigationId,
      );
    }
  }

  Future<void> _demarrer() async {
    final depot = _depot(context);
    final l = AppLocalizations.of(context);
    setState(() => envoi = true);
    try {
      await _expliquerPosition();
      if (!mounted) return;
      final p = _parametres(depot);
      await demanderSms(
        context,
        depot,
        positionsAutomatiques:
            (p?.smsActifs ?? true) &&
            p?.smsParType['positionsAutomatiques'] != false,
      );
      if (!mounted) return;
      await proposerBatterie(context, depot);
      final n = await depot.demarrer(
        bateau: widget.bateaux[bateau],
        frequenceMinutes: frequence!,
        personnesABord: personnes!,
        personnesAlertees: alertees!.toList(),
        personnesSms: depot.canalSms.disponible ? alerteesSms!.toList() : null,
        destination: destination.text,
        destinationPosition: destinationPoint,
        parametres: _parametres(depot),
      );
      if (!mounted) return;
      await _enregistrerNouvelles(depot, n.id);
      final etat = await depot.file.etat('demarrage:${n.id}');
      // SMS de début, prérempli (RG-NAV-08, RG-SMS-03).
      final sms = depot.canalSms.disponible
          ? await depot.sms.ordinaire(
              n,
              'debut',
              defaut: depot.parametres,
              position: n.journal.firstOrNull?.position,
            )
          : null;
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => NavigationReelScreen(
            resultat: (l.voyageStarted, lignesResultat(l, etat, sms: sms)),
          ),
        ),
      );
    } on RefusDemarrage catch (r) {
      if (mounted) await _refus(r);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(messageErreur(l, e))));
    } finally {
      if (mounted) setState(() => envoi = false);
    }
  }

  /// Démarrage refusé : quota épuisé (RG-ECO-04, avec l'heure du retour des
  /// minutes et l'abonnement) ou message du serveur.
  Future<void> _refus(RefusDemarrage r) {
    final l = AppLocalizations.of(context);
    final quand = r.disponibleLe;
    final texte = r.quotaEpuise
        ? (quand == null
              ? l.startQuotaExhaustedNoDate
              : l.startQuotaExhausted(fmtDate(l, quand.toLocal())))
        : (r.erreur?.message.isNotEmpty == true
              ? r.erreur!.message
              : l.errorGeneric);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.startRefused),
        content: Text(texte, key: const Key('start-refused')),
        actions: [
          if (r.quotaEpuise)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const QuotaScreen()));
              },
              child: Text(l.menuQuota),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final depot = _depot(context);
    final l = AppLocalizations.of(context);
    final alertables = _alertables(depot);
    frequence ??= depot.parametres?.frequenceParDefaut ?? 30;
    if (!frequencies.contains(frequence)) frequence = 30;
    personnes ??= depot.session.dernierNombrePersonnes;
    final smsCircuit = depot.canalSms.disponible;
    alertees ??= {
      for (final c in alertables)
        if (_emailPossible(c)) c.id,
    };
    alerteesSms ??= {
      for (final c in alertables)
        if (_smsPossible(c)) c.id,
    };
    final aucunSos = !depot.contacts.any((c) => c.contactSos);
    final sosCoche = alertables.any(
      (c) =>
          c.contactSos &&
          (alertees!.contains(c.id) ||
              (smsCircuit && alerteesSms!.contains(c.id))),
    );
    Widget choix(
      String id,
      String nom, {
      required bool email,
      required bool sms,
      String? note,
    }) => ListTile(
      key: Key('alerted-$id'),
      contentPadding: EdgeInsets.zero,
      title: note == null
          ? Text(nom)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nom),
                Text(note, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
      subtitle: Wrap(
        spacing: 8,
        children: [
          FilterChip(
            key: Key('alert-email-$id'),
            avatar: const Icon(Icons.alternate_email, size: 18),
            label: Text(l.alertByEmail),
            selected: alertees!.contains(id),
            onSelected: email
                ? (v) => setState(
                    () => v ? alertees!.add(id) : alertees!.remove(id),
                  )
                : null,
          ),
          if (smsCircuit)
            FilterChip(
              key: Key('alert-sms-$id'),
              avatar: const Icon(Icons.sms_outlined, size: 18),
              label: Text(l.alertBySms),
              selected: alerteesSms!.contains(id),
              onSelected: sms
                  ? (v) => setState(
                      () => v ? alerteesSms!.add(id) : alerteesSms!.remove(id),
                    )
                  : null,
            ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.startVoyage)),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // RG-NAV-02 : pas de choix avec un seul bateau.
                if (widget.bateaux.length > 1) ...[
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: bateau,
                    decoration: InputDecoration(
                      labelText: l.boat,
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (var i = 0; i < widget.bateaux.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(widget.bateaux[i].nom),
                        ),
                    ],
                    onChanged: (v) => setState(() => bateau = v ?? 0),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Text(
                    '${l.boat} : ${widget.bateaux.first.nom}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                ],
                // RG-NAV-04 : destination facultative, en texte (carte : TODO).
                TextField(
                  key: const Key('start-destination'),
                  controller: destination,
                  decoration: InputDecoration(
                    labelText: l.destinationOptional,
                    hintText: l.destinationHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
                // RG-NAV-04 : ou un point choisi sur une carte.
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('start-destination-map'),
                    icon: const Icon(Icons.map_outlined),
                    label: Text(l.destinationOnMap),
                    onPressed: () async {
                      final p = await Navigator.of(context).push<PositionGps>(
                        MaterialPageRoute(
                          builder: (_) => DestinationCarteScreen(
                            initiale:
                                destinationPoint ??
                                depot.positions.derniereConnue,
                          ),
                        ),
                      );
                      if (p != null && mounted) {
                        setState(() => destinationPoint = p);
                      }
                    },
                  ),
                ),
                if (destinationPoint != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.place, color: NlColors.teal),
                    title: Text(
                      l.destinationPoint(coordonnees(destinationPoint!)),
                      key: const Key('destination-point'),
                    ),
                    trailing: IconButton(
                      tooltip: l.destinationRemovePoint,
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() => destinationPoint = null),
                    ),
                  ),
                const SizedBox(height: 16),
                // RG-NAV-27 : nombre de personnes à bord, repris dans le SOS.
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: l.personsOnBoard,
                    border: const OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: l.onePersonLess,
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: personnes! > 1
                            ? () => setState(() => personnes = personnes! - 1)
                            : null,
                      ),
                      Expanded(
                        child: Text(
                          '${personnes!}',
                          key: const Key('persons'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: kMonoFont,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l.onePersonMore,
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () =>
                            setState(() => personnes = personnes! + 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // RG-NAV-05 : fréquence préremplie par les paramètres généraux.
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: frequence,
                  decoration: InputDecoration(
                    labelText: l.autoFrequency,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    for (final f in frequencies)
                      DropdownMenuItem(
                        value: f,
                        child: Text(frequencyLabel(l, f)),
                      ),
                  ],
                  onChanged: (v) => setState(() => frequence = v),
                ),
                const SizedBox(height: 20),
                // RG-NAV-25 : personnes alertées, toutes cochées.
                Text(
                  l.alertedPersons,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                // TODO-5.13 (demande du 2026-11-26) : « Début de navigation »
                // avec la liste des personnes alertées, juste au-dessus d'elle.
                const SizedBox(height: 8),
                FilledButton(
                  key: const Key('start-send'),
                  onPressed: envoi ? null : _demarrer,
                  child: envoi
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l.sendStart),
                ),
                const SizedBox(height: 8),
                if (alertables.isEmpty) Text(l.noAlertablePerson),
                // Q-102 : un sélecteur « E-mail » et un « SMS » par personne,
                // sans distinguer suiveur et contact SOS.
                for (final c in alertables)
                  choix(
                    c.id,
                    c.nom,
                    email: _emailPossible(c),
                    sms: _smsPossible(c),
                  ),
                for (final x in nouvelles)
                  choix(
                    x.id,
                    x.c.name,
                    email: x.c.email?.trim().isNotEmpty ?? false,
                    sms: x.c.phone?.trim().isNotEmpty ?? false,
                    note: l.addPersonPending,
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('start-add-person'),
                    icon: const Icon(Icons.person_add_alt),
                    label: Text(l.addPerson),
                    onPressed: _ajouterPersonne,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.tune),
                    label: Text(l.voyageSettings),
                    onPressed: () => _reglages(depot),
                  ),
                ),
                // RG-IOS-02, RG-IOS-04 : sur iPhone, SOS par Internet seulement ;
                // contacts SOS sans e-mail, qui ne seront pas prévenus.
                if (depot.plateforme == 'ios') ...[
                  Card(
                    color: const Color(0xFFFBE9E9),
                    child: ListTile(
                      leading: const Icon(
                        Icons.phone_iphone,
                        color: NlColors.alert,
                      ),
                      title: Text(
                        l.iosStartWarning,
                        key: const Key('ios-start-warning'),
                      ),
                      subtitle: () {
                        final sansEmail = [
                          for (final c in depot.contacts)
                            if (c.contactSos &&
                                (c.email?.trim().isEmpty ?? true))
                              c.nom,
                        ];
                        return sansEmail.isEmpty
                            ? null
                            : Text(
                                l.iosStartNoEmail(sansEmail.join(', ')),
                                key: const Key('ios-no-email'),
                              );
                      }(),
                    ),
                  ),
                ],
                // D-91 : sans permission d'envoi de SMS, positions au serveur seulement.
                if (smsAutorise == false &&
                    (_parametres(depot)?.smsActifs ?? true) &&
                    _parametres(depot)?.smsParType['positionsAutomatiques'] !=
                        false)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.sms_failed_outlined),
                      title: Text(
                        l.smsAutoOffNotice,
                        key: const Key('sms-auto-off'),
                      ),
                    ),
                  ),
                // RG-SOS-14, RG-NAV-25 : avertissement sans contact SOS.
                if (aucunSos || !sosCoche)
                  Card(
                    color: const Color(0xFFFBE9E9),
                    child: ListTile(
                      leading: const Icon(
                        Icons.warning_amber,
                        color: NlColors.alert,
                      ),
                      title: Text(aucunSos ? l.noSosContact : l.noSosChecked),
                    ),
                  ),
                const SizedBox(height: 16),
                const PiedDePage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- navigation

/// Écran de navigation en cours (cahier des charges §5.4) de la vraie
/// application. Aucune carte (RG-NAV-09).
class NavigationReelScreen extends StatefulWidget {
  const NavigationReelScreen({super.key, this.resultat});

  /// Résultat du démarrage à afficher à l'ouverture (RG-COM-03).
  final (String, List<String>)? resultat;

  @override
  State<NavigationReelScreen> createState() => _NavigationReelScreenState();
}

class _NavigationReelScreenState extends State<NavigationReelScreen> {
  Timer? ticker;
  bool envoi = false;
  bool propositionOuverte = false;

  /// Fin confirmée, envoi en cours : l'écran dit « Navigation terminée, en
  /// cours d'envoi » au lieu de « Aucune navigation en cours » (Q-102).
  bool finEnCours = false;

  /// RG-NAV-24 : « Terminer la navigation » ou « Continuer » après 2 heures
  /// sans éloignement de plus de 20 mètres.
  void _proposerFin(DepotReel depot) {
    if (propositionOuverte || envoi || !depot.conduite.propositionFin) return;
    propositionOuverte = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final l = AppLocalizations.of(context);
      final fin = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(l.endVoyageQuestion),
          content: Text(l.stationaryText, key: const Key('stationary')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.continueLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.endVoyage),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (fin == true) {
        propositionOuverte = false;
        await _terminer(depot, confirme: true);
      } else {
        await depot.conduite.continuer();
        propositionOuverte = false;
      }
    });
  }

  /// Envoi par le navigateur, puis SMS prérempli de ce [type] (RG-SMS-03),
  /// puis résultat de chaque circuit (RG-COM-03).
  Future<void> _envoyer(
    String titre,
    String type,
    Future<EtatEnvoi?> Function() f, {
    String? Function()? photo,
    String Function()? titreFinal,
  }) async {
    if (envoi) return;
    final l = AppLocalizations.of(context);
    final depot = _depot(context);
    setState(() => envoi = true);
    EtatEnvoi? etat;
    (IssueSms, int)? sms;
    try {
      etat = await f();
      final n = depot.conduite.enCours;
      if (etat != null &&
          !etat.refuse &&
          n != null &&
          n.journal.isNotEmpty &&
          depot.canalSms.disponible) {
        final e = n.journal.last;
        // Type de l'événement créé : « NOTE » crée une note ou un incident
        // (D-165), chacun avec sa préférence de SMS (RG-SMS-02).
        sms = await depot.sms.ordinaire(
          n,
          e.type,
          defaut: depot.parametres,
          position: e.position,
          note: e.texte,
          evenementId: e.id,
          photo: photo?.call(),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(messageErreur(l, e))));
      }
    } finally {
      if (mounted) setState(() => envoi = false);
    }
    if (etat == null || !mounted) return;
    await showSendResult(
      context,
      etat.refuse ? l.sendRefused : (titreFinal?.call() ?? titre),
      lignesResultat(l, etat, sms: sms),
    );
  }

  /// « Terminer la navigation » : confirmation, fin envoyée (ou gardée sans
  /// Internet, RG-NAV-14), résultat, puis page détaillée de la navigation
  /// sur la plateforme Web (RG-NAV-13) ; hors connexion, message (RG-COM-06).
  Future<void> _terminer(DepotReel depot, {bool confirme = false}) async {
    final l = AppLocalizations.of(context);
    final ok = confirme
        ? true
        : await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l.endVoyageQuestion),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l.end),
                ),
              ],
            ),
          );
    if (ok != true || !mounted) return;
    setState(() {
      envoi = true;
      finEnCours = true;
    });
    final avant = depot.conduite.enCours;
    final r = await depot.terminer();
    if (!mounted) return;
    if (r == null) {
      setState(() {
        envoi = false;
        finEnCours = false;
      });
      return;
    }
    final (id, etat) = r;
    // SMS de fin, prérempli (RG-NAV-13, RG-SMS-03), avec la position de fin.
    final sms = avant != null && depot.canalSms.disponible && !etat.refuse
        ? await depot.sms.ordinaire(
            avant,
            'fin',
            defaut: depot.parametres,
            position: depot.conduite.derniereFin,
          )
        : null;
    if (!mounted) return;
    final nav = Navigator.of(context);
    await showSendResult(context, l.voyageFinished, [
      ...lignesResultat(l, etat, sms: sms),
      if (!etat.recu && !etat.refuse) l.pageOffline,
    ]);
    if (etat.recu) {
      try {
        await ouvrirLien(Uri.parse(voyagePageUrl(id)));
      } catch (e) {
        debugPrint('Page de la navigation : $e');
      }
    }
    if (nav.mounted) nav.pop();
  }

  /// Note, photo ou note vocale du journal (RG-JRN-06) : modifier le texte,
  /// supprimer, ou voir la photo et écouter la note vocale dans le journal
  /// complet de la navigation.
  Future<void> _actionsEvenement(
    DepotReel depot,
    NavigationLocale n,
    EvenementLocal e,
  ) async {
    final l = AppLocalizations.of(context);
    final choix = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l.eventEdit),
              onTap: () => Navigator.pop(ctx, 'modifier'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: NlColors.alert),
              title: Text(l.eventDelete),
              onTap: () => Navigator.pop(ctx, 'supprimer'),
            ),
            if (e.type != 'note')
              ListTile(
                leading: const Icon(Icons.menu_book),
                title: Text(l.eventFullLog),
                onTap: () => Navigator.pop(ctx, 'journal'),
              ),
          ],
        ),
      ),
    );
    if (choix == null || !mounted) return;
    if (choix == 'journal') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NavigationSuivieScreen(navigationId: n.id),
        ),
      );
      return;
    }
    String? texte;
    if (choix == 'modifier') {
      texte = await _texte(l.eventEdit, l.noteHint, initial: e.texte);
      if (texte == null) return;
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l.eventDeleteConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.eventDelete),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await depot.changerEvenement(
        e.id,
        texte: texte,
        supprimer: choix == 'supprimer',
      );
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err is HorsConnexion ? l.eventChangeOffline : messageErreur(l, err),
          ),
        ),
      );
    }
  }

  Future<String?> _texte(String titre, String aide, {String? initial}) {
    final c = TextEditingController(text: initial);
    final l = AppLocalizations.of(context);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: TextField(
          key: const Key('note-text'),
          controller: c,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: aide),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: Text(l.validateSend),
          ),
        ],
      ),
    );
  }

  /// Fenêtre de « NOTE » (D-165) : « Note » ou « Incident - avarie » ; pour
  /// un incident ou une avarie, texte obligatoire et une pièce jointe
  /// facultative, photo ou note vocale (RG-JRN-11).
  Future<({bool incident, String texte, String piece})?> _saisieNote(
    bool avecMedias,
  ) {
    final c = TextEditingController();
    final l = AppLocalizations.of(context);
    var incident = false;
    var piece = 'aucune';
    return showDialog<({bool incident, String texte, String piece})>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, majDialogue) => AlertDialog(
          title: Text(l.noteTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SegmentedButton<bool>(
                  key: const Key('note-kind'),
                  segments: [
                    ButtonSegment(value: false, label: Text(l.noteKindNote)),
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.report_problem_outlined),
                      label: Text(l.noteKindIncident),
                    ),
                  ],
                  selected: {incident},
                  onSelectionChanged: (v) =>
                      majDialogue(() => incident = v.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('note-text'),
                  controller: c,
                  autofocus: true,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: incident ? l.incidentHint : l.noteHint,
                  ),
                ),
                if (incident && avecMedias) ...[
                  const SizedBox(height: 12),
                  Text(l.incidentAttachment),
                  RadioGroup<String>(
                    groupValue: piece,
                    onChanged: (v) => majDialogue(() => piece = v ?? piece),
                    child: Column(
                      children: [
                        for (final (v, t) in [
                          ('aucune', l.attachmentNone),
                          ('photo', l.attachmentPhoto),
                          ('vocal', l.attachmentVoice),
                        ])
                          RadioListTile<String>(
                            key: Key('incident-piece-$v'),
                            value: v,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(t),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l.cancel),
            ),
            TextButton(
              // RG-JRN-11 : texte obligatoire, pour une note comme pour un
              // incident : sans texte, la fenêtre reste ouverte.
              onPressed: () {
                if (c.text.trim().isEmpty) return;
                Navigator.pop(ctx, (
                  incident: incident,
                  texte: c.text.trim(),
                  piece: incident ? piece : 'aucune',
                ));
              },
              child: Text(l.validateSend),
            ),
          ],
        ),
      ),
    );
  }

  /// Incident ou avarie (RG-JRN-11, D-165), avec sa pièce jointe éventuelle :
  /// photo prise ou note vocale enregistrée comme par « Photo » et « Vocal ».
  Future<EtatEnvoi?> _incident(
    DepotReel depot,
    ({bool incident, String texte, String piece}) s,
  ) async {
    final c = depot.conduite;
    final medias = depot.medias;
    final l = AppLocalizations.of(context);
    if (s.piece == 'aucune' || medias == null) return c.incident(s.texte);
    final id = depot.file.nouvelId();
    if (s.piece == 'photo') {
      final f = await medias.photo(id);
      if (f == null) return null;
      return c.incident(
        s.texte,
        id: id,
        chemin: f.chemin,
        typeMedia: 'image/jpeg',
        taille: f.tailleOctets,
      );
    }
    if (!await medias.commencerVocal(id)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.micRefused)));
      }
      return null;
    }
    if (!mounted) return null;
    final r = await showDialog<(FichierMedia, int)>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EnregistrementVocal(medias: medias),
    );
    if (r == null) return null;
    return c.incident(
      s.texte,
      id: id,
      chemin: r.$1.chemin,
      typeMedia: 'audio/mp4',
      taille: r.$1.tailleOctets,
      dureeSecondes: r.$2,
    );
  }

  List<Widget> _boutons(DepotReel depot, AppLocalizations l) {
    final c = depot.conduite;
    final medias = depot.medias;
    return [
      FilledButton.icon(
        icon: const Icon(Icons.my_location),
        label: Text(l.sendPosition),
        onPressed: envoi
            ? null
            : () => _envoyer(
                l.positionSent,
                'position_manuelle',
                c.positionManuelle,
              ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.edit_note),
              label: Text(l.noteButton),
              onPressed: envoi
                  ? null
                  : () {
                      var titre = l.noteSent;
                      _envoyer(l.noteSent, 'note', () async {
                        final s = await _saisieNote(medias != null);
                        if (s == null) return null;
                        if (!s.incident) return c.note(s.texte);
                        titre = l.incidentSent;
                        return _incident(depot, s);
                      }, titreFinal: () => titre);
                    },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(l.photoButton),
              onPressed: envoi || medias == null
                  ? null
                  : () {
                      String? chemin;
                      _envoyer(l.photoSent, 'photo', () async {
                        final id = depot.file.nouvelId();
                        final f = await medias.photo(id);
                        if (f == null) return null;
                        // Copie pour le MMS : la photo du téléphone est
                        // effacée après son dépôt sur le serveur.
                        final p = c.enCours?.parametres ?? depot.parametres;
                        if (depot.canalSms.disponible &&
                            p?.photoEnMms == true) {
                          chemin = await depot.sms.copierPhoto(f.chemin);
                        }
                        return c.photo(id, f.chemin, f.tailleOctets);
                      }, photo: () => chemin);
                    },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.mic_none),
              label: Text(l.voiceButton),
              onPressed: envoi || medias == null
                  ? null
                  : () => _envoyer(l.voiceSent, 'note_vocale', () async {
                      final id = depot.file.nouvelId();
                      if (!await medias.commencerVocal(id)) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(l.micRefused)));
                        }
                        return null;
                      }
                      if (!mounted) return null;
                      final r = await showDialog<(FichierMedia, int)>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => _EnregistrementVocal(medias: medias),
                      );
                      if (r == null) return null;
                      return c.noteVocale(
                        id,
                        r.$1.chemin,
                        r.$1.tailleOctets,
                        r.$2,
                      );
                    }),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    final r = widget.resultat;
    if (r != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showSendResult(context, r.$1, r.$2);
      });
    }
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final depot = _depot(context);
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: depot.conduite,
      builder: (context, _) {
        final n = depot.conduite.enCours;
        if (n == null) {
          return Scaffold(
            appBar: AppBar(),
            body: PageAvecPied(
              child: finEnCours
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          l.voyageEndingSending,
                          key: const Key('voyage-ending'),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : Text(l.noVoyageInProgress),
            ),
          );
        }
        final maintenant = depot.conduite.maintenant;
        final refus = n.refus;
        _proposerFin(depot);
        return Scaffold(
          appBar: AppBar(title: Text(n.bateauNom)),
          body: Column(
            children: [
              const BandeauHorsConnexion(),
              Expanded(
                child: RadarBackground(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        n.nom,
                        key: const Key('voyage-name'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (refus != null)
                        Card(
                          color: const Color(0xFFFBE9E9),
                          child: ListTile(
                            leading: const Icon(
                              Icons.error_outline,
                              color: NlColors.alert,
                            ),
                            title: Text(l.voyageRefused(refus)),
                          ),
                        ),
                      // RG-NAV-10, Q-102 : les deux chronomètres dans la même
                      // zone ; le second remis à zéro par tout envoi reçu.
                      Chronos(
                        depuisDebut: maintenant.difference(n.debut),
                        depuisDernierEnvoi: maintenant.difference(
                          n.dernierEnvoi ?? n.debut,
                        ),
                      ),
                      if (refus == null &&
                          depot.conduite.prochaineAutomatique != null) ...[
                        const SizedBox(height: 8),
                        // RG-GPS-03 : positions automatiques à la fréquence choisie.
                        Text(
                          l.nextAutoPosition(
                            fmtTime(depot.conduite.prochaineAutomatique!),
                          ),
                          key: const Key('next-auto-position'),
                        ),
                      ],
                      // RG-SMS-07 : SMS de position automatique en échec après 3 essais.
                      ListenableBuilder(
                        listenable: depot.envoisSms,
                        builder: (context, _) => Column(
                          children: [
                            for (final s in depot.envoisSms.echecsPosition)
                              Card(
                                color: const Color(0xFFFBE9E9),
                                child: ListTile(
                                  leading: const Icon(
                                    Icons.sms_failed_outlined,
                                    color: NlColors.alert,
                                  ),
                                  title: Text(
                                    l.smsAutoFailed(s.destinataire.numero),
                                  ),
                                  trailing: TextButton(
                                    onPressed: () =>
                                        depot.envoisSms.reessayer(s),
                                    child: Text(l.retry),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Q-102 : lien vers la météo marine.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const Key('weather-link'),
                          icon: const Icon(Icons.cloud_outlined),
                          label: Text(l.weatherLink),
                          onPressed: () =>
                              ouvrirLien(Uri.parse(meteoMarineUrl)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._boutons(depot, l),
                      const SizedBox(height: 24),
                      SosButton(onPressed: () => confirmSosReel(context)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: envoi ? null : () => _terminer(depot),
                        child: Text(l.endVoyage),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l.logbook,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final e in n.journal.reversed)
                        EvenementTile(
                          evenement: e,
                          onTap:
                              const {
                                'note',
                                'photo',
                                'note_vocale',
                                'incident',
                              }.contains(e.type)
                              ? () => _actionsEvenement(depot, n, e)
                              : null,
                        ),
                      const PiedDePage(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Les deux chronomètres de l'écran de navigation dans une même zone
/// (RG-NAV-10, Q-102) : en grand, « Depuis le début » ; dessous, plus petit,
/// « Depuis le dernier envoi position ».
class Chronos extends StatelessWidget {
  const Chronos({
    super.key,
    required this.depuisDebut,
    required this.depuisDernierEnvoi,
  });

  final Duration depuisDebut;
  final Duration depuisDernierEnvoi;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final petit = Theme.of(context).textTheme.bodySmall;
    const chiffres = [FontFeature.tabularFigures()];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(l.sinceStart, style: petit),
            Text(
              fmtClock(depuisDebut),
              key: const Key('since-start'),
              style: const TextStyle(
                fontFamily: kMonoFont,
                fontSize: 34,
                fontWeight: FontWeight.w600,
                fontFeatures: chiffres,
              ),
            ),
            const Divider(height: 16),
            Text(l.sinceLastSend, style: petit),
            Text(
              fmtClock(depuisDernierEnvoi),
              key: const Key('since-last-send'),
              style: const TextStyle(
                fontFamily: kMonoFont,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                fontFeatures: chiffres,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- reprise

/// « Reprendre la dernière navigation » de la vraie application (RG-NAV-12).
Future<void> openNavigationReel(BuildContext context) async {
  await _depot(context).reprendre();
  if (!context.mounted) return;
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const NavigationReelScreen()));
}

// ---------------------------------------------------------------- SOS

/// Ouverture d'un lien (application SMS) ; remplacée dans les essais.
Future<bool> Function(Uri) ouvrirLien = (u) =>
    launchUrl(u, mode: LaunchMode.externalApplication);

/// « Envoyer un SOS » de la vraie application, depuis l'accueil ou l'écran
/// de navigation (RG-SOS-01, RG-SOS-15). Pendant la navigation du téléphone,
/// l'alerte lui est rattachée ; sinon au bateau du téléphone, choisi s'il y
/// en a plusieurs, avant la confirmation (D-142).
Future<void> confirmSosReel(BuildContext context) async {
  final depot = _depot(context);
  final l = AppLocalizations.of(context);
  BateauNl? bateau;
  if (depot.conduite.enCours == null) {
    final bateaux = await depot.bateauxDuTelephone();
    if (!context.mounted) return;
    if (bateaux.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.sos, color: NlColors.alert, size: 40),
          content: Text(l.sosReelNoBoat),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.ok)),
          ],
        ),
      );
      return;
    }
    bateau = bateaux.length == 1
        ? bateaux.single
        : await showDialog<BateauNl>(
            context: context,
            builder: (ctx) => SimpleDialog(
              title: Text(l.sosReelChooseBoat),
              children: [
                for (final b in bateaux)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, b),
                    child: Text(b.nom),
                  ),
              ],
            ),
          );
    if (bateau == null || !context.mounted) return;
  }
  // RG-SOS-02 : confirmation, « Problème rencontré » facultatif.
  final probleme = await showDialog<String>(
    context: context,
    builder: (_) => const SosDialog(),
  );
  if (probleme == null || !context.mounted) return;
  ScaffoldMessenger.of(context).clearSnackBars();
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => SosReelScreen(bateau: bateau, probleme: probleme),
    ),
  );
}

/// Envoi et résultat du SOS (RG-SOS-04, RG-COM-03) : position, SMS SOS
/// prérempli (RG-AND-04 : pas d'envoi automatique dans cette version),
/// alerte au serveur, journal, résultat de chaque étape.
class SosReelScreen extends StatefulWidget {
  const SosReelScreen({super.key, this.bateau, this.probleme = ''});

  /// Bateau d'un SOS depuis l'accueil ; vide pendant la navigation.
  final BateauNl? bateau;
  final String probleme;

  @override
  State<SosReelScreen> createState() => _SosReelScreenState();
}

class _SosReelScreenState extends State<SosReelScreen> {
  (PositionGps?, NaturePosition)? position;
  (IssueSms, int)? sms;
  String? alerteId;
  AlerteEnvoyee? alerte;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _lancer());
  }

  /// Premier SMS SOS (RG-SOS-07, RG-SOS-09 à RG-SOS-11), dans la langue de
  /// l'interface (RG-PRM-04).
  String _texteSms(AppLocalizations l, DepotReel d) {
    final n = d.conduite.enCours;
    final b =
        widget.bateau ??
        d.bateaux.where((x) => x.id == n?.bateauId).firstOrNull;
    final nom = b?.nom ?? n?.bateauNom ?? '';
    final type = b?.type == 'moteur' ? l.sosReelMotorboat : l.sosReelSailboat;
    final longueur = b?.longueurMetres == null
        ? '—'
        : '${b!.longueurMetres!.toStringAsFixed(1)} m';
    final personnes = n?.personnesABord ?? d.session.dernierNombrePersonnes;
    final p = position?.$1;
    final coord = p == null
        ? ''
        : '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
    return [
      l.sosSmsBoat(nom, type, longueur, b?.immatriculation ?? '—'),
      l.sosSmsPersons(personnes),
      if (widget.probleme.isNotEmpty) l.sosSmsProblem(widget.probleme),
      switch (position?.$2) {
        NaturePosition.actuelle => l.sosSmsPosition(
          coord,
          heureEnvoyee(l, p!.heureAcquisition),
        ),
        NaturePosition.derniereConnue => l.sosReelSmsLastKnown(
          coord,
          heureEnvoyee(l, p!.heureAcquisition, avecDate: true),
        ),
        _ => l.sosReelSmsNoPosition,
      },
      if (p != null) lienCarte(p),
    ].join('\n');
  }

  /// Second SMS SOS (RG-SOS-08).
  String _secondSms(DepotReel d) {
    final n = d.conduite.enCours;
    final b =
        widget.bateau ??
        d.bateaux.where((x) => x.id == n?.bateauId).firstOrNull;
    return d.sms.secondSos(b, b?.nom ?? n?.bateauNom ?? '');
  }

  Future<void> _lancer() async {
    final d = _depot(context);
    final l = AppLocalizations.of(context);
    // 1. Position (RG-SOS-09 à RG-SOS-11, RG-SOS-23).
    final pos = await d.conduite.positionSos();
    if (!mounted) return;
    final id = d.file.nouvelId();
    setState(() {
      position = pos;
      alerteId = id;
    });
    // 2. SMS aux contacts SOS (Android, RG-SOS-05 à RG-SOS-08, RG-SOS-16),
    // 3. alerte au serveur, sans qu'une étape attende l'autre (RG-SOS-04).
    final envoi = d.conduite.envoyerSos(
      id: id,
      position: pos.$1,
      nature: pos.$2,
      bateauId: widget.bateau?.id,
      probleme: widget.probleme,
      personnesABord: d.session.dernierNombrePersonnes,
    );
    if (d.canalSms.disponible) {
      final r = await d.sms.sos(
        alerteId: id,
        navigation: d.conduite.enCours,
        premier: _texteSms(l, d),
        second: _secondSms(d),
      );
      if (mounted) setState(() => sms = r);
    }
    final a = await envoi;
    if (mounted) setState(() => alerte = a);
  }

  /// Ligne d'un SMS SOS envoyé automatiquement, avec son état (RG-SOS-12).
  Widget _ligneSms(AppLocalizations l, SmsSuivi s) {
    final (icone, etat, couleur) = switch (s.etat) {
      EtatSms.enAttente => (Icons.schedule, l.sosSmsPending, null),
      EtatSms.acceptePourEnvoi => (
        Icons.sms_outlined,
        l.sosSmsAccepted(s.destinataire.numero),
        null,
      ),
      EtatSms.livraisonConfirmee => (
        Icons.mark_chat_read_outlined,
        l.sosSmsDelivered,
        null,
      ),
      EtatSms.echec => (
        Icons.sms_failed_outlined,
        l.sosSmsFailed,
        NlColors.alert,
      ),
    };
    return ListTile(
      dense: true,
      leading: Icon(icone, color: couleur ?? NlColors.teal),
      title: Text(s.destinataire.numero),
      subtitle: Text('${s.rang == 2 ? '2/2' : '1/2'} · $etat'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = position;
    final a = alerte;
    String? textePosition;
    if (p != null) {
      final q = p.$1;
      final coord = q == null
          ? ''
          : '${q.latitude.toStringAsFixed(5)}, ${q.longitude.toStringAsFixed(5)}';
      textePosition = switch (p.$2) {
        NaturePosition.actuelle => l.sosSmsPosition(
          coord,
          heureEnvoyee(l, q!.heureAcquisition),
        ),
        NaturePosition.derniereConnue => l.sosReelSmsLastKnown(
          coord,
          heureEnvoyee(l, q!.heureAcquisition, avecDate: true),
        ),
        NaturePosition.aucune => l.sosReelSmsNoPosition,
      };
    }
    Widget ligne(IconData i, String titre, String? detail, {Color? couleur}) =>
        ListTile(
          leading: Icon(i, color: couleur ?? NlColors.teal),
          title: Text(titre),
          subtitle: detail == null ? null : Text(detail),
        );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.sosAlert),
        backgroundColor: NlColors.alert,
        foregroundColor: NlColors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Les secours d'abord : NautiLink n'est pas un équipement de sécurité.
          Text(
            l.homeDistressHint,
            key: const Key('sos-distress'),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: NlColors.alert),
          ),
          const SizedBox(height: 12),
          if (p == null)
            ligne(Icons.gps_not_fixed, l.sosReelSearching, null)
          else
            ligne(
              p.$2 == NaturePosition.aucune ? Icons.gps_off : Icons.gps_fixed,
              textePosition!,
              null,
              couleur: p.$2 == NaturePosition.actuelle ? null : NlColors.alert,
            ),
          ...switch (sms?.$1) {
            IssueSms.sansDestinataire => [
              ligne(
                Icons.sms_failed_outlined,
                l.sosReelSmsNoContact,
                null,
                couleur: NlColors.alert,
              ),
            ],
            IssueSms.prerempli => [
              ligne(Icons.sms_outlined, l.sosReelSmsOpened, null),
            ],
            IssueSms.echec => [
              ligne(
                Icons.sms_failed_outlined,
                l.sosReelSmsFailed,
                null,
                couleur: NlColors.alert,
              ),
            ],
            IssueSms.automatique => [
              ListenableBuilder(
                listenable: _depot(context).envoisSms,
                builder: (context, _) {
                  final envois = _depot(context).envoisSms;
                  final g = 'sos:$alerteId';
                  final liste = envois.groupe(g);
                  return Column(
                    children: [
                      ligne(
                        Icons.sms_outlined,
                        l.sosSmsAutoSent(sms!.$2),
                        null,
                      ),
                      for (final s in liste) _ligneSms(l, s),
                      if (envois.sosRetentes(g)) ...[
                        ligne(
                          Icons.autorenew,
                          l.sosSmsRetrying,
                          null,
                          couleur: NlColors.alert,
                        ),
                        OutlinedButton(
                          key: const Key('sos-stop-retry'),
                          onPressed: () => envois.arreterSos(g),
                          child: Text(l.sosSmsStopRetry),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
            _ => const <Widget>[],
          },
          if (a == null)
            ligne(Icons.cloud_upload_outlined, l.sosReelSending, null)
          else if (a.etat.refuse)
            ligne(
              Icons.cloud_off,
              l.voyageRefused(a.etat.refus!.message),
              null,
              couleur: NlColors.alert,
            )
          else if (!a.etat.recu && _depot(context).plateforme == 'ios')
            // RG-IOS-03 : sans Internet, l'alerte ne part pas de l'iPhone ;
            // elle part dès le retour de la connexion.
            ligne(
              Icons.cloud_off,
              l.iosSosOffline,
              null,
              couleur: NlColors.alert,
            )
          else
            ligne(
              a.etat.recu ? Icons.cloud_done_outlined : Icons.cloud_queue,
              a.etat.recu ? l.sosReelServerReceived : l.sosReelServerQueued,
              null,
              couleur: a.etat.recu ? null : NlColors.alert,
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.back),
          ),
          const PiedDePage(),
        ],
      ),
    );
  }
}

/// Note vocale en cours d'enregistrement : 1 minute au plus, arrêt
/// automatique (RG-JRN-04), sans mention de la limite à l'écran (Q-102,
/// proposition appliquée en attendant). Rend le fichier et la durée en
/// secondes.
class _EnregistrementVocal extends StatefulWidget {
  const _EnregistrementVocal({required this.medias});
  final Medias medias;

  @override
  State<_EnregistrementVocal> createState() => _EnregistrementVocalState();
}

class _EnregistrementVocalState extends State<_EnregistrementVocal> {
  int secondes = 0;
  Timer? minuterie;
  bool fini = false;

  @override
  void initState() {
    super.initState();
    minuterie = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => secondes++);
      if (secondes >= 60) _arreter(); // 1 minute au plus
    });
  }

  Future<void> _arreter() async {
    if (fini) return;
    fini = true;
    minuterie?.cancel();
    final f = await widget.medias.arreterVocal();
    if (mounted) {
      Navigator.of(context)
          .pop(f == null ? null : (f, secondes == 0 ? 1 : secondes));
    }
  }

  @override
  void dispose() {
    minuterie?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      icon: const Icon(Icons.mic, color: NlColors.alert, size: 40),
      title: Text(l.recording),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            fmtSeconds(secondes),
            style: const TextStyle(
              fontFamily: kMonoFont,
              fontSize: 32,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(l.recordingHintReal),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            fini = true;
            minuterie?.cancel();
            await widget.medias.annulerVocal();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(l.cancel),
        ),
        TextButton(onPressed: _arreter, child: Text(l.stopAndSend)),
      ],
    );
  }
}

/// Ligne du journal tenu sur le téléphone ; les noms de lieux viennent du
/// serveur (RG-JRN-10) et se lisent sur la page Web de la navigation.
class EvenementTile extends StatelessWidget {
  const EvenementTile({super.key, required this.evenement, this.onTap});
  final EvenementLocal evenement;

  /// Note, photo, note vocale, incident ou avarie : actions du journal
  /// (RG-JRN-06).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final e = evenement;
    final (icone, titre) = switch (e.type) {
      'debut' => (Icons.flag_outlined, l.eventStart),
      'position_automatique' => (Icons.place_outlined, l.eventAutoPosition),
      'position_manuelle' => (Icons.place_outlined, l.eventManualPosition),
      'note' => (Icons.edit_note, l.eventNote),
      'photo' => (Icons.photo_outlined, l.eventPhoto),
      'note_vocale' => (Icons.mic_none, l.eventVoice),
      'incident' => (Icons.report_problem_outlined, l.eventIncident),
      'sos' => (Icons.sos, l.eventSos),
      'fin' => (Icons.sports_score, l.eventEnd),
      _ => (Icons.circle_outlined, e.type),
    };
    final p = e.position;
    final positionnable = const {
      'debut',
      'position_automatique',
      'position_manuelle',
      'sos',
      'fin',
    }.contains(e.type);
    final details = [
      if (e.texte != null && e.texte!.isNotEmpty) e.texte!,
      if (e.dureeSecondes != null) fmtSeconds(e.dureeSecondes!),
      if (p != null)
        '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}'
      else if (positionnable)
        l.gpsUnavailable,
    ];
    final sos = e.type == 'sos';
    // RG-JRN-11 : incident ou avarie mis en évidence, comme l'alerte SOS.
    final enEvidence = sos || e.type == 'incident';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      trailing: onTap == null ? null : const Icon(Icons.more_vert),
      leading: Icon(icone, color: enEvidence ? NlColors.alert : NlColors.teal),
      title: Text(
        '${fmtTime(e.heure)} · $titre',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: enEvidence ? NlColors.alert : null,
        ),
      ),
      subtitle: details.isEmpty ? null : Text(details.join('\n')),
    );
  }
}

/// Destination choisie sur une carte (RG-NAV-04) : un toucher place le point,
/// « Valider » le rend.
class DestinationCarteScreen extends StatefulWidget {
  const DestinationCarteScreen({super.key, this.initiale});
  final PositionGps? initiale;

  @override
  State<DestinationCarteScreen> createState() => _DestinationCarteScreenState();
}

class _DestinationCarteScreenState extends State<DestinationCarteScreen> {
  LatLng? point;

  @override
  void initState() {
    super.initState();
    final p = widget.initiale;
    if (p != null) point = LatLng(p.latitude, p.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = point;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.destinationOnMap),
        actions: [
          TextButton(
            key: const Key('destination-validate'),
            onPressed: p == null
                ? null
                : () => Navigator.of(context).pop(
                    PositionGps(
                      latitude: p.latitude,
                      longitude: p.longitude,
                      heureAcquisition: DateTime.now(),
                    ),
                  ),
            child: Text(l.validate),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(l.destinationMapHint),
          ),
          Expanded(
            child: FlutterMap(
              key: const Key('destination-map'),
              options: MapOptions(
                // Sans position connue : les côtes françaises.
                initialCenter: p ?? const LatLng(47.0, -2.5),
                initialZoom: p == null ? 6 : 11,
                backgroundColor: const Color(0xFFDCEFF8),
                onTap: (_, q) => setState(() => point = q),
              ),
              children: [
                if (SeaMap.tilesEnabled) ...[
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'fr.nautilink.nautilink',
                  ),
                  TileLayer(
                    urlTemplate:
                        'https://tiles.openseamap.org/seamark/{z}/{x}/{y}.png',
                    userAgentPackageName: 'fr.nautilink.nautilink',
                  ),
                ],
                if (p != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: p,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.place,
                          color: NlColors.alert,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (p != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l.destinationPoint(
                  '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}',
                ),
              ),
            ),
          const PiedDePage(),
        ],
      ),
    );
  }
}
