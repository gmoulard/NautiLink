package main

import (
	"net/http"
	"strings"
	"time"
)

// Pages de l'espace administrateur (TODO-7.1), sous <chemin>/admin/, servies
// par le serveur sans JavaScript, comme l'Application web ; elles appellent
// les mêmes fonctions que l'API d'administration et tracent chaque action.

type donneesAdmin struct {
	Titre, Base     string
	Version         construction
	Connecte        bool
	Email           string
	Message, Erreur string
	Recherche       string
	F               map[string]string
	D               any
}

var messagesAdmin = map[string]string{
	"enregistre": "Modifications enregistrées.",
	"supprime":   "Suppression faite.",
	"publiee":    "Annonce publiée.",
	"deconnecte": "Vous êtes déconnecté de l'espace administrateur.",
}

type pageAdmin func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error

// webAdmin : enveloppe des pages : base prête, session administrateur (renvoi
// vers la connexion de l'espace administrateur), refus des formulaires venus
// d'un autre site, cookie prolongé.
func (a *app) webAdmin(connecte bool, p pageAdmin) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		d := &donneesAdmin{Base: a.cfg.Chemin, Version: constructionServeur(), Message: messagesAdmin[r.URL.Query().Get("ok")],
			Recherche: r.URL.Query().Get("recherche"), F: map[string]string{}}
		w.Header().Set("X-Robots-Tag", "noindex")
		if !a.b.prete() {
			w.WriteHeader(http.StatusServiceUnavailable)
			d.Titre, d.Erreur = "Service momentanément indisponible", "La base de données n'est pas prête."
			a.rendreAdmin(w, "admin-message.html", d)
			return
		}
		if r.Method == http.MethodPost && memeOrigine(r) != nil {
			http.Error(w, "requête refusée", http.StatusForbidden)
			return
		}
		r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
		s, err := a.sessionAdminDe(r.Context(), r)
		if err != nil {
			a.erreurAdmin(w, d, err)
			return
		}
		if s == nil {
			if _, e := r.Cookie(nomCookieAdmin); e == nil {
				a.effacerCookieAdmin(w)
			}
		} else {
			c, _ := r.Cookie(nomCookieAdmin)
			a.poserCookieAdmin(w, c.Value, s.persistante)
			d.Connecte, d.Email = true, s.email
		}
		if connecte && s == nil {
			http.Redirect(w, r, a.cfg.Chemin+"/admin/connexion", http.StatusSeeOther)
			return
		}
		if err := p(w, r, s, d); err != nil {
			a.erreurAdmin(w, d, err)
		}
	}
}

func (a *app) rendreAdmin(w http.ResponseWriter, nom string, d *donneesAdmin) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	_ = pages.ExecuteTemplate(w, nom, d)
}

func (a *app) erreurAdmin(w http.ResponseWriter, d *donneesAdmin, err error) {
	e := enErreurAPI(err)
	w.WriteHeader(e.statut)
	d.Titre, d.Erreur = "Impossible d'afficher cette page", e.message
	a.rendreAdmin(w, "admin-message.html", d)
}

type donneesAdminAccueil struct {
	Stats       statistiquesJSON
	Supervision supervisionJSON
}

type donneesAdminUtilisateur struct {
	Profil   profilJSON
	Bateaux  []bateauAdminJSON
	Contacts []contactJSON
}

// dateFin : « 2026-12-31 » saisi dans le formulaire → fin de ce jour, heure de
// Paris ; vide : sans date de fin.
func dateFin(v string) (any, error) {
	v = strings.TrimSpace(v)
	if v == "" {
		return nil, nil
	}
	paris, err := time.LoadLocation("Europe/Paris")
	if err != nil {
		paris = time.UTC
	}
	j, err := time.ParseInLocation("2006-01-02", v, paris)
	if err != nil {
		return nil, errInvalide("Date de fin illisible.")
	}
	return j.AddDate(0, 0, 1), nil
}

