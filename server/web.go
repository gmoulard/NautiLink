package main

import (
	"encoding/json"
	"errors"
	"html/template"
	"log"
	"net/http"
	"net/url"
	"strconv"
	"strings"
)

// fonctionsPages : petites aides des gabarits.
var fonctionsPages = template.FuncMap{
	// nombre : 12.5 → « 12,5 » ; absent → vide.
	"nombre": func(n *float64) string {
		if n == nil {
			return ""
		}
		return strings.Replace(strconv.FormatFloat(*n, 'f', -1, 64), ".", ",", 1)
	},
	"oui": func(b *bool) bool { return b != nil && *b },
	// ligne : une navigation du tableau de bord et le chemin des liens.
	"ligne": func(base string, l ligneNav) struct {
		Base string
		L    ligneNav
	} {
		return struct {
			Base string
			L    ligneNav
		}{base, l}
	},
	"deref": func(s *string) string {
		if s == nil {
			return ""
		}
		return *s
	},
}

// Application web (D-147) : pages servies par le serveur, en français, sans
// JavaScript sauf la mise à jour en direct de la page d'une navigation
// (web_navigations.go) : inscription, connexion, compte, tableau de bord.
// Elle appelle les mêmes fonctions que l'API.

// donneesPage : données communes à toutes les pages.
type donneesPage struct {
	Titre, Base            string
	Version                construction
	Avertissement          string
	VersionAvertissement   string
	Connecte, EmailVerifie bool
	Admin                  bool // menu « Administration » (RG-WEB-03)
	Nom                    string
	Message, Erreur        string
	Retour                 string
	DemanderAvertissement  bool
	Annonces               []annonceJSON     // bandeau du tableau de bord (RG-ADM-06)
	F                      map[string]string // valeurs saisies, renvoyées après une erreur
	D                      any               // données propres à la page
}

// messages : messages affichés après un renvoi (?ok=…).
var messages = map[string]string{
	"inscrit":    "Compte créé. Un e-mail vous a été envoyé pour confirmer votre adresse.",
	"verifie":    "Adresse e-mail confirmée.",
	"lien":       "Un nouveau lien vous a été envoyé par e-mail.",
	"enregistre": "Modifications enregistrées.",
	"deconnecte": "Vous êtes déconnecté.",
	"motdepasse": "Mot de passe changé. Connectez-vous avec le nouveau mot de passe.",
}

type pageWeb func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error

// web : enveloppe commune des pages : base prête, session (renvoi vers la
// connexion si elle est exigée), refus des formulaires venus d'un autre site,
// cookie de session prolongé.
func (a *app) web(connecte bool, p pageWeb) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		d := &donneesPage{Base: a.cfg.Chemin, Version: constructionServeur(), Avertissement: adresseAvertissement,
			VersionAvertissement: versionAvertissement, Message: messages[r.URL.Query().Get("ok")], F: map[string]string{}}
		if !a.b.prete() && (connecte || r.Method != http.MethodGet) {
			w.WriteHeader(http.StatusServiceUnavailable)
			d.Titre = "Service momentanément indisponible"
			a.rendre(w, "message.html", d)
			return
		}
		if r.Method == http.MethodPost && memeOrigine(r) != nil {
			http.Error(w, "requête refusée", http.StatusForbidden)
			return
		}
		r.Body = http.MaxBytesReader(w, r.Body, 12<<20)
		var s *session
		if jeton, parCookie := jetonDe(r); parCookie && a.b.prete() {
			var err error
			if s, err = a.sessionDe(r.Context(), r); err != nil {
				a.erreurPage(w, d, err)
				return
			}
			if s == nil {
				a.effacerCookie(w)
			} else {
				a.poserCookie(w, jeton)
				p, err := a.profil(r.Context(), s.utilisateur)
				if err != nil {
					a.erreurPage(w, d, err)
					return
				}
				d.Connecte, d.Nom, d.EmailVerifie = true, p.Nom, p.EmailVerifie
				// Administrateur (RG-ADM-07) : lien vers l'espace administrateur,
				// qui garde sa propre connexion (RG-WEB-03, RG-ADM-01).
				d.Admin = p.EmailVerifie && a.estAdmin(p.Email)
			}
		}
		if connecte && s == nil {
			http.Redirect(w, r, a.cfg.Chemin+"/connexion?retour="+url.QueryEscape(r.URL.RequestURI()), http.StatusSeeOther)
			return
		}
		if err := p(w, r, s, d); err != nil {
			a.erreurPage(w, d, err)
		}
	}
}

