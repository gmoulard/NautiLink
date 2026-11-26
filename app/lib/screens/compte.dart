import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../depot/depot.dart';
import '../l10n/app_localizations.dart';
import '../reel/depot_reel.dart';
import '../reel/sms_navigation.dart';
import '../theme.dart';
import 'connexion.dart';
import 'memo.dart';
import 'warning.dart';

/// Écrans « Autres écrans » de l'application mobile (cahier des charges §5.5) :
/// contacts, paramètres généraux, historique des alertes SOS, assistance.
/// Les mêmes écrans servent à la démonstration (données d'exemple, rien
/// n'est envoyé) et à la vraie application (serveur, copie locale), par le
/// [Depot] ; ce qui n'existe que dans la vraie application (ajout, fiche du
/// contact, invitations, accès) n'est pas montré dans la démonstration.

/// Plateforme de la vraie application (`android`, `ios`, vide sur le Web).
String? _plateforme(Depot depot) =>
    depot is DepotReel ? depot.plateforme : null;

void _message(BuildContext context, String texte) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));

Future<bool> _confirmer(BuildContext context, String texte) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(texte),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l.ok),
        ),
      ],
    ),
  );
  return ok == true;
}

String etatInvitationLabel(AppLocalizations l, String etat) => switch (etat) {
  'envoyee' => l.invitationSent,
  'acceptee' => l.invitationAccepted,
  'annulee' => l.invitationCancelled,
  _ => l.invitationNone,
};

// ======================================================================
// Contacts
// ======================================================================

/// Contacts : une seule liste, cases « Suiveur » et « Contact SOS »
/// (RG-CTC-01, RG-CTC-05) ; dans la vraie application, ajout, fiche du
/// contact, invitations et accès (RG-CTC-02, RG-CTC-04, RG-PAR-02 à RG-PAR-06),
/// copie locale utilisable hors connexion (RG-CTC-03, RG-COM-06).
class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.of(context);
    final l = AppLocalizations.of(context);
    final demo = depot.demonstration;
    final refus = depot is DepotReel ? depot.compte.dernierRefus : null;
    final liste = ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (!demo && depot.horsConnexion)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l.contactsOffline,
              key: const Key('contacts-offline'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        if (refus != null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(l.contactRefused(refus)),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                tooltip: l.ok,
                onPressed: () {
                  (depot as DepotReel).compte.dernierRefus = null;
                  depot.actualiser();
                },
              ),
            ),
          ),
        Text(l.contactsDefault),
        const SizedBox(height: 12),
        for (final c in depot.contacts) _CarteContact(contact: c),
        if (!demo) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('contact-add'),
            icon: const Icon(Icons.person_add_alt),
            label: Text(l.contactAdd),
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ContactScreen())),
          ),
        ],
      ],
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.menuContacts)),
      body: demo
          ? liste
          : RefreshIndicator(onRefresh: depot.actualiser, child: liste),
    );
  }
}

