package main

import (
	"context"
	"errors"
	"net/http"
	"sort"
	"time"

	"github.com/jackc/pgx/v5"
)

// Quota et clôture automatique (TODO-4.6) : RG-ECO-01 à RG-ECO-05,
// RG-ECO-09, RG-ECO-12, RG-NAV-07, RG-NAV-15, RG-NAV-21. Le quota est
// calculé par le serveur, à la minute, sur les heures enregistrées par le
// téléphone (jamais sur les heures modifiées ensuite), pour le compte comme
// navigateur seulement, navigations de la corbeille comprises. Chaque
// minute consommée redevient disponible 7 jours après.

const (
	quotaMinutes = 24 * 60            // RG-ECO-01
	fenetreQuota = 7 * 24 * time.Hour // jours glissants
	delaiCloture = 24 * time.Hour     // RG-ECO-05
	pasDuQuota   = time.Minute
	horizonQuota = fenetreQuota + pasDuQuota
)

// intervalle : navigation du compte, [debut, fin) ; fin nulle : en cours.
type intervalle struct {
	id    string
	debut time.Time
	fin   *time.Time
}

// minutesConsommees : minutes de [i.debut, i.fin) encore décomptées à
// l'instant t : la minute commencée à m l'est de m à m + 7 jours.
func (i intervalle) minutesConsommees(t time.Time) int {
	t = t.Truncate(pasDuQuota)
	debut := i.debut.Truncate(pasDuQuota)
	fin := t
	if i.fin != nil && i.fin.Truncate(pasDuQuota).Before(t) {
		fin = i.fin.Truncate(pasDuQuota)
	}
	if bas := t.Add(-fenetreQuota + pasDuQuota); debut.Before(bas) {
		debut = bas
	}
	if !fin.After(debut) {
		return 0
	}
	return int(fin.Sub(debut) / pasDuQuota)
}

func consommation(navs []intervalle, t time.Time) int {
	total := 0
	for _, n := range navs {
		if !n.debut.After(t) {
			total += n.minutesConsommees(t)
		}
	}
	return total
}

// intervallesDe : navigations du compte comme navigateur (RG-ECO-03),
// corbeille comprise (RG-NAV-21), qui touchent la fenêtre glissante.
func (a *app) intervallesDe(ctx context.Context, utilisateur string, t time.Time) ([]intervalle, error) {
	lignes, err := a.b.pool.Query(ctx, `SELECT id, debut_enregistre, fin_enregistree FROM navigations
		WHERE navigateur_id = $1 AND (fin_enregistree IS NULL OR fin_enregistree > $2) ORDER BY debut_enregistre`,
		utilisateur, t.Add(-horizonQuota))
	if err != nil {
		return nil, err
	}
	defer lignes.Close()
	var navs []intervalle
	for lignes.Next() {
		var n intervalle
		if err := lignes.Scan(&n.id, &n.debut, &n.fin); err != nil {
			return nil, err
		}
		navs = append(navs, n)
	}
	return navs, lignes.Err()
}

type abonnementJSON struct {
	Actif bool       `json:"actif"`
	Canal *string    `json:"canal"`
	Debut *time.Time `json:"debut"`
	Fin   *time.Time `json:"fin"`
}

// abonnement : un seul état par compte, quel que soit le canal (RG-ECO-07) ;
// actif de son début à sa fin, 10 ans après (RG-ECO-06). Souscription par
// Google Play et l'App Store : achats.go ; par Stripe sur le Web : stripe.go.
func (a *app) abonnement(ctx context.Context, utilisateur string, t time.Time) (abonnementJSON, error) {
	var ab abonnementJSON
	err := a.b.pool.QueryRow(ctx, "SELECT canal, debut, fin FROM abonnements WHERE utilisateur_id = $1", utilisateur).
		Scan(&ab.Canal, &ab.Debut, &ab.Fin)
	if errors.Is(err, pgx.ErrNoRows) {
		return abonnementJSON{}, nil
	}
	ab.Actif = err == nil && !ab.Debut.After(t) && ab.Fin.After(t)
	return ab, err
}

type prochainesJSON struct {
	Minutes       int       `json:"minutes"`
	DisponiblesLe time.Time `json:"disponiblesLe"`
}

type quotaJSON struct {
	ConsommeMinutes      int              `json:"consommeMinutes"`
	DisponibleMinutes    int              `json:"disponibleMinutes"`
	ProchainesMinutes    []prochainesJSON `json:"prochainesMinutes"`
	Epuise               bool             `json:"epuise"`
	ClotureAutomatiqueLe *time.Time       `json:"clotureAutomatiqueLe"`
	Abonnement           abonnementJSON   `json:"abonnement"`
}