func (a *app) routesWebAdmin(mux *http.ServeMux, c string) {
	ca := c + "/admin"
	tracer := func(r *http.Request, s *sessionAdmin, action, res, cible string, details any) error {
		return a.journaliser(r.Context(), s, action, res, cible, details)
	}
	vers := func(w http.ResponseWriter, r *http.Request, chemin, ok string) error {
		http.Redirect(w, r, ajouterOK(ca+chemin, ok), http.StatusSeeOther)
		return nil
	}

	mux.HandleFunc("GET "+ca+"/connexion", a.webAdmin(false, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		d.Titre = "Connexion à l'espace administrateur"
		d.F["rester"] = "oui" // « Rester connecté » coché par défaut (D-160)
		a.rendreAdmin(w, "admin-connexion.html", d)
		return nil
	}))
	mux.HandleFunc("POST "+ca+"/connexion", a.webAdmin(false, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		d.Titre, d.F["email"], d.F["rester"] = "Connexion à l'espace administrateur", r.FormValue("email"), r.FormValue("rester")
		rester := d.F["rester"] != ""
		jeton, err := a.connexionAdmin(r.Context(), r, r.FormValue("email"), r.FormValue("motdepasse"), rester)
		if err == nil {
			a.poserCookieAdmin(w, jeton, rester)
			http.Redirect(w, r, ca+"/", http.StatusSeeOther)
			return nil
		}
		if d.Erreur, err = messageErreur(err); err != nil {
			return err
		}
		w.WriteHeader(http.StatusUnauthorized)
		a.rendreAdmin(w, "admin-connexion.html", d)
		return nil
	}))
	mux.HandleFunc("POST "+ca+"/deconnexion", a.webAdmin(false, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		if s != nil {
			if err := tracer(r, s, "deconnexion", "session", "", nil); err != nil {
				return err
			}
			if _, err := a.b.pool.Exec(r.Context(), "DELETE FROM sessions_admin WHERE id = $1", s.id); err != nil {
				return err
			}
		}
		a.effacerCookieAdmin(w)
		http.Redirect(w, r, ca+"/connexion?ok=deconnecte", http.StatusSeeOther)
		return nil
	}))

	mux.HandleFunc("GET "+ca+"/{$}", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		st, err := a.statistiques(r.Context())
		if err != nil {
			return err
		}
		sv, err := a.supervision(r.Context())
		if err != nil {
			return err
		}
		if err := tracer(r, s, "consultation", "statistiques", "", nil); err != nil {
			return err
		}
		d.Titre, d.D = "Tableau de bord", donneesAdminAccueil{st, sv}
		a.rendreAdmin(w, "admin-accueil.html", d)
		return nil
	}))

	// Utilisateurs.
	mux.HandleFunc("GET "+ca+"/utilisateurs", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		l, err := a.utilisateursAdmin(r.Context(), d.Recherche, decalageDe(r.URL.Query().Get("curseur")))
		if err != nil {
			return err
		}
		if err := tracer(r, s, "consultation", "utilisateurs", "", map[string]string{"recherche": d.Recherche}); err != nil {
			return err
		}
		d.Titre, d.D = "Utilisateurs", l
		a.rendreAdmin(w, "admin-utilisateurs.html", d)
		return nil
	}))
	ficheUtilisateur := func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		id := r.PathValue("id")
		if !estUUID(id) {
			return errIntrouvable()
		}
		p, err := a.profil(r.Context(), id)
		if err != nil {
			return err
		}
		b, err := a.bateauxAdmin(r.Context(), "", id, 0)
		if err != nil {
			return err
		}
		k, _, _, err := a.contacts(r.Context(), id, 0)
		if err != nil {
			return err
		}
		d.Titre, d.D = p.Nom, donneesAdminUtilisateur{p, b, k}
		a.rendreAdmin(w, "admin-utilisateur.html", d)
		return nil
	}
	mux.HandleFunc("GET "+ca+"/utilisateurs/{id}", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		if err := tracer(r, s, "consultation", "utilisateurs", r.PathValue("id"), nil); err != nil {
			return err
		}
		return ficheUtilisateur(w, r, s, d)
	}))
	mux.HandleFunc("POST "+ca+"/utilisateurs/{id}", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		id := r.PathValue("id")
		if !estUUID(id) {
			return errIntrouvable()
		}
		f := formulaireEnChamps(r, map[string]string{"nom": "texte", "telephone": "texte"})
		if _, err := a.modifierProfil(r.Context(), id, f); err != nil {
			if d.Erreur, err = messageErreur(err); err != nil {
				return err
			}
			w.WriteHeader(http.StatusUnprocessableEntity)
			return ficheUtilisateur(w, r, s, d)
		}
		if err := tracer(r, s, "modification", "utilisateurs", id, f); err != nil {
			return err
		}
		return vers(w, r, "/utilisateurs/"+id, "enregistre")
	}))
	mux.HandleFunc("POST "+ca+"/utilisateurs/{id}/suppression", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		id := r.PathValue("id")
		if r.FormValue("confirmation") == "" {
			d.Erreur = "Cochez la case de confirmation pour supprimer le compte."
			w.WriteHeader(http.StatusUnprocessableEntity)
			return ficheUtilisateur(w, r, s, d)
		}
		if err := a.supprimerParAdmin(r.Context(), "utilisateurs", id); err != nil {
			return err
		}
		if err := tracer(r, s, "suppression", "utilisateurs", id, nil); err != nil {
			return err
		}
		return vers(w, r, "/utilisateurs", "supprime")
	}))
	mux.HandleFunc("POST "+ca+"/contacts/{id}/suppression", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		id := r.PathValue("id")
		n, err := a.navigateurDuContact(r.Context(), id)
		if err != nil {
			return err
		}
		if err := a.supprimerParAdmin(r.Context(), "contacts", id); err != nil {
			return err
		}
		if err := tracer(r, s, "suppression", "contacts", id, nil); err != nil {
			return err
		}
		return vers(w, r, "/utilisateurs/"+n, "supprime")
	}))

	// Bateaux.
	mux.HandleFunc("GET "+ca+"/bateaux", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		l, err := a.bateauxAdmin(r.Context(), d.Recherche, "", decalageDe(r.URL.Query().Get("curseur")))
		if err != nil {
			return err
		}
		if err := tracer(r, s, "consultation", "bateaux", "", map[string]string{"recherche": d.Recherche}); err != nil {
			return err
		}
		d.Titre, d.D = "Bateaux", l
		a.rendreAdmin(w, "admin-bateaux.html", d)
		return nil
	}))
	ficheBateau := func(w http.ResponseWriter, r *http.Request, d *donneesAdmin) error {
		b, err := a.bateauAdmin(r.Context(), r.PathValue("id"))
		if err != nil {
			return err
		}
		d.Titre, d.D = b.Nom, b
		a.rendreAdmin(w, "admin-bateau.html", d)
		return nil
	}
	mux.HandleFunc("GET "+ca+"/bateaux/{id}", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		if err := tracer(r, s, "consultation", "bateaux", r.PathValue("id"), nil); err != nil {
			return err
		}
		return ficheBateau(w, r, d)
	}))
	mux.HandleFunc("POST "+ca+"/bateaux/{id}", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		id := r.PathValue("id")
		f := formulaireEnChamps(r, formulaireFiche)
		if e := strings.TrimSpace(r.FormValue("proprietaireEmail")); e != "" {
			f["proprietaireEmail"] = enJSON(e)
		}
		trace := champs{}
		for k, x := range f {
			trace[k] = x
		}
		if _, err := a.modifierBateauAdmin(r.Context(), id, f); err != nil {
			if d.Erreur, err = messageErreur(err); err != nil {
				return err
			}
			w.WriteHeader(http.StatusUnprocessableEntity)
			return ficheBateau(w, r, d)
		}
		if err := tracer(r, s, "modification", "bateaux", id, trace); err != nil {
			return err
		}
		return vers(w, r, "/bateaux/"+id, "enregistre")
	}))
	mux.HandleFunc("POST "+ca+"/bateaux/{id}/suppression", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		id := r.PathValue("id")
		if r.FormValue("confirmation") == "" {
			d.Erreur = "Cochez la case de confirmation pour supprimer le bateau."
			w.WriteHeader(http.StatusUnprocessableEntity)
			return ficheBateau(w, r, d)
		}
		if err := a.supprimerParAdmin(r.Context(), "bateaux", id); err != nil {
			return err
		}
		if err := tracer(r, s, "suppression", "bateaux", id, nil); err != nil {
			return err
		}
		return vers(w, r, "/bateaux", "supprime")
	}))

	// Annonces (RG-ADM-06).
	listeAnnonces := func(w http.ResponseWriter, r *http.Request, d *donneesAdmin) error {
		l, err := a.annonces(r.Context(), "")
		if err != nil {
			return err
		}
		d.Titre, d.D = "Annonces", l
		a.rendreAdmin(w, "admin-annonces.html", d)
		return nil
	}
	mux.HandleFunc("GET "+ca+"/annonces", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		if err := tracer(r, s, "consultation", "annonces", "", nil); err != nil {
			return err
		}
		return listeAnnonces(w, r, d)
	}))
	mux.HandleFunc("POST "+ca+"/annonces", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		d.F["texte"], d.F["fin"] = r.FormValue("texte"), r.FormValue("fin")
		fin, err := dateFin(r.FormValue("fin"))
		var n annonceJSON
		f := champs{"texte": enJSON(r.FormValue("texte")), "finLe": enJSON(fin)}
		if err == nil {
			n, err = a.creerAnnonce(r.Context(), s, f)
		}
		if err != nil {
			if d.Erreur, err = messageErreur(err); err != nil {
				return err
			}
			w.WriteHeader(http.StatusUnprocessableEntity)
			return listeAnnonces(w, r, d)
		}
		if err := tracer(r, s, "creation", "annonces", n.ID, f); err != nil {
			return err
		}
		return vers(w, r, "/annonces", "publiee")
	}))
	mux.HandleFunc("POST "+ca+"/annonces/{id}/fin", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		id := r.PathValue("id")
		f := champs{"finLe": enJSON(time.Now().UTC())}
		if _, err := a.modifierAnnonce(r.Context(), id, f); err != nil {
			return err
		}
		if err := tracer(r, s, "modification", "annonces", id, f); err != nil {
			return err
		}
		return vers(w, r, "/annonces", "enregistre")
	}))
	mux.HandleFunc("POST "+ca+"/annonces/{id}/suppression", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		id := r.PathValue("id")
		if err := a.supprimerParAdmin(r.Context(), "annonces", id); err != nil {
			return err
		}
		if err := tracer(r, s, "suppression", "annonces", id, nil); err != nil {
			return err
		}
		return vers(w, r, "/annonces", "supprime")
	}))

	// Journal des actions (RG-ADM-03, gardé 3 ans).
	mux.HandleFunc("GET "+ca+"/journal", a.webAdmin(true, func(w http.ResponseWriter, r *http.Request, s *sessionAdmin, d *donneesAdmin) error {
		if err := tracer(r, s, "consultation", "journal", "", map[string]string{"recherche": d.Recherche}); err != nil {
			return err
		}
		l, err := a.journal(r.Context(), d.Recherche, decalageDe(r.URL.Query().Get("curseur")))
		if err != nil {
			return err
		}
		d.Titre, d.D = "Journal des actions", l
		a.rendreAdmin(w, "admin-journal.html", d)
		return nil
	}))

	// Bandeau des annonces du tableau de bord Web : fermeture par l'utilisateur.
	mux.HandleFunc("POST "+c+"/annonces/{id}/fermeture", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		if err := a.fermerAnnonce(r.Context(), s.utilisateur, r.PathValue("id")); err != nil {
			return err
		}
		http.Redirect(w, r, c+"/", http.StatusSeeOther)
		return nil
	}))
}