class _CarteContact extends StatelessWidget {
  const _CarteContact({required this.contact});
  final ContactNl contact;

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.of(context);
    final l = AppLocalizations.of(context);
    final c = contact;
    final demo = depot.demonstration;
    final entete = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(c.nom, style: const TextStyle(fontWeight: FontWeight.w700)),
        Text([c.telephone, c.email].whereType<String>().join(' · ')),
        if (!demo && c.suiveur)
          Text(
            etatInvitationLabel(l, c.etatInvitation),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (c.enAttente)
          Text(
            l.contactPending,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (demo)
              entete
            else
              InkWell(
                key: Key('contact-${c.id}'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ContactScreen(contactId: c.id),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(child: entete),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l.roleFollower),
                    value: c.suiveur,
                    onChanged: (v) => changerSuiveur(context, c, v ?? false),
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l.roleSos),
                    subtitle: c.telephone == null
                        ? Text(l.phoneRequired)
                        : null,
                    value: c.contactSos,
                    // RG-CTC-05 : « Contact SOS » demande un numéro.
                    onChanged: c.telephone == null
                        ? null
                        : (v) => depot.modifierContact(c.id, {
                            'contactSos': v ?? false,
                          }),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Case « Suiveur » : la cocher envoie une invitation avec le périmètre
/// choisi, refusée tant que l'adresse n'est pas confirmée ; la décocher
/// retire le suiveur de toutes les navigations (RG-CTC-04, RG-CPT-09, RG-PAR-06).
Future<void> changerSuiveur(
  BuildContext context,
  ContactNl c,
  bool suiveur,
) async {
  final depot = DepotScope.of(context);
  final l = AppLocalizations.of(context);
  if (depot.demonstration) {
    await depot.modifierContact(c.id, {'suiveur': suiveur});
    return;
  }
  if (!suiveur) {
    if (c.etatInvitation == 'acceptee' &&
        !await _confirmer(context, l.followerRemoveConfirm(c.nom))) {
      return;
    }
    await depot.modifierContact(c.id, {'suiveur': false});
    return;
  }
  if (depot.profil?.emailVerifie == false) {
    _message(context, l.followerNeedsVerifiedEmail);
    return;
  }
  final p = await choisirPerimetre(context);
  if (p == null) return;
  await depot.modifierContact(c.id, {
    'suiveur': true,
    'perimetre': p.perimetre,
    'navigationId': p.navigationId,
  });
}

typedef Perimetre = ({String perimetre, String? navigationId});

/// Choix du périmètre de l'accès : *navigateur* (toutes les navigations,
/// historique compris) ou *navigation* (une seule) (RG-PAR-02, RG-PAR-09).
Future<Perimetre?> choisirPerimetre(BuildContext context, {Perimetre? actuel}) {
  return showDialog<Perimetre>(
    context: context,
    builder: (ctx) => _DialoguePerimetre(actuel: actuel),
  );
}

class _DialoguePerimetre extends StatefulWidget {
  const _DialoguePerimetre({this.actuel});
  final Perimetre? actuel;

  @override
  State<_DialoguePerimetre> createState() => _DialoguePerimetreState();
}

class _DialoguePerimetreState extends State<_DialoguePerimetre> {
  late String perimetre = widget.actuel?.perimetre ?? 'navigateur';
  late String? navigationId = widget.actuel?.navigationId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final navigations = DepotScope.of(context).navigations
        .where((n) => !n.commeSuiveur)
        .toList();
    if (navigationId == null && navigations.isNotEmpty) {
      navigationId = navigations.first.id;
    }
    return AlertDialog(
      title: Text(l.scopeTitle),
      content: RadioGroup<String>(
        groupValue: perimetre,
        onChanged: (v) => setState(() => perimetre = v ?? perimetre),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              key: const Key('scope-navigateur'),
              value: 'navigateur',
              title: Text(l.scopeNavigator),
            ),
            RadioListTile<String>(
              key: const Key('scope-navigation'),
              value: 'navigation',
              title: Text(l.scopeVoyage),
              enabled: navigations.isNotEmpty,
              subtitle: navigations.isEmpty ? Text(l.scopeNoVoyage) : null,
            ),
            if (perimetre == 'navigation' && navigations.isNotEmpty)
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: navigationId,
                decoration: InputDecoration(labelText: l.scopeChooseVoyage),
                items: [
                  for (final n in navigations)
                    DropdownMenuItem(
                      value: n.id,
                      child: Text(n.nom, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => navigationId = v),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const Key('scope-ok'),
          onPressed: () => Navigator.pop(context, (
            perimetre: perimetre,
            navigationId: perimetre == 'navigation' ? navigationId : null,
          )),
          child: Text(l.ok),
        ),
      ],
    );
  }
}

/// Fiche d'un contact de la vraie application : ajout ([contactId] vide) ou
/// modification, cases, invitation, périmètre, retrait et suppression
/// (RG-CTC-01 à RG-CTC-05, RG-PAR-02 à RG-PAR-06).
class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key, this.contactId});
  final String? contactId;

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _nom = TextEditingController();
  final _tel = TextEditingController();
  final _email = TextEditingController();
  bool _suiveur = true;
  bool _sos = true;
  bool _rempli = false;
  String? _erreur;
  bool _occupe = false;

  /// Invitations et accès du contact, lus sur le serveur (Internet requis).
  List<InvitationNl>? _invitations;
  List<AccesNl>? _acces;
  String? _erreurEnLigne;

  /// Dernière invitation par téléphone : son lien est affiché (RG-PAR-04).
  InvitationNl? _lien;

  DepotReel get _depot => DepotScope.of(context) as DepotReel;

  ContactNl? get _contact {
    for (final c in _depot.contacts) {
      if (c.id == widget.contactId) return c;
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rempli) return;
    _rempli = true;
    final c = _contact;
    if (c != null) {
      _nom.text = c.nom;
      _tel.text = c.telephone ?? '';
      _email.text = c.email ?? '';
      _suiveur = c.suiveur;
      _sos = c.contactSos;
      _lireEnLigne();
    } else {
      // Adresse non confirmée : pas d'invitation, un contact SOS reste permis (RG-CPT-09).
      _suiveur = _depot.profil?.emailVerifie != false;
    }
  }

  @override
  void dispose() {
    _nom.dispose();
    _tel.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _lireEnLigne() async {
    final l = AppLocalizations.of(context);
    try {
      final i = await _depot.compte.invitations();
      final a = await _depot.compte.accesDonnes();
      if (!mounted) return;
      setState(() {
        _invitations = i;
        _acces = a;
        _erreurEnLigne = null;
      });
    } catch (e) {
      if (mounted) setState(() => _erreurEnLigne = messageErreur(l, e));
    }
  }

  String? _texte(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _enregistrer() async {
    final l = AppLocalizations.of(context);
    final tel = _texte(_tel), email = _texte(_email);
    if (tel == null && email == null) {
      setState(() => _erreur = l.contactPhoneOrEmail);
      return;
    }
    final c = _contact;
    if (c == null) {
      Perimetre? p;
      if (_suiveur) {
        p = await choisirPerimetre(context);
        if (p == null) return;
      }
      await _depot.compte.ajouterContact(
        nom: _nom.text,
        telephone: tel,
        email: email,
        suiveur: _suiveur,
        contactSos: _sos && tel != null,
        perimetre: p?.perimetre,
        navigationId: p?.navigationId,
      );
    } else {
      // Seuls les champs changés partent (RG-COM-04).
      final champs = <String, Object?>{
        if (_nom.text.trim() != c.nom) 'nom': _nom.text.trim(),
        if (tel != c.telephone) 'telephone': tel,
        if (email != c.email) 'email': email,
      };
      if (champs.isNotEmpty) await _depot.modifierContact(c.id, champs);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _enLigne(Future<void> Function() action) async {
    final l = AppLocalizations.of(context);
    setState(() => _occupe = true);
    try {
      await action();
      await _lireEnLigne();
    } catch (e) {
      if (mounted) _message(context, messageErreur(l, e));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  Future<void> _inviter(ContactNl c, String canal, {Perimetre? p}) async {
    final l = AppLocalizations.of(context);
    if (_depot.horsConnexion && canal == 'telephone') {
      _message(context, l.smsInviteOffline);
      return;
    }
    final perimetre =
        p ??
        (c.perimetre == null
            ? await choisirPerimetre(context)
            : (perimetre: c.perimetre!, navigationId: c.navigationId));
    if (perimetre == null) return;
    await _enLigne(() async {
      final i = await _depot.compte.inviter(
        contactId: c.id,
        canal: canal,
        perimetre: perimetre.perimetre,
        navigationId: perimetre.navigationId,
      );
      if (!mounted) return;
      if (canal == 'email') {
        _message(context, l.invitationEmailSent(i.email ?? c.email ?? ''));
      } else {
        setState(() => _lien = i);
      }
    });
  }

  Future<void> _changerPerimetre(ContactNl c, InvitationNl? attente) async {
    final p = await choisirPerimetre(
      context,
      actuel: c.perimetre == null
          ? null
          : (perimetre: c.perimetre!, navigationId: c.navigationId),
    );
    if (p == null || !mounted) return;
    final acces = _accesDe(c);
    if (acces != null) {
      await _enLigne(
        () => _depot.compte.changerPerimetre(
          acces.id,
          p.perimetre,
          navigationId: p.navigationId,
        ),
      );
    } else {
      // Invitation pas encore acceptée : une nouvelle invitation, même canal,
      // remplace celle en attente.
      await _inviter(
        c,
        attente?.canal ?? (c.email != null ? 'email' : 'telephone'),
        p: p,
      );
    }
  }

  AccesNl? _accesDe(ContactNl c) {
    for (final a in _acces ?? const <AccesNl>[]) {
      if (c.utilisateurId != null && a.suiveurId == c.utilisateurId) return a;
    }
    return null;
  }

  /// Invitation par téléphone : SMS envoyé automatiquement sur Android avec
  /// la permission d'envoi de SMS, sinon prérempli (D-146), avec la copie au
  /// navigateur (RG-SMS-08) ; lien affiché sur iPhone (RG-PAR-04, RG-IOS-02,
  /// D-137).
  Future<void> _envoyerSms(ContactNl c, InvitationNl i) async {
    final l = AppLocalizations.of(context);
    final nom = _depot.profil?.nom ?? '';
    final texte =
        '$nom vous invite à suivre ses navigations sur NautiLink : ${i.lien}';
    final numero = i.telephone ?? c.telephone;
    if (numero == null) return;
    final (issue, _) = await _depot.sms.invitation(
      i.id,
      numero,
      texte,
      contactId: c.id,
    );
    if (issue == IssueSms.automatique && mounted) {
      _message(context, l.inviteSmsSent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = _contact;
    final nouveau = widget.contactId == null;
    final verifie = _depot.profil?.emailVerifie != false;
    return Scaffold(
      appBar: AppBar(title: Text(nouveau ? l.contactAdd : (c?.nom ?? ''))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: const Key('contact-name'),
            controller: _nom,
            decoration: InputDecoration(
              labelText: l.contactName,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('contact-phone'),
            controller: _tel,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l.contactPhone,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('contact-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l.contactEmail,
              border: const OutlineInputBorder(),
            ),
          ),
          if (nouveau) ...[
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l.roleFollower),
              subtitle: verifie ? null : Text(l.followerNeedsVerifiedEmail),
              value: _suiveur && verifie,
              onChanged: verifie
                  ? (v) => setState(() => _suiveur = v ?? false)
                  : null,
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(l.roleSos),
              subtitle: _texte(_tel) == null ? Text(l.phoneRequired) : null,
              value: _sos && _texte(_tel) != null,
              onChanged: _texte(_tel) == null
                  ? null
                  : (v) => setState(() => _sos = v ?? false),
            ),
          ],
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _erreur!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('contact-save'),
            onPressed: _enregistrer,
            child: Text(l.contactSave),
          ),
          if (c != null) ...[
            const SizedBox(height: 16),
            _CarteContact(contact: c),
            if (c.suiveur) _invitationEtAcces(l, c),
            const SizedBox(height: 16),
            TextButton.icon(
              key: const Key('contact-delete'),
              icon: const Icon(Icons.delete_outline),
              label: Text(l.contactDelete),
              onPressed: () async {
                if (!await _confirmer(context, l.contactDeleteConfirm(c.nom))) {
                  return;
                }
                await _depot.compte.supprimerContact(c.id);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _invitationEtAcces(AppLocalizations l, ContactNl c) {
    InvitationNl? attente;
    for (final i in _invitations ?? const <InvitationNl>[]) {
      if (i.contactId == c.id && i.etat == 'envoyee') {
        attente = i;
        break;
      }
    }
    final acces = _accesDe(c);
    final ios = _plateforme(_depot) != 'android';
    final navigation = c.navigationId == null
        ? null
        : _depot.navigations.where((n) => n.id == c.navigationId).firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              etatInvitationLabel(l, c.etatInvitation),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (c.perimetre != null)
              Text(
                '${l.scopeTitle} : ${c.perimetre == 'navigation' ? '${l.scopeVoyage}${navigation == null ? '' : ' (${navigation.nom})'}' : l.scopeNavigator}',
              ),
            if (_erreurEnLigne != null)
              Text(
                _erreurEnLigne!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_occupe) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            if (c.etatInvitation != 'acceptee') ...[
              if (c.email != null)
                OutlinedButton(
                  key: const Key('invite-email'),
                  onPressed: _occupe ? null : () => _inviter(c, 'email'),
                  child: Text(l.inviteByEmail),
                ),
              if (c.telephone != null)
                OutlinedButton(
                  key: const Key('invite-phone'),
                  onPressed: _occupe ? null : () => _inviter(c, 'telephone'),
                  child: Text(l.inviteByPhone),
                ),
            ],
            if (_lien != null) ...[
              const SizedBox(height: 8),
              Text(
                l.invitationLink,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              SelectableText(_lien!.lien, key: const Key('invitation-link')),
              Text(
                ios ? l.iphoneNoSmsInvite : l.invitationLinkHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (!ios)
                    FilledButton.icon(
                      key: const Key('invitation-sms'),
                      icon: const Icon(Icons.sms_outlined),
                      label: Text(l.invitationSendSms),
                      onPressed: () => _envoyerSms(c, _lien!),
                    ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy),
                    label: Text(l.invitationCopyLink),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: _lien!.lien));
                      if (mounted) _message(context, l.linkCopied);
                    },
                  ),
                ],
              ),
            ],
            if (attente != null)
              TextButton(
                key: const Key('invitation-cancel'),
                onPressed: _occupe
                    ? null
                    : () => _enLigne(
                        () => _depot.compte.annulerInvitation(attente!.id),
                      ),
                child: Text(l.invitationCancel),
              ),
            if (c.etatInvitation == 'acceptee' || attente != null)
              TextButton(
                key: const Key('scope-change'),
                onPressed: _occupe ? null : () => _changerPerimetre(c, attente),
                child: Text(l.scopeChange),
              ),
            if (acces != null)
              TextButton(
                key: const Key('follower-remove'),
                onPressed: _occupe
                    ? null
                    : () async {
                        if (!await _confirmer(
                          context,
                          l.followerRemoveConfirm(c.nom),
                        )) {
                          return;
                        }
                        await _enLigne(
                          () => _depot.compte.retirerAcces(acces.id),
                        );
                      },
                child: Text(l.followerRemove),
              ),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// Paramètres généraux
// ======================================================================

/// Types de SMS ordinaires, dans l'ordre de RG-SMS-02, avec leur clé de
/// `smsParType` (schéma `Parametres`).
const typesSms = [
  (SmsType.start, 'debut'),
  (SmsType.autoPosition, 'positionsAutomatiques'),
  (SmsType.manualPosition, 'positionsManuelles'),
  (SmsType.note, 'notes'),
  (SmsType.photo, 'photos'),
  (SmsType.voice, 'notesVocales'),
  (SmsType.end, 'fin'),
];

/// Paramètres généraux (RG-PRM-01, RG-PRM-02, RG-SMS-02), modifiés champ par
/// champ (RG-COM-04) ; synchronisés avec le Web dans la vraie application.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.of(context);
    final l = AppLocalizations.of(context);
    final demo = depot.demonstration;
    // Valeurs d'un nouveau compte tant que rien n'est reçu (RG-PRM-06).
    final p = depot.parametres ?? ParametresGeneraux.depuisJson(const {})!;
    final frequence = frequencies.contains(p.frequenceParDefaut)
        ? p.frequenceParDefaut
        : 30;
    return Scaffold(
      appBar: AppBar(title: Text(l.menuSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!demo) ...[
            Text(
              l.settingsSynced,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
          ],
          // RG-PRM-03 : langue du téléphone par défaut, ou choisie.
          if (depot is DepotReel) ...[
            DropdownButtonFormField<String>(
              key: const Key('settings-language'),
              isExpanded: true,
              initialValue: depot.langueChoisie ?? '',
              decoration: InputDecoration(
                labelText: l.settingsLanguage,
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: '', child: Text(l.languagePhone)),
                DropdownMenuItem(value: 'fr', child: Text(l.languageFrench)),
                DropdownMenuItem(value: 'en', child: Text(l.languageEnglish)),
              ],
              onChanged: (v) {
                final choix = v == null || v.isEmpty ? null : v;
                final telephone = WidgetsBinding
                    .instance
                    .platformDispatcher
                    .locale
                    .languageCode;
                depot.choisirLangue(
                  choix,
                  effective: choix ?? (telephone == 'en' ? 'en' : 'fr'),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          DropdownButtonFormField<int>(
            key: ValueKey('frequence-$frequence'),
            isExpanded: true,
            initialValue: frequence,
            decoration: InputDecoration(
              labelText: l.defaultFrequency,
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final f in frequencies)
                DropdownMenuItem(value: f, child: Text(frequencyLabel(l, f))),
            ],
            onChanged: (v) {
              if (v == null) return;
              depot.modifierParametres({'frequenceParDefaut': v});
            },
          ),
          const SizedBox(height: 16),
          // iPhone : réglages gardés pour les navigations menées depuis un
          // téléphone Android, sans effet sur l'iPhone (RG-IOS-02, D-137).
          if (!demo && _plateforme(depot) == 'ios')
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(l.settingsIphone, key: const Key('settings-iphone')),
            ),
          SwitchListTile(
            title: Text(
              l.smsEnabled,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            value: p.smsActifs,
            onChanged: (v) => depot.modifierParametres({'smsActifs': v}),
          ),
          for (final (type, cle) in typesSms)
            SwitchListTile(
              title: Text(smsTypeLabel(l, type)),
              value: p.smsParType[cle] ?? true,
              onChanged: p.smsActifs
                  ? (v) => depot.modifierParametres({
                      'smsParType': {cle: v},
                    })
                  : null,
            ),
          if (!demo)
            SwitchListTile(
              key: const Key('photo-mms'),
              title: Text(l.photoAsMms),
              value: p.photoEnMms,
              onChanged: p.smsActifs
                  ? (v) => depot.modifierParametres({'photoEnMms': v})
                  : null,
            ),
          const SizedBox(height: 8),
          Text(l.sosAlwaysSent),
          // RG-IOS-06, RG-AND-08 : notifications push par type, sauf le SOS.
          if (depot is DepotReel && depot.notifications != null) ...[
            const Divider(height: 32),
            Text(l.pushTitle, style: Theme.of(context).textTheme.titleMedium),
            for (final (cle, titre) in [
              ('debut', l.pushStart),
              ('fin', l.pushEnd),
              ('photo', l.pushPhoto),
              ('positionEnRetard', l.pushLate),
            ])
              SwitchListTile(
                key: Key('push-$cle'),
                title: Text(titre),
                value: depot.profil?.push[cle] ?? true,
                onChanged: (v) => depot.modifierPush({cle: v}),
              ),
            Text(l.pushSosAlways),
          ],
        ],
      ),
    );
  }
}

// ======================================================================
// Historique des alertes SOS
// ======================================================================

/// Historique des alertes SOS des bateaux du compte (RG-SOS-13) : date,
/// position transmise, statut des SMS par contact, e-mails (RG-SOS-12) ;
/// hors connexion, alertes du téléphone et dernier historique reçu (RG-COM-06).
class SosHistoryScreen extends StatefulWidget {
  const SosHistoryScreen({super.key});

  @override
  State<SosHistoryScreen> createState() => _SosHistoryScreenState();
}

class _SosHistoryScreenState extends State<SosHistoryScreen> {
  List<AlerteSosResume> _enAttente = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _lireEnAttente();
  }

  Future<void> _lireEnAttente() async {
    final depot = DepotScope.of(context);
    if (depot is! DepotReel) return;
    final l = await depot.compte.alertesEnAttente();
    if (mounted) setState(() => _enAttente = l);
  }

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.of(context);
    final l = AppLocalizations.of(context);
    final recues = {for (final a in depot.alertes) a.id};
    final alertes = [
      ..._enAttente.where((a) => !recues.contains(a.id)),
      ...depot.alertes,
    ]..sort((a, b) => b.heureDeclenchement.compareTo(a.heureDeclenchement));
    final bateaux = {for (final b in depot.bateaux) b.id: b.nom};
    final contacts = {for (final c in depot.contacts) c.id: c.nom};
    final actualise = depot.actualiseLe;
    return Scaffold(
      appBar: AppBar(title: Text(l.menuSosHistory)),
      body: RefreshIndicator(
        onRefresh: () async {
          await depot.actualiser();
          await _lireEnAttente();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (depot.horsConnexion)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l.sosHistoryOffline(
                    actualise == null ? '—' : fmtDate(l, actualise),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            if (alertes.isEmpty) Text(l.sosHistoryEmpty),
            for (final a in alertes)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.sosAlertTitle(fmtDate(l, a.heureDeclenchement)),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      Text(
                        [
                          bateaux[a.bateauId],
                          _position(l, a),
                        ].whereType<String>().join(' · '),
                      ),
                      if (a.problemeRencontre != null)
                        Text(l.sosHistoryProblem(a.problemeRencontre!)),
                      for (final s in a.sms)
                        Text(
                          '${s.statut == 'echec' ? '✗' : '✓'} '
                          '${contacts[s.contactId] ?? s.telephone} · '
                          '${_statutSms(l, s.statut)}',
                        ),
                      if (a.emailsEnvoyesA.isNotEmpty)
                        Text(
                          '✓ ${l.sosEmailsSent('${a.emailsEnvoyesA.length}')}',
                        ),
                      if (a.enAttente)
                        Text(
                          l.sosAlertPending,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _position(AppLocalizations l, AlerteSosResume a) {
    final p = a.position;
    return switch (a.naturePosition) {
      'aucune' => l.sosPositionNone,
      _ when p == null => l.sosPositionNone,
      'derniere_connue' =>
        '${l.sosPositionLast} : ${Position(p.latitude, p.longitude, p.heureAcquisition).text}',
      _ => Position(p.latitude, p.longitude, p.heureAcquisition).text,
    };
  }

  String _statutSms(AppLocalizations l, String s) => switch (s) {
    'accepte_pour_envoi' => l.sosHistorySmsAccepted,
    'livraison_confirmee' => l.sosSmsDelivered,
    'echec' => l.sosSmsFailed,
    _ => l.sosSmsPending,
  };
}

// ======================================================================
// Assistance
// ======================================================================

/// Page de suivi du projet, en attendant l'adresse e-mail de l'équipe (D-138).
const assistanceUrl = '$repositoryUrl/issues';

/// Assistance : contact de l'équipe NautiLink (D-138), avertissement bêta
/// consultable à tout moment, texte inclus dans l'application (RG-CPT-07),
/// mémo sécurité en mer (RG-SOS-22) ; hors connexion, contact impossible
/// (RG-COM-06).
class AssistanceScreen extends StatelessWidget {
  const AssistanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.of(context);
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.menuAssistance)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.betaBanner, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              key: const Key('assistance-write'),
              leading: const Icon(Icons.mail_outline),
              title: Text(l.assistanceWrite),
              subtitle: Text(l.assistanceWriteHint),
              trailing: const Icon(Icons.open_in_new),
              onTap: () {
                if (depot.horsConnexion) {
                  _message(context, l.assistanceOffline);
                  return;
                }
                launchUrl(
                  Uri.parse(assistanceUrl),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ),
          Card(
            child: ListTile(
              key: const Key('assistance-warning'),
              leading: const Icon(Icons.info_outline),
              title: Text(l.assistanceWarning),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text(l.assistanceWarning)),
                    body: const SingleChildScrollView(
                      padding: EdgeInsets.all(20),
                      child: WarningText(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.health_and_safety_outlined),
              title: Text(l.homeSecurityMemo),
              subtitle: Text(l.assistanceMemoHint),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openSecurityMemo(context),
            ),
          ),
        ],
      ),
    );
  }
}