// quota : GET /v1/quota (RG-ECO-09). Prochaines minutes : pour chaque
// navigation encore décomptée, ses minutes et l'heure à partir de laquelle
// elles redeviennent disponibles, minute par minute.
func (a *app) quota(ctx context.Context, utilisateur string) (quotaJSON, error) {
	t := a.maintenant()
	q := quotaJSON{ProchainesMinutes: []prochainesJSON{}}
	navs, err := a.intervallesDe(ctx, utilisateur, t)
	if err != nil {
		return q, err
	}
	if q.Abonnement, err = a.abonnement(ctx, utilisateur, t); err != nil {
		return q, err
	}
	q.ConsommeMinutes = consommation(navs, t)
	q.DisponibleMinutes = max(0, quotaMinutes-q.ConsommeMinutes)
	q.Epuise = q.ConsommeMinutes >= quotaMinutes && !q.Abonnement.Actif
	for _, n := range navs {
		if m := n.minutesConsommees(t); m > 0 {
			debut := n.debut.Truncate(pasDuQuota)
			if bas := t.Truncate(pasDuQuota).Add(-fenetreQuota + pasDuQuota); debut.Before(bas) {
				debut = bas
			}
			q.ProchainesMinutes = append(q.ProchainesMinutes, prochainesJSON{m, debut.Add(fenetreQuota).UTC()})
		}
	}
	sort.Slice(q.ProchainesMinutes, func(i, j int) bool {
		return q.ProchainesMinutes[i].DisponiblesLe.Before(q.ProchainesMinutes[j].DisponiblesLe)
	})
	if err := a.b.pool.QueryRow(ctx, `SELECT min(epuise_le) + interval '24 hours' FROM navigations
		WHERE navigateur_id = $1 AND fin_enregistree IS NULL`, utilisateur).Scan(&q.ClotureAutomatiqueLe); err != nil {
		return q, err
	}
	return q, nil
}

// erreurQuota : quota_epuise, avec l'heure à laquelle des minutes
// redeviennent disponibles (RG-ECO-04).
type erreurQuota struct {
	*erreurAPI
	disponibleLe time.Time
}

func (e *erreurQuota) Unwrap() error { return e.erreurAPI }

// verifierQuotaAuDemarrage : démarrage refusé si le quota est épuisé et le
// compte sans abonnement actif (RG-NAV-07, RG-ECO-04).
func (a *app) verifierQuotaAuDemarrage(ctx context.Context, utilisateur string) error {
	t := a.maintenant()
	ab, err := a.abonnement(ctx, utilisateur, t)
	if err != nil || ab.Actif {
		return err
	}
	navs, err := a.intervallesDe(ctx, utilisateur, t)
	if err != nil {
		return err
	}
	if consommation(navs, t) < quotaMinutes {
		return nil
	}
	// Première minute où le décompte repasse sous le quota (au plus 7 jours).
	dispo := t.Truncate(pasDuQuota)
	for fin := dispo.Add(horizonQuota); dispo.Before(fin) && consommation(navs, dispo) >= quotaMinutes; dispo = dispo.Add(pasDuQuota) {
	}
	return &erreurQuota{&erreurAPI{http.StatusConflict, "quota_epuise",
		"Votre quota gratuit de 24 heures sur 7 jours est épuisé. Abonnez-vous, ou attendez que des minutes redeviennent disponibles.", 0}, dispo}
}

// cloturesAutomatiques : tâche de chaque minute (RG-ECO-05, RG-NAV-15).
// Pour chaque navigation en cours d'un compte sans abonnement actif : heure
// d'épuisement du quota (première minute où le décompte atteint 24 heures),
// puis clôture 24 heures après, à cette heure-là. Un abonnement souscrit
// entre-temps annule la clôture. Le quota redevenu disponible pendant ces
// 24 heures ne l'annule pas (RG-ECO-05, D-112).
func (a *app) cloturesAutomatiques(ctx context.Context) error {
	t := a.maintenant()
	lignes, err := a.b.pool.Query(ctx, `SELECT id, navigateur_id, debut_enregistre, epuise_le FROM navigations
		WHERE fin_enregistree IS NULL`)
	if err != nil {
		return err
	}
	type enCours struct {
		id, navigateur string
		debut          time.Time
		epuise         *time.Time
	}
	var liste []enCours
	for lignes.Next() {
		var n enCours
		if err := lignes.Scan(&n.id, &n.navigateur, &n.debut, &n.epuise); err != nil {
			lignes.Close()
			return err
		}
		liste = append(liste, n)
	}
	lignes.Close()
	for _, n := range liste {
		ab, err := a.abonnement(ctx, n.navigateur, t)
		if err != nil {
			return err
		}
		if ab.Actif {
			if n.epuise != nil {
				if _, err := a.b.pool.Exec(ctx, "UPDATE navigations SET epuise_le = NULL WHERE id = $1", n.id); err != nil {
					return err
				}
			}
			continue
		}
		if n.epuise == nil {
			navs, err := a.intervallesDe(ctx, n.navigateur, n.debut.Add(-horizonQuota))
			if err != nil {
				return err
			}
			for m := n.debut.Truncate(pasDuQuota); !m.After(t); m = m.Add(pasDuQuota) {
				if consommation(navs, m) >= quotaMinutes {
					epuise := m
					n.epuise = &epuise
					break
				}
			}
			if n.epuise == nil {
				continue
			}
			if _, err := a.b.pool.Exec(ctx, "UPDATE navigations SET epuise_le = $2 WHERE id = $1 AND epuise_le IS NULL",
				n.id, *n.epuise); err != nil {
				return err
			}
		}
		if cloture := n.epuise.Add(delaiCloture); !t.Before(cloture) {
			if _, err := a.b.pool.Exec(ctx, `UPDATE navigations SET fin_enregistree = $2, fin = $2, cloture_automatique_le = $2,
				version = version + 1, modifiee_le = now() WHERE id = $1 AND fin_enregistree IS NULL`, n.id, cloture); err != nil {
				return err
			}
		}
	}
	return nil
}

func (a *app) routesQuota(mux *http.ServeMux, v string) {
	mux.HandleFunc("GET "+v+"/quota", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		q, err := a.quota(r.Context(), s.utilisateur)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, q)
		return nil
	}))
}
