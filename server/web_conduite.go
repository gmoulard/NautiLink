package main

import (
	"context"
	"errors"
	"io"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"
)

// Fonctions de l'application mobile dans l'Application web (TODO-6.8,
// RG-WEB-01, RG-WEB-02, D-150), sans SMS (RG-IOS-02) : pendant une
// navigation en cours, son navigateur envoie « Envoyer position », une note
// ou un « Incident - avarie » (RG-JRN-11, D-165), une photo ou une note
// vocale (fichier choisi, comme les ajouts : RG-JRN-04, RG-JRN-08) et la
// termine (RG-NAV-13 ; le téléphone l'apprend, RG-NAV-33) ; la page envoie
// les positions automatiques tant qu'elle reste ouverte (static/conduite.js) ;
// SOS par Internet seulement, depuis la page de la navigation ou le tableau
// de bord (RG-SOS-01, RG-SOS-02, RG-SOS-15), hors navigation avec le bateau
// choisi parmi ceux du compte. Position : géolocalisation du navigateur
// Internet si la personne l'accepte, sinon aucune (le SOS prend la dernière
// position du journal, RG-SOS-10) (RG-WEB-05, D-163) ; heures dans le fuseau
// du navigateur Internet, sinon celui du début de la navigation, sinon UTC
// (RG-WEB-07). Démarrage : web_demarrage.go.

func init() {
	messages["envoye"] = "Envoyé au journal de bord."
	messages["terminee"] = "Navigation terminée."
	messages["sos"] = "Alerte SOS envoyée : les e-mails partent à vos amis dont l'e-mail est connu. Aucun SMS n'est envoyé depuis l'Application web : alertez aussi les secours, canal 16 de la VHF ou 196."
}

// heureWebMaintenant : heure d'un envoi fait depuis le Web, dans le fuseau
// indiqué (RG-PRM-07, RG-WEB-07).
func (a *app) heureWebMaintenant(decalage *int) time.Time {
	return a.maintenant().In(zoneDe(decalage)).Truncate(time.Second)
}

// fuseauWeb : fuseau du navigateur Internet (RG-WEB-07), sinon celui du
// début de la navigation.
func fuseauWeb(r *http.Request, n navLigne) *int {
	if f := decalageWeb(r.FormValue("decalage")); f != nil {
		return f
	}
	return n.decalage
}

// navigationConduite : navigation en cours de ce navigateur.
func (a *app) navigationConduite(ctx context.Context, utilisateur, id string) (navLigne, error) {
	n, err := a.navigationDuNavigateur(ctx, utilisateur, id)
	if err == nil && !n.enCours() {
		err = &erreurAPI{http.StatusConflict, "navigation_terminee", "Cette navigation est terminée.", 0}
	}
	return n, err
}

// dernierePosition : dernière position du journal de la navigation, pour un
// SOS sans GPS (RG-SOS-10, RG-SOS-23).
func (a *app) dernierePosition(ctx context.Context, navigation string) (*positionJSON, error) {
	var p positionJSON
	var hp *time.Time
	err := a.b.pool.QueryRow(ctx, `SELECT latitude, longitude, precision_metres, heure_position, heure_acquisition FROM evenements
		WHERE navigation_id = $1 AND latitude IS NOT NULL AND longitude IS NOT NULL AND supprime_le IS NULL
		ORDER BY heure_acquisition DESC, numero_ordre DESC NULLS LAST LIMIT 1`, navigation).
		Scan(&p.Latitude, &p.Longitude, &p.PrecisionMetres, &hp, &p.HeureAcquisition)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if hp != nil {
		p.HeureAcquisition = *hp
	}
	return &p, err
}

type donneesPageSos struct {
	Navigation *navigationJSON
	Bateaux    []bateauJSON
}

