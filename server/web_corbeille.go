package main

import (
	"net/http"
	"strconv"
	"time"
)

// Page « Corbeille » (TODO-4.8) : navigations supprimées, avec leur date de
// suppression définitive, et « Restaurer » (RG-NAV-20, cahier des charges
// 6.3). Le bouton « Supprimer » de la page de la navigation (TODO-6.2)
// enverra le formulaire POST <chemin>/navigations/{id}/suppression.

var moisFrancais = [...]string{"janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août",
	"septembre", "octobre", "novembre", "décembre"}

// dateFrancaise : « 25 décembre 2026 », dans le fuseau du téléphone au
// début de la navigation (RG-PRM-07, D-151), UTC sans décalage connu.
func dateFrancaise(t time.Time, decalage *int) string {
	t = t.In(zoneDe(decalage))
	jour := strconv.Itoa(t.Day())
	if t.Day() == 1 {
		jour = "1er"
	}
	return jour + " " + moisFrancais[t.Month()-1] + " " + strconv.Itoa(t.Year())
}

type ligneCorbeille struct {
	N          navigationJSON
	Debut      string
	Definitive string
}

func init() {
	messages["corbeille"] = "Navigation mise dans la corbeille. Vous pouvez la restaurer pendant 30 jours."
	messages["restauree"] = "Navigation restaurée."
}

func (a *app) routesWebCorbeille(mux *http.ServeMux, c string) {
	mux.HandleFunc("GET "+c+"/corbeille", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		l, err := a.corbeille(r.Context(), s.utilisateur)
		if err != nil {
			return err
		}
		lignes := []ligneCorbeille{}
		for _, n := range l {
			lignes = append(lignes, ligneCorbeille{N: n, Debut: heureWeb(n.Debut, n.decalage), Definitive: dateFrancaise(*n.SupprimeeDefinitivementLe, n.decalage)})
		}
		d.Titre, d.D = "Corbeille", lignes
		a.rendre(w, "corbeille.html", d)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/corbeille/{id}/restauration", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		if _, err := a.restaurer(r.Context(), s.utilisateur, r.PathValue("id")); err != nil {
			return err
		}
		http.Redirect(w, r, c+"/corbeille?ok=restauree", http.StatusSeeOther)
		return nil
	}))
	mux.HandleFunc("POST "+c+"/navigations/{id}/suppression", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		if err := a.mettreALaCorbeille(r.Context(), s, r.PathValue("id")); err != nil {
			return err
		}
		http.Redirect(w, r, c+"/corbeille?ok=corbeille", http.StatusSeeOther)
		return nil
	}))
}
