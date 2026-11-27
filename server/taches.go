package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// tachesDeFond : traitements faits par le serveur seul (x-traitements de
// docs/api/openapi.yaml), chaque minute : clôture automatique (TODO-4.6),
// relance des e-mails SOS en échec (TODO-4.7, RG-SOS-18), purge de la
// corbeille (TODO-4.8), météo du départ et de l'arrivée (TODO-4.10) ; et
// noms des lieux par Nominatim.
func (a *app) tachesDeFond(ctx context.Context) {
	if a.cfg.Nominatim != "" {
		go a.nommerLesLieux(ctx)
	}
	minute := time.NewTicker(time.Minute)
	defer minute.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-minute.C:
		}
		if !a.b.prete() {
			continue
		}
		for _, t := range a.tachesMinute() {
			if err := t(ctx); err != nil {
				log.Printf("tâche de fond : %v", err)
			}
		}
	}
}

// tachesMinute : tâches jouées chaque minute, dans cet ordre.
func (a *app) tachesMinute() []func(context.Context) error {
	return []func(context.Context) error{a.cloturesAutomatiques, a.purgerLaCorbeille, a.relancerEmailsSos, a.positionsEnRetard, a.relevesMeteo}
}

// ------------------------------------------------------------------ lieux

// Géocodage inverse (RG-NAV-16, RG-JRN-10) par Nominatim d'OpenStreetMap,
// avec un cache des noms (D-96) : positions arrondies au millième de degré
// (environ 100 mètres), une requête par seconde au plus (règle d'usage de
// Nominatim). Sans nom trouvé, les coordonnées en tiennent lieu.

func cleLieu(lat, lon float64) (int, int) {
	return int(math.Round(lat * 1000)), int(math.Round(lon * 1000))
}

func (a *app) nommerLesLieux(ctx context.Context) {
	client := &http.Client{Timeout: 10 * time.Second}
	for {
		if a.b.prete() {
			if n, err := a.nommerUnLot(ctx, client); err != nil {
				log.Printf("noms de lieux : %v", err)
			} else if n > 0 {
				continue
			}
		}
		select {
		case <-ctx.Done():
			return
		case <-time.After(15 * time.Second):
		}
	}
}

// nommerUnLot : nomme jusqu'à 20 positions sans nom ; rend leur nombre.
func (a *app) nommerUnLot(ctx context.Context, client *http.Client) (int, error) {
	lignes, err := a.b.pool.Query(ctx, `SELECT id, latitude, longitude FROM evenements
		WHERE latitude IS NOT NULL AND NOT lieu_cherche ORDER BY recu_le LIMIT 20`)
	if err != nil {
		return 0, err
	}
	type aNommer struct {
		id       string
		lat, lon float64
	}
	var liste []aNommer
	for lignes.Next() {
		var x aNommer
		if err := lignes.Scan(&x.id, &x.lat, &x.lon); err != nil {
			lignes.Close()
			return 0, err
		}
		liste = append(liste, x)
	}
	lignes.Close()
	for _, x := range liste {
		nom, err := a.nomDuLieu(ctx, client, x.lat, x.lon)
		if err != nil {
			return 0, err // réessayé au tour suivant
		}
		if _, err := a.b.pool.Exec(ctx, `UPDATE evenements SET lieu = $2, lieu_cherche = true,
			modification = nextval('modifications') WHERE id = $1`, x.id, nom); err != nil {
			return 0, err
		}
	}
	return len(liste), nil
}

func (a *app) nomDuLieu(ctx context.Context, client *http.Client, lat, lon float64) (*string, error) {
	la, lo := cleLieu(lat, lon)
	var nom *string
	if err := a.b.pool.QueryRow(ctx, "SELECT nom FROM lieux WHERE latitude = $1 AND longitude = $2", la, lo).Scan(&nom); err == nil {
		return nom, nil
	}
	time.Sleep(time.Second)
	q := url.Values{"format": {"jsonv2"}, "lat": {fmt.Sprintf("%.3f", float64(la)/1000)},
		"lon": {fmt.Sprintf("%.3f", float64(lo)/1000)}, "zoom": {"14"}, "accept-language": {"fr"}}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, a.cfg.Nominatim+"/reverse?"+q.Encode(), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", "NautiLink/"+version)
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("Nominatim : %s", resp.Status)
	}
	var r struct {
		Name        string `json:"name"`
		DisplayName string `json:"display_name"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&r); err != nil {
		return nil, err
	}
	if t := strings.TrimSpace(r.Name); t != "" {
		nom = &t
	} else if t, _, _ := strings.Cut(r.DisplayName, ","); strings.TrimSpace(t) != "" {
		t = strings.TrimSpace(t)
		nom = &t
	}
	_, err = a.b.pool.Exec(ctx, "INSERT INTO lieux (latitude, longitude, nom) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING", la, lo, nom)
	return nom, err
}
