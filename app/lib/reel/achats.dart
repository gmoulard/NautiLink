import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'api.dart';

/// Issue d'un achat de l'abonnement (RG-ECO-11).
enum ResultatAchat {
  /// Abonnement ouvert par le serveur (RG-ECO-07).
  ouvert,

  /// Achat abandonné par le navigateur.
  annule,

  /// Paiement non confirmé : l'abonnement n'est pas ouvert.
  refuse,

  /// Achat pas encore ouvert (produit absent du magasin, serveur sans
  /// identifiants).
  indisponible,

  /// Paiement fait, mais le serveur n'a pas pu être joint : l'achat est
  /// présenté de nouveau au prochain lancement.
  enAttente,
}

/// Achat unique de 10 ans par Google Play (Android) ou par l'App Store
/// (iPhone, RG-IOS-07), vérifié par le serveur avant d'ouvrir l'abonnement
/// (`POST /v1/abonnement/google-play`, `POST /v1/abonnement/app-store`).
/// Sur iPhone, StoreKit 2 (par défaut) rend la transaction signée (JWS)
/// attendue par le serveur.
abstract class AchatsAbonnement {
  /// Prix affiché par le magasin, si le produit est connu.
  Future<String?> prix();

  Future<ResultatAchat> acheter();

  /// Appelé après un abonnement ouvert, pour relire le quota.
  set surOuvert(void Function()? f);
}

class AchatsMagasin implements AchatsAbonnement {
  AchatsMagasin({required this.api, required this.produit, required this.ios}) {
    _abonnement = _iap.purchaseStream.listen((achats) {
      for (final a in achats) {
        unawaited(_traiter(a));
      }
    }, onError: (Object e) => debugPrint('Achats : $e'));
  }

  final ClientApi api;
  final String produit;
  final bool ios;
  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _abonnement;
  Completer<ResultatAchat>? _enCours;
  void Function()? _surOuvert;

  @override
  set surOuvert(void Function()? f) => _surOuvert = f;

  Future<ProductDetails?> _produit() async {
    if (!await _iap.isAvailable()) return null;
    final r = await _iap.queryProductDetails({produit});
    return r.productDetails.where((p) => p.id == produit).firstOrNull;
  }

  @override
  Future<String?> prix() async {
    try {
      return (await _produit())?.price;
    } catch (e) {
      debugPrint('Prix : $e');
      return null;
    }
  }

  @override
  Future<ResultatAchat> acheter() async {
    final p = await _produit();
    if (p == null) return ResultatAchat.indisponible;
    final c = _enCours = Completer<ResultatAchat>();
    final lance = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: p),
    );
    if (!lance) {
      _enCours = null;
      return ResultatAchat.annule;
    }
    return c.future;
  }

  void _finir(ResultatAchat r) {
    final c = _enCours;
    _enCours = null;
    if (c != null && !c.isCompleted) c.complete(r);
  }

  /// Achat rendu par le magasin (aussi au lancement, pour un achat payé
  /// dont le serveur n'a pas encore pris connaissance).
  Future<void> _traiter(PurchaseDetails a) async {
    if (a.productID != produit) return;
    switch (a.status) {
      case PurchaseStatus.pending:
        return;
      case PurchaseStatus.canceled:
        if (a.pendingCompletePurchase) await _iap.completePurchase(a);
        _finir(ResultatAchat.annule);
        return;
      case PurchaseStatus.error:
        if (a.pendingCompletePurchase) await _iap.completePurchase(a);
        _finir(ResultatAchat.refuse);
        return;
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        break;
    }
    final jeton = a.verificationData.serverVerificationData;
    try {
      await api.appel(
        'POST',
        ios ? '/v1/abonnement/app-store' : '/v1/abonnement/google-play',
        json: ios ? {'transactionSignee': jeton} : {'jetonAchat': jeton},
      );
      if (a.pendingCompletePurchase) await _iap.completePurchase(a);
      _surOuvert?.call();
      _finir(ResultatAchat.ouvert);
    } on HorsConnexion {
      // Achat gardé par le magasin, présenté de nouveau au prochain lancement.
      _finir(ResultatAchat.enAttente);
    } on ErreurApi catch (e) {
      if (e.code == 'achat_non_configure') {
        _finir(ResultatAchat.indisponible);
        return;
      }
      if (e.statut >= 500) {
        _finir(ResultatAchat.enAttente);
        return;
      }
      if (a.pendingCompletePurchase) await _iap.completePurchase(a);
      _finir(ResultatAchat.refuse);
    }
  }

  void fermer() => _abonnement?.cancel();
}
