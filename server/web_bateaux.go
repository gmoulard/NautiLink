package main

import (
	"net/http"
)

// Pages « Bateaux » (TODO-4.2) : liste, ajout, fiche, photo, téléphone associé.

type donneesBateaux struct {
	Bateaux   []bateauJSON
	Fiche     bateauJSON
	Appareils []appareilJSON
}

var formulaireFiche = map[string]string{"nom": "texte", "type": "texte", "immatriculation": "texte",
	"portAttache": "texte", "moteur": "texte", "autonomie": "texte", "longueurMetres": "nombre",
	"capaciteCarburantLitres": "nombre", "vitesseNoeuds": "nombre", "tirantEauMetres": "nombre"}

// ficheSaisie : fiche telle que saisie, pour la réafficher après une erreur.
func ficheSaisie(r *http.Request, b bateauJSON) bateauJSON {
	_ = appliquerFiche(&b, formulaireEnChamps(r, formulaireFiche), false)
	return b
}

func (a *app) routesWebBateaux(mux *http.ServeMux, c string) {
	liste := func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage, saisie bateauJSON) error {
		l, err := a.bateaux(r.Context(), s.utilisateur)
		if err != nil {
			return err
		}
		d.Titre, d.D = "Bateaux", donneesBateaux{Bateaux: l, Fiche: saisie}
		a.rendre(w, "bateaux.html", d)
		return nil
	}
	fiche := func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage, saisie *bateauJSON) error {
		b, err := a.bateauDuProprietaire(r.Context(), s.utilisateur, r.PathValue("id"))
		if err != nil {
			return err
		}
		ap, err := a.appareils(r.Context(), s.utilisateur)
		if err != nil {
			return err
		}
		if saisie != nil {
			b = *saisie
		}
		d.Titre, d.D = b.Nom, donneesBateaux{Fiche: b, Appareils: ap}
		a.rendre(w, "bateau.html", d)
		return nil
	}
	// echec : erreur de saisie réaffichée dans la page, autre erreur remontée.
	echec := func(w http.ResponseWriter, d *donneesPage, err error, page func() error) error {
		if d.Erreur, err = messageErreur(err); err != nil {
			return err
		}
		w.WriteHeader(http.StatusUnprocessableEntity)
		return page()
	}

	mux.HandleFunc("GET "+c+"/bateaux", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		return liste(w, r, s, d, bateauJSON{})
	}))
	mux.HandleFunc("POST "+c+"/bateaux", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		b, err := a.creerBateau(r.Context(), s.utilisateur, formulaireEnChamps(r, formulaireFiche))
		if err != nil {
			return echec(w, d, err, func() error { return liste(w, r, s, d, ficheSaisie(r, bateauJSON{})) })
		}
		http.Redirect(w, r, c+"/bateaux/"+b.ID+"?ok=ajoute", http.StatusSeeOther)
		return nil
	}))
	mux.HandleFunc("GET "+c+"/bateaux/{id}", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		return fiche(w, r, s, d, nil)
	}))
	mux.HandleFunc("POST "+c+"/bateaux/{id}", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		if _, err := a.modifierBateau(r.Context(), s.utilisateur, r.PathValue("id"), formulaireEnChamps(r, formulaireFiche)); err != nil {
			return echec(w, d, err, func() error {
				b, err := a.bateauDuProprietaire(r.Context(), s.utilisateur, r.PathValue("id"))
				if err != nil {
					return err
				}
				saisie := ficheSaisie(r, b)
				return fiche(w, r, s, d, &saisie)
			})
		}
		http.Redirect(w, r, c+"/bateaux/"+r.PathValue("id")+"?ok=enregistre", http.StatusSeeOther)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/bateaux/{id}/photo", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		f, _, err := r.FormFile("photo")
		if err != nil {
			err = errInvalide("Choisissez une photo au format JPEG (5 Mo au plus).")
		} else {
			defer f.Close()
			err = a.enregistrerPhotoBateau(r.Context(), s.utilisateur, r.PathValue("id"), f)
		}
		if err != nil {
			return echec(w, d, err, func() error { return fiche(w, r, s, d, nil) })
		}
		http.Redirect(w, r, c+"/bateaux/"+r.PathValue("id")+"?ok=photo", http.StatusSeeOther)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/bateaux/{id}/telephone", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		if _, err := a.associerTelephone(r.Context(), s.utilisateur, r.PathValue("id"), r.FormValue("appareilId")); err != nil {
			return echec(w, d, err, func() error { return fiche(w, r, s, d, nil) })
		}
		http.Redirect(w, r, c+"/bateaux/"+r.PathValue("id")+"?ok=associe", http.StatusSeeOther)
		return nil
	}))
}
