package main

import (
	"net/http"
	"strconv"
)

// Page « Paramètres » (TODO-4.4) : paramètres généraux, les mêmes que sur le
// téléphone (RG-PRM-01).

type choixFrequence struct {
	Minutes int
	Libelle string
	Choisie bool
}

type donneesParametres struct {
	P          parametresJSON
	Frequences []choixFrequence
}

// libelleFrequence : 15 → « 15 minutes », 120 → « 2 heures », 1440 → « 1 jour ».
func libelleFrequence(m int) string {
	pluriel := func(n int, un, plusieurs string) string {
		if n > 1 {
			return strconv.Itoa(n) + " " + plusieurs
		}
		return "1 " + un
	}
	switch {
	case m%1440 == 0:
		return pluriel(m/1440, "jour", "jours")
	case m%60 == 0:
		return pluriel(m/60, "heure", "heures")
	}
	return pluriel(m, "minute", "minutes")
}

func (a *app) routesWebParametres(mux *http.ServeMux, c string) {
	page := func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		p, err := a.parametres(r.Context(), s.utilisateur)
		if err != nil {
			return err
		}
		donnees := donneesParametres{P: p}
		for _, m := range frequences {
			donnees.Frequences = append(donnees.Frequences, choixFrequence{m, libelleFrequence(m),
				p.FrequenceParDefaut != nil && *p.FrequenceParDefaut == m})
		}
		d.Titre, d.D = "Paramètres", donnees
		a.rendre(w, "parametres.html", d)
		return nil
	}
	mux.HandleFunc("GET "+c+"/parametres", a.web(true, page))
	mux.HandleFunc("POST "+c+"/parametres", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		f := formulaireEnChamps(r, map[string]string{"smsActifs": "case", "photoEnMms": "case"})
		f["smsParType"] = enJSON(formulaireEnChamps(r, map[string]string{"debut": "case", "positionsAutomatiques": "case",
			"positionsManuelles": "case", "notes": "case", "photos": "case", "notesVocales": "case", "incidents": "case", "fin": "case"}))
		if v := r.FormValue("frequenceParDefaut"); v != "" {
			n, err := strconv.Atoi(v)
			if err != nil {
				n = -1
			}
			f["frequenceParDefaut"] = enJSON(n)
		}
		if _, err := a.modifierParametres(r.Context(), s.utilisateur, f); err != nil {
			if d.Erreur, err = messageErreur(err); err != nil {
				return err
			}
			w.WriteHeader(http.StatusUnprocessableEntity)
			return page(w, r, s, d)
		}
		http.Redirect(w, r, c+"/parametres?ok=parametres", http.StatusSeeOther)
		return nil
	}))
}
