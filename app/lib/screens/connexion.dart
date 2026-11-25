import 'package:flutter/material.dart';

import '../depot/depot.dart';
import '../l10n/app_localizations.dart';
import '../reel/api.dart';
import '../reel/depot_reel.dart';
import '../theme.dart';
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

/// Mention « Version bêta », visible tant que dure la bêta (RG-CPT-07).
class BetaBanner extends StatelessWidget {
  const BetaBanner({super.key, this.detail});
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      color: NlColors.beta,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        detail == null ? l.betaBanner : '${l.betaBanner} · $detail',
        style: const TextStyle(
          color: Color(0xFF3A2A00),
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        textAlign: TextAlign.center,
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
  final _email = TextEditingController();
  final _mdp = TextEditingController();
  bool _occupe = false;
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final depot = _depot(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.loginTitle)),
      body: Column(
        children: [
          const BetaBanner(),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AutofillGroup(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
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
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        key: const Key('login-password'),
                        controller: _mdp,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: l.password,
                          border: const OutlineInputBorder(),
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
                      // Connexion par Google et Apple (RG-CPT-02, RG-CPT-11) : désactivée tant que
                      // les identifiants clients ne sont pas configurés (app/README.md).
                      OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.account_circle_outlined),
                        label: Text(l.continueGoogle),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.apple),
                        label: Text(l.continueApple),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l.providerUnavailable,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const Divider(height: 32),
                      OutlinedButton(
                        onPressed: _occupe
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CreationCompteScreen(),
                                ),
                              ),
                        child: Text(l.createAccount),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SponsorFooter(),
        ],
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
          const BetaBanner(),
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
        ],
      ),
    );
  }
}
