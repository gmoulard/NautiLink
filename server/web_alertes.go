package main

import (
	"context"
	"net/http"
)

// Pages « Alertes SOS » et « Assistance » de la gestion du compte
// (TODO-6.5, cahier des charges 6.3), comme sur l'application mobile
// (TODO-5.7). Historique des alertes (RG-SOS-12, RG-SOS-13) : celles du
// navigateur et, pour un suiveur, celles qu'il voit (RG-PAR-07, RG-SOS-20),
// avec la position transmise (RG-SOS-09 à RG-SOS-11), le statut de chaque
// SMS et les e-mails envoyés ; heures au format de RG-PRM-07, dans le fuseau
// du déclenchement. Assistance : « Écrire à l'équipe NautiLink »
// (RG-COM-09), avertissement bêta et sa date d'acceptation (RG-CPT-07),
// mémo sécurité en mer du site (RG-SOS-22).

const (
	adresseEquipe = "https://github.com/gmoulard/NautiLink/issues" // RG-COM-09, D-138
	adresseMemo   = "https://gmoulard.github.io/NautiLink/securite.html"
	// Prévision marine de Météo-France (RG-NAV-37, D-166), adresse vérifiée
	// le 2026-11-26 ; ouverture sur la position actuelle : Q-103.
	adresseMeteoMarine = "https://meteofrance.com/meteo-marine"
)

var libellesStatutSms = map[string]string{
	"en_attente": "en attente", "accepte_pour_envoi": "accepté pour envoi",
	"livraison_confirmee": "livraison confirmée", "echec": "échec",
}

type ligneSms struct {
	Telephone, Statut string
	Second            bool
}

type ligneHistoriqueSos struct {
	A                  alerteSosJSON
	Heure, Position    string
	Bateau, Navigateur string
	Mienne             bool
	Nature             string
	Sms                []ligneSms
}

// historiqueSos : alertes visibles de l'utilisateur, de la plus récente à
// la plus ancienne, avec le bateau, le navigateur et le fuseau de chacune.
func (a *app) historiqueSos(ctx context.Context, utilisateur string) ([]ligneHistoriqueSos, error) {
	l, err := a.alertes(ctx, utilisateur, "", "")
	if err != nil {
		return nil, err
	}
	lignes := []ligneHistoriqueSos{}
	for _, al := range l {
		h := ligneHistoriqueSos{A: al}
		var decalage *int
		var navigateur string
		if err := a.b.pool.QueryRow(ctx, `SELECT b.nom, u.nom, u.id::text, al.decalage_minutes FROM alertes_sos al
			JOIN bateaux b ON b.id = al.bateau_id JOIN utilisateurs u ON u.id = al.navigateur_id
			WHERE al.id = $1`, al.ID).Scan(&h.Bateau, &h.Navigateur, &navigateur, &decalage); err != nil {
			return nil, err
		}
		h.Mienne = navigateur == utilisateur
		h.Heure = heureWeb(al.HeureDeclenchement, decalage)
		switch al.NaturePosition {
		case "actuelle":
			h.Nature = "position actuelle"
		case "derniere_connue":
			h.Nature = "dernière position connue, pas nécessairement la position actuelle"
		default:
			h.Nature = "GPS indisponible, aucune position connue"
		}
		if al.Position != nil {
			h.Position = coordonnees(*al.Position) + ", " + heureWeb(al.Position.HeureAcquisition, decalage)
		}
		for _, s := range al.Sms {
			h.Sms = append(h.Sms, ligneSms{Telephone: s.Telephone, Statut: libellesStatutSms[s.Statut], Second: s.Rang > 1})
		}
		lignes = append(lignes, h)
	}
	return lignes, nil
}

type donneesAssistance struct {
	Equipe, Memo string
	Profil       profilJSON
	AccepteLe    string
}

func (a *app) routesWebAlertes(mux *http.ServeMux, c string) {
	mux.HandleFunc("GET "+c+"/alertes-sos", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		l, err := a.historiqueSos(r.Context(), s.utilisateur)
		if err != nil {
			return err
		}
		d.Titre, d.D = "Alertes SOS", l
		a.rendre(w, "alertes.html", d)
		return nil
	}))
	mux.HandleFunc("GET "+c+"/assistance", a.web(true, func(w http.ResponseWriter, r *http.Request, s *session, d *donneesPage) error {
		p, err := a.profil(r.Context(), s.utilisateur)
		if err != nil {
			return err
		}
		d.Titre = "Assistance"
		d.D = donneesAssistance{Equipe: adresseEquipe, Memo: adresseMemo, Profil: p,
			AccepteLe: dateFrancaise(p.AvertissementAccepteLe, nil)}
		a.rendre(w, "assistance.html", d)
		return nil
	}))
}