func (a *app) rendre(w http.ResponseWriter, nom string, d *donneesPage) {
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	if err := pages.ExecuteTemplate(w, nom, d); err != nil {
		log.Printf("page %s : %v", nom, err)
	}
}

func (a *app) erreurPage(w http.ResponseWriter, d *donneesPage, err error) {
	e := enErreurAPI(err)
	w.WriteHeader(e.statut)
	d.Titre, d.Erreur = "Impossible d'afficher cette page", e.message
	a.rendre(w, "message.html", d)
}

// messageErreur : texte d'une erreur à afficher dans le formulaire, ou
// l'erreur elle-même si elle n'est pas due à la saisie.
func messageErreur(err error) (string, error) {
	var e *erreurAPI
	if errors.As(err, &e) && e.statut < 500 {
		return e.message, nil
	}
	return "", err
}

// retourSur : adresse de retour après connexion, limitée aux pages du site.
func (a *app) retourSur(v string) string {
	if strings.HasPrefix(v, a.cfg.Chemin+"/") && !strings.HasPrefix(v, "//") && !strings.Contains(v, "\\") {
		return v
	}
	return a.cfg.Chemin + "/"
}

func ajouterOK(adresse, ok string) string {
	if strings.Contains(adresse, "?") {
		return adresse + "&ok=" + ok
	}
	return adresse + "?ok=" + ok
}

