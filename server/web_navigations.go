package main

import (
	"context"
	"math"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// Tableau de bord de l'Application web (TODO-6.1, cahier des charges 6.1,
// D-23) : page ouverte dès la connexion (demande du 2026-11-26) ; en haut les
// navigations en cours, les miennes et celles que je suis ; en dessous
// l'historique, de la plus récente à la plus ancienne, filtrable « comme
// navigateur » / « comme suiveur » ; pour chacune nom, bateau, date et heure
// de départ, lieux de départ et d'arrivée, durée, distance (RG-NAV-16) ;
// aperçu au survol sur ordinateur, au toucher sur mobile (CSS seul).

// heureWeb : heure affichée sur l'Application web et dans le PDF : heure
// locale du téléphone du navigateur, puis UTC (RG-PRM-07, D-151).
func heureWeb(t time.Time, decalage *int) string {
	return heureEnvoyee(t, decalage, true)
}

// dureeTexte : « 45 min », « 3 h 05 », « 2 j 4 h 05 ».
func dureeTexte(minutes int) string {
	j, h, m := minutes/1440, minutes%1440/60, minutes%60
	switch {
	case j > 0:
		return strconv.Itoa(j) + " j " + strconv.Itoa(h) + " h " + deuxChiffres(m)
	case h > 0:
		return strconv.Itoa(h) + " h " + deuxChiffres(m)
	}
	return strconv.Itoa(m) + " min"
}

func deuxChiffres(n int) string {
	if n < 10 {
		return "0" + strconv.Itoa(n)
	}
	return strconv.Itoa(n)
}

// decimal : 12.34 → « 12,3 ».
func decimal(v float64, chiffres int) string {
	return strings.Replace(strconv.FormatFloat(v, 'f', chiffres, 64), ".", ",", 1)
}

// distanceTexte : distance en kilomètres et en milles marins.
func distanceTexte(metres float64) string {
	return decimal(metres/1000, 1) + " km (" + decimal(metres/1852, 1) + " milles)"
}

// coordonnees : « 47,3456 N, 3,1234 O ».
func coordonnees(p positionJSON) string {
	ns, eo := "N", "E"
	if p.Latitude < 0 {
		ns = "S"
	}
	if p.Longitude < 0 {
		eo = "O"
	}
	return decimal(math.Abs(p.Latitude), 4) + " " + ns + ", " + decimal(math.Abs(p.Longitude), 4) + " " + eo
}

// lieuTexte : nom du lieu le plus proche, sinon ses coordonnées (RG-NAV-16,
// RG-JRN-10).
func lieuTexte(l *lieuJSON) string {
	switch {
	case l == nil:
		return ""
	case l.Nom != nil && *l.Nom != "":
		return *l.Nom
	case l.Position != nil:
		return coordonnees(*l.Position)
	}
	return ""
}

// ligneNav : une navigation du tableau de bord.
type ligneNav struct {
	N                navigationJSON
	Depart, Fin      string
	LieuDepart       string
	LieuArrivee      string
	Duree, Distance  string
	Derniere, HeureD string
	Apercu           *carte
}

type donneesTableau struct {
	EnCours, Historique []ligneNav
	Role                string // filtre de l'historique : "", navigateur ou suiveur
	Suivant             int    // décalage de la page suivante de l'historique, 0 sans suite
}

// traceDe : positions non masquées d'une navigation, dans l'ordre
// d'acquisition (RG-JRN-03, RG-NAV-22).
func (a *app) traceDe(ctx context.Context, n navigationJSON) ([]pointCarte, error) {
	lignes, err := a.b.pool.Query(ctx, `SELECT heure_acquisition, latitude, longitude FROM evenements
		WHERE navigation_id = $1 AND latitude IS NOT NULL AND supprime_le IS NULL
		ORDER BY heure_acquisition, numero_ordre NULLS LAST`, n.ID)
	if err != nil {
		return nil, err
	}
	defer lignes.Close()
	plage := navLigne{debut: n.Debut, fin: n.Fin}
	var l []pointCarte
	for lignes.Next() {
		var h time.Time
		var p pointCarte
		if err := lignes.Scan(&h, &p.Latitude, &p.Longitude); err != nil {
			return nil, err
		}
		if !plage.masque(h) {
			p.Sorte = "position"
			l = append(l, p)
		}
	}
	return l, lignes.Err()
}

// ligneDe : présentation d'une navigation, avec l'aperçu (tracé seul, sans
// dalles : le tableau de bord ne charge aucune image de carte).
func (a *app) ligneDe(ctx context.Context, n navigationJSON) (ligneNav, error) {
	l := ligneNav{N: n, Depart: heureWeb(n.Debut, n.decalage), LieuDepart: lieuTexte(n.LieuDepart),
		LieuArrivee: lieuTexte(n.LieuArrivee), Duree: dureeTexte(n.DureeMinutes), Distance: distanceTexte(n.DistanceMetres)}
	if n.Fin != nil {
		l.Fin = heureWeb(*n.Fin, n.decalage)
	}
	if d := n.DernierePosition; d != nil && d.Position != nil {
		l.Derniere, l.HeureD = lieuTexte(d), heureWeb(d.Position.HeureAcquisition, n.decalage)
	}
	trace, err := a.traceDe(ctx, n)
	if err != nil {
		return l, err
	}
	var marques []pointCarte
	if len(trace) > 0 {
		marques = append(marques, pointCarte{Latitude: trace[0].Latitude, Longitude: trace[0].Longitude, Sorte: "depart", Titre: "Départ"})
		der := trace[len(trace)-1]
		sorte, titre := "arrivee", "Arrivée"
		if n.Etat == "en_cours" {
			sorte, titre = "derniere", "Dernière position"
		}
		marques = append(marques, pointCarte{Latitude: der.Latitude, Longitude: der.Longitude, Sorte: sorte, Titre: titre})
	}
	l.Apercu = cadrer(trace, marques, 320, 200, false)
	return l, nil
}

func (a *app) lignesDe(ctx context.Context, navs []navigationJSON) ([]ligneNav, error) {
	l := []ligneNav{}
	for _, n := range navs {
		x, err := a.ligneDe(ctx, n)
		if err != nil {
			return nil, err
		}
		l = append(l, x)
	}
	return l, nil
}

// tableauDeBord : données de la page d'accueil d'un utilisateur connecté.
func (a *app) tableauDeBord(ctx context.Context, utilisateur, role string, decalage int) (donneesTableau, error) {
	if role != "navigateur" && role != "suiveur" {
		role = ""
	}
	d := donneesTableau{Role: role}
	if decalage == 0 {
		enCours, _, err := a.navigations(ctx, utilisateur, "", "en_cours", "", 0)
		if err != nil {
			return d, err
		}
		if d.EnCours, err = a.lignesDe(ctx, enCours); err != nil {
			return d, err
		}
	}
	hist, suivant, err := a.navigations(ctx, utilisateur, role, "terminee", "", decalage)
	if err != nil {
		return d, err
	}
	d.Suivant = suivant
	d.Historique, err = a.lignesDe(ctx, hist)
	return d, err
}

func (a *app) pageTableau(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
	var err error
	if d.Annonces, err = a.annonces(r.Context(), s.utilisateur); err != nil {
		return err
	}
	decalage, _ := strconv.Atoi(r.URL.Query().Get("curseur"))
	t, err := a.tableauDeBord(r.Context(), s.utilisateur, r.URL.Query().Get("role"), max(0, decalage))
	if err != nil {
		return err
	}
	d.Titre, d.D = "Tableau de bord", t
	a.rendre(w, "tableau.html", d)
	return nil
}
