package main

import (
	"net/http"
	"net/url"
)

// Pages « Amis » (TODO-4.3, D-176) : amis, invitations, accès, page
// d'invitation.

type donneesContacts struct {
	Contacts      []contactJSON
	Saisie        contactJSON
	Invitations   []invitationJSON
	Donnes, Recus []accesJSON
}

var formulaireContact = map[string]string{"nom": "texte", "telephone": "texte", "email": "texte",
	"perimetre": "texte"}

// champsContact : formulaire en modification partielle ; un champ vide est effacé.
func champsContact(r *http.Request) champs {
	c := formulaireEnChamps(r, formulaireContact)
	for _, nom := range []string{"telephone", "email"} {
		if r.FormValue(nom) == "" {
			c[nom] = enJSON(nil)
		}
	}
	return c
}

func (a *app) routesWebContacts(mux *http.ServeMux, c string) {
	liste := func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage, saisie contactJSON) error {
		l, _, _, err := a.contacts(r.Context(), s.utilisateur, 0)
		if err != nil {
			return err
		}
		donnes, err := a.listeAcces(r.Context(), s.utilisateur, "navigateur")
		if err != nil {
			return err
		}
		recus, err := a.listeAcces(r.Context(), s.utilisateur, "suiveur")
		if err != nil {
			return err
		}
		d.Titre, d.D = "Contacts", donneesContacts{Contacts: l, Saisie: saisie, Donnes: donnes, Recus: recus}
		a.rendre(w, "contacts.html", d)
		return nil
	}
	fiche := func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage, saisie *contactJSON) error {
		k, err := a.contact(r.Context(), a.b.pool, s.utilisateur, r.PathValue("id"))
		if err != nil {
			return err
		}
		inv, err := a.invitations(r.Context(), r, s.utilisateur, k.ID)
		if err != nil {
			return err
		}
		if saisie != nil {
			k = *saisie
		}
		if len(inv) > 0 {
			inv = inv[:1]
		}
		d.Titre, d.D = k.Nom, donneesContacts{Saisie: k, Invitations: inv}
		a.rendre(w, "contact.html", d)
		return nil
	}
	echec := func(w http.ResponseWriter, d *donneesPage, err error, page func() error) error {
		if d.Erreur, err = messageErreur(err); err != nil {
			return err
		}
		w.WriteHeader(http.StatusUnprocessableEntity)
		return page()
	}
	saisie := func(r *http.Request, k contactJSON) contactJSON {
		k.Nom = r.FormValue("nom")
		t, e := r.FormValue("telephone"), r.FormValue("email")
		k.Telephone, k.Email = &t, &e
		return k
	}

	mux.HandleFunc("GET "+c+"/contacts", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		return liste(w, r, s, d, contactJSON{Suiveur: true, ContactSos: true})
	}))
	mux.HandleFunc("POST "+c+"/contacts", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		k, _, err := a.creerContact(r.Context(), r, s.utilisateur, champsContact(r))
		if err != nil {
			return echec(w, d, err, func() error { return liste(w, r, s, d, saisie(r, contactJSON{})) })
		}
		http.Redirect(w, r, c+"/contacts/"+k.ID+"?ok=contact", http.StatusSeeOther)
		return nil
	}))
	mux.HandleFunc("GET "+c+"/contacts/{id}", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		return fiche(w, r, s, d, nil)
	}))
	mux.HandleFunc("POST "+c+"/contacts/{id}", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		if _, err := a.modifierContact(r.Context(), r, s.utilisateur, r.PathValue("id"), champsContact(r)); err != nil {
			return echec(w, d, err, func() error {
				k, err := a.contact(r.Context(), a.b.pool, s.utilisateur, r.PathValue("id"))
				if err != nil {
					return err
				}
				k = saisie(r, k)
				return fiche(w, r, s, d, &k)
			})
		}
		http.Redirect(w, r, c+"/contacts/"+r.PathValue("id")+"?ok=contact", http.StatusSeeOther)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/contacts/{id}/suppression", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		if err := a.supprimerContact(r.Context(), s.utilisateur, r.PathValue("id")); err != nil {
			return err
		}
		http.Redirect(w, r, c+"/contacts?ok=supprime", http.StatusSeeOther)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/invitations/{id}/annulation", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		var contact *string
		_ = a.b.pool.QueryRow(r.Context(), "SELECT contact_id::text FROM invitations WHERE id::text = $1 AND navigateur_id = $2",
			r.PathValue("id"), s.utilisateur).Scan(&contact)
		if err := a.annulerInvitation(r.Context(), s.utilisateur, r.PathValue("id")); err != nil {
			return err
		}
		vers := c + "/contacts"
		if contact != nil {
			vers += "/" + *contact
		}
		http.Redirect(w, r, vers+"?ok=annulee", http.StatusSeeOther)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/acces/{id}/retrait", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		if err := a.retirerAcces(r.Context(), s.utilisateur, r.PathValue("id")); err != nil {
			return err
		}
		http.Redirect(w, r, c+"/contacts?ok=retire", http.StatusSeeOther)
		return nil
	}))

	// Page du lien d'invitation : connexion ou création d'un compte, puis
	// acceptation (RG-PAR-05) ; aucun accès sans compte (RG-PAR-01).
	mux.HandleFunc("GET "+c+"/invitation", a.web(false, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		jeton := r.URL.Query().Get("jeton")
		_, _, nom, _, _, err := a.invitationParJeton(r.Context(), jeton)
		if err != nil {
			return err
		}
		d.Titre = "Invitation"
		d.D = map[string]string{"Navigateur": nom, "Jeton": jeton, "Retour": c + "/invitation?jeton=" + url.QueryEscape(jeton)}
		a.rendre(w, "invitation.html", d)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/invitation", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		if _, err := a.accepterInvitation(r.Context(), s.utilisateur, r.FormValue("jeton")); err != nil {
			return err
		}
		http.Redirect(w, r, c+"/contacts?ok=accepte", http.StatusSeeOther)
		return nil
	}))
}
