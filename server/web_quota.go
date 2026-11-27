package main

import (
	"net/http"
)

// Page « Quota et abonnement » de l'Application web (TODO-6.7, RG-ECO-09,
// RG-ECO-10) : temps consommé et disponible, clôture automatique annoncée,
// état de l'abonnement, quel que soit le canal de la souscription
// (RG-ECO-07), sans les prochaines minutes récupérables (D-179) ;
// « Souscrire l'abonnement » par carte bancaire avec Stripe (RG-ECO-11,
// stripe.go) ; lien vers la page d'information du site.

const adresseInfoAbonnement = "https://gmoulard.github.io/NautiLink/abonnement.html"

var libellesCanal = map[string]string{"stripe": "carte bancaire sur le Web", "google_play": "Google Play", "app_store": "App Store"}

type donneesQuota struct {
	Q                      quotaJSON
	Consomme, Disponible   string
	Cloture, FinAbonnement string
	Canal                  string
	Info                   string
	StripeOuvert           bool
}

func init() {
	messages["abonne"] = "Paiement confirmé : votre abonnement est ouvert pour 10 ans."
}

// formStripe : la page envoie le formulaire de paiement, renvoyé vers la
// page de paiement de Stripe (politique de sécurité du contenu).
func formStripe(w http.ResponseWriter) {
	w.Header().Set("Content-Security-Policy", "default-src 'self'; img-src 'self' data: "+sourcesCarte+
		"; frame-ancestors 'none'; form-action 'self' https://checkout.stripe.com; base-uri 'none'")
}

func (a *app) routesWebQuota(mux *http.ServeMux, c string) {
	page := func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		q, err := a.quota(r.Context(), s.utilisateur)
		if err != nil {
			return err
		}
		dq := donneesQuota{Q: q, Consomme: dureeTexte(q.ConsommeMinutes), Disponible: dureeTexte(q.DisponibleMinutes),
			Info: adresseInfoAbonnement, StripeOuvert: a.stripe.cle != "", Canal: libellesCanal[texteOuVide(q.Abonnement.Canal)]}
		if q.ClotureAutomatiqueLe != nil {
			dq.Cloture = heureWeb(*q.ClotureAutomatiqueLe, nil)
		}
		if q.Abonnement.Actif && q.Abonnement.Fin != nil {
			dq.FinAbonnement = dateFrancaise(*q.Abonnement.Fin, nil)
		}
		d.Titre, d.D = "Quota et abonnement", dq
		formStripe(w)
		a.rendre(w, "quota.html", d)
		return nil
	}
	mux.HandleFunc("GET "+c+"/quota", a.web(true, page))
	mux.HandleFunc("POST "+c+"/quota/abonnement", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		p, err := a.profil(r.Context(), s.utilisateur)
		if err != nil {
			return err
		}
		base := a.adressePublique(r)
		adresse, err := a.stripe.ouvrirPaiement(r.Context(), s.utilisateur, p.Email, base+"/quota/abonnement/retour", base+"/quota")
		if err != nil {
			if d.Erreur, err = messageErreur(err); err != nil {
				return err
			}
			formStripe(w)
			w.WriteHeader(http.StatusServiceUnavailable)
			return page(w, r, s, d)
		}
		http.Redirect(w, r, adresse, http.StatusSeeOther)
		return nil
	}))
	// Retour de la page de paiement : session relue auprès de Stripe avant
	// d'ouvrir l'abonnement (RG-ECO-11).
	mux.HandleFunc("GET "+c+"/quota/abonnement/retour", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		ref, err := a.stripe.verifierSession(r.Context(), r.URL.Query().Get("session"), s.utilisateur)
		if err == nil {
			err = a.ouvrirAbonnement(r.Context(), s.utilisateur, "stripe", ref)
		}
		if err != nil {
			if d.Erreur, err = messageErreur(err); err != nil {
				return err
			}
			formStripe(w)
			w.WriteHeader(http.StatusPaymentRequired)
			return page(w, r, s, d)
		}
		http.Redirect(w, r, c+"/quota?ok=abonne", http.StatusSeeOther)
		return nil
	}))
}
