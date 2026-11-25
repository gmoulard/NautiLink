package main

import (
	"context"
	"net/http"
)

// API de l'espace administrateur (docs/api/openapi.yaml, tag Administration)
// et annonces vues par les utilisateurs (RG-ADM-06). Chaque appel est tracé.

type gestionnaireAdmin func(w http.ResponseWriter, r *http.Request, s *sessionAdmin) error

// apiAdmin : base prête, session administrateur exigée (cookie distinct),
// refus des appels venus d'un autre site, erreurs en JSON.
func (a *app) apiAdmin(g gestionnaireAdmin) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if !a.b.prete() {
			ecrireErreurJSON(w, errIndisponible)
			return
		}
		s, err := a.sessionAdminDe(r.Context(), r)
		if err != nil {
			ecrireErreurJSON(w, err)
			return
		}
		if s == nil {
			ecrireErreurJSON(w, errNonAuthentifie())
			return
		}
		if r.Method != http.MethodGet && memeOrigine(r) != nil {
			ecrireErreurJSON(w, errInterdit("interdit", "Requête refusée."))
			return
		}
		if err := g(w, r, s); err != nil {
			ecrireErreurJSON(w, err)
		}
	}
}

func (a *app) routesAdmin(mux *http.ServeMux, v string) {
	// Annonces vues par l'utilisateur connecté (RG-ADM-06).
	mux.HandleFunc("GET "+v+"/annonces", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		l, err := a.annonces(r.Context(), s.utilisateur)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, nonNul(l))
		return nil
	}))
	mux.HandleFunc("POST "+v+"/annonces/{id}/fermeture", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		if err := a.fermerAnnonce(r.Context(), s.utilisateur, r.PathValue("id")); err != nil {
			return err
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))

	mux.HandleFunc("GET "+v+"/admin/{ressource}", a.apiAdmin(func(w http.ResponseWriter, r *http.Request, s *sessionAdmin) error {
		ctx, q := r.Context(), r.URL.Query()
		res, recherche, dec := r.PathValue("ressource"), q.Get("recherche"), decalageDe(q.Get("curseur"))
		var v any
		var err error
		switch res {
		case "utilisateurs":
			v, err = a.utilisateursAdmin(ctx, recherche, dec)
		case "bateaux":
			v, err = a.bateauxAdmin(ctx, recherche, q.Get("utilisateur"), dec)
		case "contacts":
			if !estUUID(q.Get("utilisateur")) {
				return errInvalide("Paramètre « utilisateur » obligatoire.")
			}
			v, _, _, err = a.contacts(ctx, q.Get("utilisateur"), 0)
		case "annonces":
			v, err = a.annonces(ctx, "")
		case "journal":
			v, err = a.journal(ctx, recherche, dec)
		case "statistiques":
			v, err = a.statistiques(ctx)
		case "supervision":
			v, err = a.supervision(ctx)
		default:
			return errPasDisponible
		}
		if err != nil {
			return err
		}
		if err := a.journaliser(ctx, s, "consultation", res, "", map[string]string{"recherche": recherche,
			"utilisateur": q.Get("utilisateur")}); err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, nonNul(v))
		return nil
	}))

	mux.HandleFunc("POST "+v+"/admin/{ressource}", a.apiAdmin(func(w http.ResponseWriter, r *http.Request, s *sessionAdmin) error {
		if r.PathValue("ressource") != "annonces" {
			return errPasDisponible
		}
		var c champs
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		n, err := a.creerAnnonce(r.Context(), s, c)
		if err != nil {
			return err
		}
		if err := a.journaliser(r.Context(), s, "creation", "annonces", n.ID, c); err != nil {
			return err
		}
		ecrireJSON(w, http.StatusCreated, n)
		return nil
	}))

	mux.HandleFunc("PATCH "+v+"/admin/{ressource}/{id}", a.apiAdmin(func(w http.ResponseWriter, r *http.Request, s *sessionAdmin) error {
		ctx, res, id := r.Context(), r.PathValue("ressource"), r.PathValue("id")
		var c champs
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		trace := champs{}
		for k, x := range c {
			trace[k] = x
		}
		var v any
		var err error
		switch res {
		case "utilisateurs":
			if !estUUID(id) {
				return errIntrouvable()
			}
			v, err = a.modifierProfil(ctx, id, c)
		case "bateaux":
			v, err = a.modifierBateauAdmin(ctx, id, c)
		case "annonces":
			v, err = a.modifierAnnonce(ctx, id, c)
		default:
			return errPasDisponible
		}
		if err != nil {
			return err
		}
		if err := a.journaliser(ctx, s, "modification", res, id, trace); err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, v)
		return nil
	}))

	mux.HandleFunc("DELETE "+v+"/admin/{ressource}/{id}", a.apiAdmin(func(w http.ResponseWriter, r *http.Request, s *sessionAdmin) error {
		ctx, res, id := r.Context(), r.PathValue("ressource"), r.PathValue("id")
		if err := a.supprimerParAdmin(ctx, res, id); err != nil {
			return err
		}
		if err := a.journaliser(ctx, s, "suppression", res, id, nil); err != nil {
			return err
		}
		w.WriteHeader(http.StatusNoContent)
		return nil
	}))
}

// supprimerParAdmin : compte (avec ses bateaux, contacts et sessions), bateau,
// contact ou annonce.
func (a *app) supprimerParAdmin(ctx context.Context, res, id string) error {
	switch res {
	case "utilisateurs":
		return a.supprimerAdmin(ctx, "utilisateurs", id)
	case "bateaux":
		return a.supprimerAdmin(ctx, "bateaux", id)
	case "annonces":
		return a.supprimerAdmin(ctx, "annonces", id)
	case "contacts":
		n, err := a.navigateurDuContact(ctx, id)
		if err != nil {
			return err
		}
		return a.supprimerContact(ctx, n, id)
	}
	return errPasDisponible
}

// nonNul : liste vide rendue [] et non null.
func nonNul(v any) any {
	switch l := v.(type) {
	case []utilisateurAdminJSON:
		if l == nil {
			return []utilisateurAdminJSON{}
		}
	case []bateauAdminJSON:
		if l == nil {
			return []bateauAdminJSON{}
		}
	case []contactJSON:
		if l == nil {
			return []contactJSON{}
		}
	case []annonceJSON:
		if l == nil {
			return []annonceJSON{}
		}
	case []entreeJournal:
		if l == nil {
			return []entreeJournal{}
		}
	}
	return v
}