func (a *app) routesWebConduite(mux *http.ServeMux, c string) {
	page := func(id, ok string) string { return c + "/navigations/" + id + "?ok=" + ok }
	echec := func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage, err error) error {
		statut := enErreurAPI(err).statut
		if d.Erreur, err = messageErreur(err); err != nil {
			return err
		}
		nav, err := a.donneesDeLaNavigation(r.Context(), s.utilisateur, r.PathValue("id"))
		if err != nil {
			return err
		}
		d.Titre, d.D = nav.N.Nom, nav
		origineSeulement(w)
		w.WriteHeader(statut)
		a.rendre(w, "navigation.html", d)
		return nil
	}

	// Note, photo ou note vocale pendant la navigation.
	mux.HandleFunc("POST "+c+"/navigations/{id}/conduite", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		id := r.PathValue("id")
		n, err := a.navigationConduite(r.Context(), s.utilisateur, id)
		if err != nil {
			return err
		}
		var donnees []byte
		if f, _, err := r.FormFile("fichier"); err == nil {
			donnees, err = io.ReadAll(io.LimitReader(f, tailleFichierMax+1))
			f.Close()
			if err != nil {
				return errInvalide("Fichier illisible.")
			}
		}
		h := a.heureWebMaintenant(fuseauWeb(r, n))
		e := evenementJSON{ID: nouvelUUID(), Type: "note", Origine: "web", Texte: texteOuNul(ptr(r.FormValue("texte"))),
			HeureAcquisition: h, Position: positionWeb(r, h)}
		if e.Fichier, err = fichierAjout(donnees); err != nil {
			return echec(w, r, s, d, err)
		}
		switch {
		case r.FormValue("type") == "incident": // RG-JRN-11, D-165 : texte obligatoire, une pièce jointe
			e.Type = "incident"
		case e.Fichier != nil && e.Fichier.TypeMedia == "image/jpeg":
			e.Type = "photo"
		case e.Fichier != nil:
			e.Type = "note_vocale"
		case e.Texte == nil:
			return echec(w, r, s, d, errInvalide("Écrivez une note ou choisissez une photo ou une note vocale."))
		}
		if _, _, err := a.envoyerEvenement(r.Context(), s.utilisateur, id, e); err != nil {
			return echec(w, r, s, d, err)
		}
		if e.Fichier != nil {
			if err := a.deposerFichier(r.Context(), s.utilisateur, e.ID, e.Fichier.TypeMedia, donnees); err != nil {
				return err
			}
		}
		http.Redirect(w, r, page(id, "envoye")+"#evenement-"+e.ID, http.StatusSeeOther)
		return nil
	}))

	// « Terminer la navigation », avec confirmation (RG-NAV-13) : fenêtre
	// ouverte par static/conduite.js, qui envoie « confirmation » (D-178).
	mux.HandleFunc("POST "+c+"/navigations/{id}/fin", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		id := r.PathValue("id")
		n, err := a.navigationConduite(r.Context(), s.utilisateur, id)
		if err != nil {
			return err
		}
		if r.FormValue("confirmation") == "" {
			// Sans JavaScript, pas de fenêtre de confirmation : la
			// même question sur une page (D-178).
			res, err := a.resumer(r.Context(), n, "navigateur")
			if err != nil {
				return err
			}
			d.Titre, d.D = "Terminer la navigation ?", donneesNavigation{N: res}
			a.rendre(w, "fin.html", d)
			return nil
		}
		h := a.heureWebMaintenant(fuseauWeb(r, n))
		fin := evenementJSON{ID: nouvelUUID(), Type: "fin", Origine: "web", HeureAcquisition: h, Position: positionWeb(r, h)}
		if _, err := a.terminer(r.Context(), s.utilisateur, id, fin); err != nil {
			return echec(w, r, s, d, err)
		}
		http.Redirect(w, r, page(id, "terminee"), http.StatusSeeOther)
		return nil
	}))

	// « Envoyer position » (position manuelle, renvoi vers la page) et
	// positions automatiques de static/conduite.js (204), par la
	// géolocalisation du navigateur Internet (RG-WEB-05).
	mux.HandleFunc("POST "+c+"/navigations/{id}/position", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		id := r.PathValue("id")
		n, err := a.navigationConduite(r.Context(), s.utilisateur, id)
		if err != nil {
			return err
		}
		auto := r.FormValue("type") == "position_automatique"
		h := a.heureWebMaintenant(fuseauWeb(r, n))
		e := evenementJSON{ID: nouvelUUID(), Type: "position_manuelle", Origine: "web", HeureAcquisition: h, Position: positionWeb(r, h)}
		if auto {
			e.Type = "position_automatique"
		}
		if e.Position == nil {
			err = errInvalide("Position indisponible : autorisez la localisation pour ce site dans votre navigateur Internet, puis réessayez.")
		} else {
			_, _, err = a.envoyerEvenement(r.Context(), s.utilisateur, id, e)
		}
		switch {
		case auto && err != nil:
			w.WriteHeader(enErreurAPI(err).statut)
		case auto:
			w.WriteHeader(http.StatusNoContent)
		case err != nil:
			return echec(w, r, s, d, err)
		default:
			http.Redirect(w, r, page(id, "position")+"#evenement-"+e.ID, http.StatusSeeOther)
		}
		return nil
	}))

	// Boîte de confirmation du SOS (RG-SOS-02) : pendant la navigation en
	// cours indiquée, sinon hors navigation avec le choix du bateau.
	sos := func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage, navigation string) error {
		d.Titre = "Envoyer un SOS ?"
		var donnees donneesPageSos
		if navigation != "" {
			n, err := a.navigationConduite(r.Context(), s.utilisateur, navigation)
			if err != nil {
				return err
			}
			res, err := a.resumer(r.Context(), n, "navigateur")
			if err != nil {
				return err
			}
			donnees.Navigation = &res
		} else {
			var err error
			if donnees.Bateaux, err = a.bateaux(r.Context(), s.utilisateur); err != nil {
				return err
			}
			if len(donnees.Bateaux) == 0 && d.Erreur == "" { // RG-SOS-23
				d.Erreur = "Aucun bateau dans votre compte : NautiLink ne peut pas envoyer l'alerte. Alertez les secours : canal 16 de la VHF ou 196."
			}
		}
		d.D = donnees
		a.rendre(w, "sos.html", d)
		return nil
	}
	mux.HandleFunc("GET "+c+"/sos", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		return sos(w, r, s, d, r.URL.Query().Get("navigation"))
	}))
	mux.HandleFunc("POST "+c+"/sos", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		al := alerteSosJSON{ProblemeRencontre: texteOuNul(ptr(r.FormValue("probleme"))), HeureDeclenchement: a.heureWebMaintenant(decalageWeb(r.FormValue("decalage")))}
		al.Position = positionWeb(r, al.HeureDeclenchement) // RG-WEB-05 : position actuelle
		if nav := r.FormValue("navigationId"); nav != "" {
			n, err := a.navigationConduite(r.Context(), s.utilisateur, nav)
			if err != nil {
				return err
			}
			al.NavigationID, al.HeureDeclenchement = &n.id, a.heureWebMaintenant(fuseauWeb(r, n))
			if al.Position != nil {
				al.Position.HeureAcquisition = al.HeureDeclenchement
			} else if al.Position, err = a.dernierePosition(r.Context(), n.id); err != nil {
				return err
			} else if al.Position != nil {
				al.NaturePosition = "derniere_connue"
			}
		} else {
			al.BateauID = r.FormValue("bateauId")
		}
		if _, _, err := a.envoyerAlerte(r.Context(), r, s.utilisateur, nouvelUUID(), al); err != nil {
			if d.Erreur, err = messageErreur(err); err != nil {
				return err
			}
			w.WriteHeader(http.StatusUnprocessableEntity)
			return sos(w, r, s, d, r.FormValue("navigationId"))
		}
		http.Redirect(w, r, c+"/alertes-sos?ok=sos", http.StatusSeeOther)
		return nil
	}))
}