func (a *app) routesWebComptes(mux *http.ServeMux, c string) {
	a.routesWebMotDePasse(mux, c)

	mux.HandleFunc("GET "+c+"/{$}", a.web(false, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		if s != nil {
			// Connecté : tableau de bord (TODO-6.1, web_navigations.go).
			return a.pageTableau(w, r, s, d)
		}
		a.rendre(w, "accueil.html", d)
		return nil
	}))

	mux.HandleFunc("GET "+c+"/inscription", a.web(false, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		d.Titre, d.Retour = "Créer un compte", r.URL.Query().Get("retour")
		a.rendre(w, "inscription.html", d)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/inscription", a.web(false, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		d.Titre, d.Retour = "Créer un compte", r.FormValue("retour")
		d.F["nom"], d.F["email"] = r.FormValue("nom"), r.FormValue("email")
		id, err := a.creerCompte(r.Context(), r, r.FormValue("email"), r.FormValue("motdepasse"), r.FormValue("nom"), "", r.FormValue("avertissement"))
		if err == nil {
			var jeton string
			if jeton, _, err = a.ouvrirSession(r.Context(), id, "web"); err == nil {
				a.poserCookie(w, jeton)
				http.Redirect(w, r, ajouterOK(a.retourSur(d.Retour), "inscrit"), http.StatusSeeOther)
				return nil
			}
		}
		if d.Erreur, err = messageErreur(err); err != nil {
			return err
		}
		w.WriteHeader(http.StatusUnprocessableEntity)
		a.rendre(w, "inscription.html", d)
		return nil
	}))

	mux.HandleFunc("GET "+c+"/connexion", a.web(false, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		d.Titre, d.Retour = "Se connecter", r.URL.Query().Get("retour")
		a.rendre(w, "connexion.html", d)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/connexion", a.web(false, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		d.Titre, d.Retour, d.F["email"] = "Se connecter", r.FormValue("retour"), r.FormValue("email")
		id, err := a.connexionEmail(r.Context(), r, r.FormValue("email"), r.FormValue("motdepasse"), r.FormValue("avertissement"))
		if err == nil {
			var jeton string
			if jeton, _, err = a.ouvrirSession(r.Context(), id, "web"); err == nil {
				a.poserCookie(w, jeton)
				http.Redirect(w, r, a.retourSur(d.Retour), http.StatusSeeOther)
				return nil
			}
		}
		d.DemanderAvertissement = err == errAvertissement
		if d.Erreur, err = messageErreur(err); err != nil {
			return err
		}
		w.WriteHeader(http.StatusUnauthorized)
		a.rendre(w, "connexion.html", d)
		return nil
	}))

	mux.HandleFunc("POST "+c+"/deconnexion", a.web(false, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		if s != nil {
			if _, err := a.b.pool.Exec(r.Context(), "DELETE FROM sessions WHERE id = $1", s.id); err != nil {
				return err
			}
		}
		a.effacerCookie(w)
		http.Redirect(w, r, c+"/?ok=deconnecte", http.StatusSeeOther)
		return nil
	}))

	mux.HandleFunc("GET "+c+"/verification", a.web(false, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		if _, err := a.verifierEmail(r.Context(), r.URL.Query().Get("jeton")); err != nil {
			return err
		}
		http.Redirect(w, r, c+"/?ok=verifie", http.StatusSeeOther)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/verification/envoi", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		if err := a.envoyerVerification(r.Context(), r, s.utilisateur); err != nil {
			return err
		}
		http.Redirect(w, r, c+"/?ok=lien", http.StatusSeeOther)
		return nil
	}))

	mux.HandleFunc("GET "+c+"/compte", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		p, err := a.profil(r.Context(), s.utilisateur)
		if err != nil {
			return err
		}
		d.Titre, d.D = "Mon compte", p
		a.rendre(w, "compte.html", d)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/compte", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		f := formulaireEnChamps(r, map[string]string{"nom": "texte", "telephone": "texte", "langue": "texte",
			"recevoirSms": "case", "emailsDebut": "case"})
		f["push"] = enJSON(map[string]bool{"debut": r.FormValue("pushDebut") != "", "fin": r.FormValue("pushFin") != "",
			"photo": r.FormValue("pushPhoto") != "", "positionEnRetard": r.FormValue("pushPositionEnRetard") != ""})
		// Premier numéro renseigné : « Recevoir les SMS » s'active (RG-SMS-01).
		if avant, err := a.profil(r.Context(), s.utilisateur); err == nil && avant.Telephone == nil {
			delete(f, "recevoirSms")
		}
		p, err := a.modifierProfil(r.Context(), s.utilisateur, f)
		if err != nil {
			if d.Erreur, err = messageErreur(err); err != nil {
				return err
			}
			p, _ = a.profil(r.Context(), s.utilisateur)
			w.WriteHeader(http.StatusUnprocessableEntity)
			d.Titre, d.D = "Mon compte", p
			a.rendre(w, "compte.html", d)
			return nil
		}
		http.Redirect(w, r, c+"/compte?ok=enregistre", http.StatusSeeOther)
		return nil
	}))
}

func enJSON(v any) json.RawMessage {
	b, _ := json.Marshal(v)
	return b
}

// formulaireEnChamps : champs d'un formulaire, tous présents (une case non
// cochée vaut faux), au format d'une modification partielle de l'API.
func formulaireEnChamps(r *http.Request, sorte map[string]string) champs {
	c := champs{}
	for nom, s := range sorte {
		switch s {
		case "case":
			c[nom] = enJSON(r.FormValue(nom) != "")
		case "texte":
			c[nom] = enJSON(strings.TrimSpace(r.FormValue(nom)))
		case "nombre":
			// Virgule ou point décimal ; vide : effacé ; illisible : refusé par l'API.
			v := strings.ReplaceAll(strings.TrimSpace(r.FormValue(nom)), ",", ".")
			if v == "" {
				c[nom] = enJSON(nil)
			} else if n, err := strconv.ParseFloat(v, 64); err == nil {
				c[nom] = enJSON(n)
			} else {
				c[nom] = enJSON(v)
			}
		}
	}
	return c
}
