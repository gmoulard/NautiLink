import 'package:flutter/material.dart';

import '../data.dart';
import '../depot/depot.dart';
import '../l10n/app_localizations.dart';
import '../reel/api.dart';
import '../reel/depot_reel.dart';
import '../reel/identites.dart';
import '../theme.dart';
import 'pied.dart';
import 'warning.dart';

/// Message affiché pour une erreur d'appel au serveur : sans Internet, la
/// connexion et la création du compte sont impossibles (RG-COM-06) ; sinon
/// le message du serveur, dans la langue de l'utilisateur.
String messageErreur(AppLocalizations l, Object e) => switch (e) {
  HorsConnexion() => l.loginOffline,
  ErreurApi(message: final m) when m.isNotEmpty => m,
  _ => l.errorGeneric,
};

DepotReel _depot(BuildContext context) => DepotScope.of(context) as DepotReel;

/// « Hors connexion · données du … » (RG-COM-06), en pastille arrondie,
/// seulement hors connexion. Le bandeau « Version bêta » qui la portait est
/// remplacé par le lien du pied de page (D-178, RG-CPT-07).
class BandeauHorsConnexion extends StatelessWidget {
  const BandeauHorsConnexion({super.key});

  @override
  Widget build(BuildContext context) {
    final depot = DepotScope.of(context);
    if (!depot.horsConnexion) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final actualise = depot.actualiseLe;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  l.offlineSince(
                    actualise == null ? '—' : fmtDate(l, actualise),
                  ),
                  key: const Key('hors-connexion'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Écran de connexion (cahier des charges §5.1, RG-CPT-02, RG-CPT-12).
class ConnexionScreen extends StatefulWidget {
  const ConnexionScreen({super.key});

  @override
  State<ConnexionScreen> createState() => _ConnexionScreenState();
}

class _ConnexionScreenState extends State<ConnexionScreen> {
  static const identites = Identites();
  final _email = TextEditingController();
  final _mdp = TextEditingController();
  bool _occupe = false;
  bool _mdpVisible = false;
  String? _erreur;

  @override
  void dispose() {
    _email.dispose();
    _mdp.dispose();
    super.dispose();
  }

  Future<void> _seConnecter() async {
    final l = AppLocalizations.of(context);
    final depot = _depot(context);
    if (_email.text.trim().isEmpty || _mdp.text.isEmpty) {
      setState(() => _erreur = l.fieldRequired);
      return;
    }
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    try {
      try {
        await depot.connexion(_email.text, _mdp.text);
      } on ErreurApi catch (e) {
        if (e.statut != 428) rethrow;
        // Le texte de l'avertissement a changé : à relire et accepter (RG-CPT-07).
        final version = await depot.versionAvertissement();
        if (!mounted) return;
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const AccepterAvertissementScreen(),
          ),
        );
        if (ok != true) return;
        await depot.connexion(
          _email.text,
          _mdp.text,
          avertissementVersion: version,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(l, e));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  /// « Continuer avec Google » ou « Continuer avec Apple » : jeton
  /// d'identité vérifié par le serveur ; un premier compte demande
  /// l'acceptation de l'avertissement bêta (428, RG-CPT-06).
  Future<void> _seConnecterPar(String fournisseur) async {
    final l = AppLocalizations.of(context);
    final depot = _depot(context);
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    try {
      final jeton = fournisseur == 'google'
          ? await identites.jetonGoogle()
          : await identites.jetonApple();
      if (jeton == null) return; // abandon
      try {
        await depot.connexionFournisseur(fournisseur, jeton);
      } on ErreurApi catch (e) {
        if (e.statut != 428) rethrow;
        final version = await depot.versionAvertissement();
        if (!mounted) return;
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => const AccepterAvertissementScreen(),
          ),
        );
        if (ok != true) return;
        await depot.connexionFournisseur(
          fournisseur,
          jeton,
          avertissementVersion: version,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(l, e));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final depot = _depot(context);
    return Scaffold(
      body: RadarBackground(
        child: AutofillGroup(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // D-178 : bandeau photo du bateau et vague blanche, comme l'étude.
              const BandeauPhoto(),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l.loginTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Text(
                          l.loginSubtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        if (depot.sessionExpiree) ...[
                          Text(
                            l.sessionExpired,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextField(
                          key: const Key('login-email'),
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: InputDecoration(
                            labelText: l.email,
                            prefixIcon: const Icon(Icons.mail_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('login-password'),
                          controller: _mdp,
                          obscureText: !_mdpVisible,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: l.password,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              key: const Key('login-eye'),
                              tooltip: _mdpVisible
                                  ? l.hidePassword
                                  : l.showPassword,
                              icon: Icon(
                                _mdpVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _mdpVisible = !_mdpVisible),
                            ),
                          ),
                          onSubmitted: (_) => _seConnecter(),
                        ),
                        if (_erreur != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _erreur!,
                            key: const Key('login-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _occupe ? null : _seConnecter,
                          child: _occupe
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(l.loginButton),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    MotDePasseOublieScreen(email: _email.text),
                              ),
                            ),
                            child: Text(l.forgotPassword),
                          ),
                        ),
                        const Divider(height: 32),
                        // Connexion par Google et Apple (RG-CPT-02, RG-CPT-11) : active
                        // avec les identifiants clients donnés à la construction
                        // (app/README.md) ; Apple sur iPhone seulement.
                        OutlinedButton.icon(
                          key: const Key('login-google'),
                          onPressed: _occupe || !identites.google
                              ? null
                              : () => _seConnecterPar('google'),
                          icon: const Icon(Icons.account_circle_outlined),
                          label: Text(l.continueGoogle),
                        ),
                        if (identites.apple || !identites.google) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            key: const Key('login-apple'),
                            onPressed: _occupe || !identites.apple
                                ? null
                                : () => _seConnecterPar('apple'),
                            icon: const Icon(Icons.apple),
                            label: Text(l.continueApple),
                          ),
                        ],
                        if (!identites.google && !identites.apple) ...[
                          const SizedBox(height: 4),
                          Text(
                            l.providerUnavailable,
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const Divider(height: 32),
                        OutlinedButton(
                          onPressed: _occupe
                              ? null
                              : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const CreationCompteScreen(),
                                  ),
                                ),
                          child: Text(l.createAccount),
                        ),
                        // Sponsor intégré à la page, après les boutons (Q-102).
                        const SizedBox(height: 24),
                        const SponsorFooter(),
                        const PiedDePage(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Création du compte sur l'application mobile, avec l'avertissement bêta
/// lu et accepté en cochant une case (RG-CPT-06).
class CreationCompteScreen extends StatefulWidget {
  const CreationCompteScreen({super.key});

  @override
  State<CreationCompteScreen> createState() => _CreationCompteScreenState();
}

class _CreationCompteScreenState extends State<CreationCompteScreen> {
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _mdp = TextEditingController();
  bool _accepte = false;
  bool _occupe = false;
  String? _erreur;

  @override
  void dispose() {
    _nom.dispose();
    _email.dispose();
    _mdp.dispose();
    super.dispose();
  }

  Future<void> _creer() async {
    final l = AppLocalizations.of(context);
    final depot = _depot(context);
    final langue = Localizations.localeOf(context).languageCode == 'en'
        ? 'en'
        : 'fr';
    if (_nom.text.trim().isEmpty || _email.text.trim().isEmpty) {
      setState(() => _erreur = l.fieldRequired);
      return;
    }
    if (_mdp.text.length < 8) {
      setState(() => _erreur = l.passwordMin);
      return;
    }
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    try {
      final version = await depot.versionAvertissement();
      await depot.creerCompte(
        nom: _nom.text,
        email: _email.text,
        motDePasse: _mdp.text,
        avertissementVersion: version,
        langue: langue,
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(l, e));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.createAccountTitle)),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    TextField(
                      key: const Key('account-name'),
                      controller: _nom,
                      decoration: InputDecoration(
                        labelText: l.name,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('account-email'),
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l.email,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('account-password'),
                      controller: _mdp,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: l.password,
                        helperText: l.passwordMin,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const WarningText(),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _accepte,
                      onChanged: (v) => setState(() => _accepte = v ?? false),
                      title: Text(l.warningAccept),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (_erreur != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _erreur!,
                        key: const Key('account-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    FilledButton(
                      // Le compte n'est pas créé sans l'acceptation (RG-CPT-06).
                      onPressed: _accepte && !_occupe ? _creer : null,
                      child: Text(l.createAccountButton),
                    ),
                    const PiedDePage(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nouvelle version de l'avertissement à accepter avant de continuer (RG-CPT-07).
class AccepterAvertissementScreen extends StatefulWidget {
  const AccepterAvertissementScreen({super.key});

  @override
  State<AccepterAvertissementScreen> createState() =>
      _AccepterAvertissementScreenState();
}

class _AccepterAvertissementScreenState
    extends State<AccepterAvertissementScreen> {
  bool _accepte = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.warningTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l.warningNewVersion,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          const WarningText(),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _accepte,
            onChanged: (v) => setState(() => _accepte = v ?? false),
            title: Text(l.warningAccept),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          FilledButton(
            onPressed: _accepte ? () => Navigator.of(context).pop(true) : null,
            child: Text(l.continueLabel),
          ),
          const PiedDePage(),
        ],
      ),
    );
  }
}

/// « Mot de passe oublié ? » (RG-CPT-10) : le serveur envoie un lien valable
/// 1 heure ; le nouveau mot de passe se choisit sur la page Web du lien.
class MotDePasseOublieScreen extends StatefulWidget {
  const MotDePasseOublieScreen({super.key, this.email = ''});
  final String email;

  @override
  State<MotDePasseOublieScreen> createState() => _MotDePasseOublieScreenState();
}

class _MotDePasseOublieScreenState extends State<MotDePasseOublieScreen> {
  late final _email = TextEditingController(text: widget.email);
  bool _occupe = false;
  bool _envoye = false;
  String? _erreur;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _envoyer() async {
    final l = AppLocalizations.of(context);
    if (_email.text.trim().isEmpty) {
      setState(() => _erreur = l.fieldRequired);
      return;
    }
    setState(() {
      _occupe = true;
      _erreur = null;
    });
    try {
      await _depot(context).motDePasseOublie(_email.text);
      if (mounted) setState(() => _envoye = true);
    } catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(l, e));
    } finally {
      if (mounted) setState(() => _occupe = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.forgotTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(l.forgotText),
          const SizedBox(height: 16),
          TextField(
            key: const Key('forgot-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: l.email,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_erreur != null) ...[
            const SizedBox(height: 12),
            Text(
              _erreur!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_envoye) ...[
            const SizedBox(height: 12),
            Text(l.forgotSent, key: const Key('forgot-sent')),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _occupe ? null : _envoyer,
            child: Text(l.forgotSend),
          ),
          const PiedDePage(),
        ],
      ),
    );
  }
}
