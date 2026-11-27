package main

import (
	"context"
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"testing"
	"time"
)

// fauxMeteoFrance : jeton OAuth2, AROME (WCS, petite grille en GRIB2 simple)
// et MFWAM (fichier GRIB2 CCSDS de testdata/), tels que décrits par l'étude
// docs/etudes/meteofrance-connexion.md § 9.1.
type fauxMeteoFrance struct {
	mu          sync.Mutex
	jetons      int
	refuser     bool // 503 partout
	runPublie   string
	appels      []string
	jetonPerime bool   // le premier appel avec le premier jeton rend 401
	cle         string // clé d'API acceptée, avec l'en-tête enteteCle
	enteteCle   string // « apikey » (par défaut) ou « Authorization » (Bearer)
}

func (f *fauxMeteoFrance) serveur(t *testing.T) *httptest.Server {
	vagues, err := os.ReadFile("testdata/mfwam-essai-ccsds.grib2")
	if err != nil {
		t.Fatal(err)
	}
	s := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		f.mu.Lock()
		defer f.mu.Unlock()
		f.appels = append(f.appels, r.URL.Path+"?"+r.URL.RawQuery)
		if f.refuser {
			http.Error(w, "indisponible", http.StatusServiceUnavailable)
			return
		}
		if r.URL.Path == "/token" {
			if r.Method != http.MethodPost || r.Header.Get("Authorization") != "Basic aWQ6c2VjcmV0" || r.FormValue("grant_type") != "client_credentials" {
				http.Error(w, "refusé", http.StatusUnauthorized)
				return
			}
			f.jetons++
			json.NewEncoder(w).Encode(map[string]any{"access_token": "jeton" + string(rune('0'+f.jetons)), "expires_in": 3600})
			return
		}
		jeton := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		cleOK := f.cle != "" && ((f.enteteCle == "" && r.Header.Get("apikey") == f.cle) ||
			(f.enteteCle == "Authorization" && jeton == f.cle))
		if r.URL.Path == "/vagues" && (cleOK || strings.HasPrefix(jeton, "jeton")) {
			w.Write([]byte(`["0.025","0.1"]`))
			return
		}
		if !cleOK && (!strings.HasPrefix(jeton, "jeton") || (f.jetonPerime && jeton == "jeton1")) {
			http.Error(w, "jeton", http.StatusUnauthorized)
			return
		}
		switch {
		case r.URL.Path == "/arome":
			q := r.URL.Query()
			id := q.Get("coverageid")
			if !strings.HasSuffix(id, "___"+f.runPublie) || q.Get("format") != "application/wmo-grib" {
				http.Error(w, "couverture inconnue", http.StatusNotFound)
				return
			}
			var v float64
			var num, cat int
			switch {
			case strings.HasPrefix(id, "U_COMPONENT_OF_WIND__"):
				v, cat, num = -3, 2, 2 // vent de l'est-nord-est : u < 0
			case strings.HasPrefix(id, "V_COMPONENT_OF_WIND__"):
				v, cat, num = -1, 2, 3
			case strings.HasPrefix(id, "PRESSURE__MEAN_SEA_LEVEL"):
				v, cat, num = 101643, 3, 1
			default:
				http.Error(w, "couverture inconnue", http.StatusNotFound)
				return
			}
			vals := make([]float64, 9)
			for i := range vals {
				vals[i] = v
			}
			// grille de 3 × 3 points à 0,01° autour du centre de la zone demandée
			la, lo := 47.55, -3.55
			for _, sub := range q["subset"] {
				var x, y float64
				if n, _ := fmt.Sscanf(sub, "lat(%f,%f)", &x, &y); n == 2 {
					la = (x + y) / 2
				} else if n, _ := fmt.Sscanf(sub, "long(%f,%f)", &x, &y); n == 2 {
					lo = (x + y) / 2
				}
			}
			w.Write(grib2Simple(0, cat, num, 3, 3, la+0.01, lo-0.01, 0.01, vals, 0))
		case strings.HasPrefix(r.URL.Path, "/vagues/0.025/packages/SP1/productMFWAM"), strings.HasPrefix(r.URL.Path, "/vagues/0.1/packages/SP1/productMFWAM"):
			if r.URL.Query().Get("format") != "grib2" || !strings.HasSuffix(r.URL.Query().Get("time"), "H") {
				http.Error(w, "paramètres", http.StatusBadRequest)
				return
			}
			w.Write(vagues)
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(s.Close)
	return s
}

func meteoEssai(t *testing.T, f *fauxMeteoFrance) *meteoFrance {
	s := f.serveur(t)
	m := nouvelleMeteoFrance(config{MeteoFrance: "aWQ6c2VjcmV0"})
	m.jetonURL, m.aromeURL, m.vaguesURL, m.pause = s.URL+"/token", s.URL+"/arome", s.URL+"/vagues/", 0
	return m
}

// TestReleverMeteo : RG-NAV-28 : vent et pression d'AROME, état de la mer de
// MFWAM au point ; calcul AROME le plus récent publié cherché en remontant ;
// jeton redemandé après un refus 401 (RG-NAV-38).
func TestReleverMeteo(t *testing.T) {
	h := time.Date(2026, 11, 26, 23, 10, 0, 0, time.UTC)
	f := &fauxMeteoFrance{runPublie: "2026-11-26T18.00.00Z", jetonPerime: true}
	m := meteoEssai(t, f)
	r, complet := m.relever(context.Background(), 47.55, -3.55, h, h)
	if !complet || r.Indisponible {
		t.Fatalf("relevé incomplet : %+v %v", r, f.appels)
	}
	if !r.HeurePrevision.Equal(time.Date(2026, 11, 26, 23, 0, 0, 0, time.UTC)) || r.Source != "Météo-France" {
		t.Errorf("heure ou source : %+v", r)
	}
	if r.VentVitesseNoeuds == nil || math.Abs(*r.VentVitesseNoeuds-6.1) > 0.05 || r.VentDirectionDegres == nil || *r.VentDirectionDegres != 72 {
		t.Errorf("vent : %v %v", r.VentVitesseNoeuds, r.VentDirectionDegres)
	}
	if r.PressionHpa == nil || *r.PressionHpa != 1016.4 {
		t.Errorf("pression : %v", r.PressionHpa)
	}
	if r.HauteurVaguesMetres == nil || *r.HauteurVaguesMetres <= 0 || r.EtatMer == "" {
		t.Errorf("vagues : %v %q", r.HauteurVaguesMetres, r.EtatMer)
	}
	if f.jetons != 2 {
		t.Errorf("%d jetons demandés, 2 attendus (refus 401)", f.jetons)
	}
	if !strings.Contains(strings.Join(f.appels, "\n"), "subset=height%2810%29") {
		t.Errorf("vent sans hauteur de 10 m : %v", f.appels)
	}
	// second relevé : calcul AROME connu essayé en premier, fichier MFWAM gardé en mémoire
	n := len(f.appels)
	if _, complet := m.relever(context.Background(), 47.56, -3.54, h, h); !complet {
		t.Fatal("second relevé incomplet")
	}
	if got := len(f.appels) - n; got != 3 {
		t.Errorf("second relevé : %d appels, 3 attendus (U, V, pression) : %v", got, f.appels[n:])
	}

	// Météo-France en panne : relevé incomplet, rien d'obtenu
	f.refuser = true
	m2 := meteoEssai(t, &fauxMeteoFrance{refuser: true})
	if r, complet := m2.relever(context.Background(), 47.55, -3.55, h, h); complet || !r.Indisponible {
		t.Errorf("panne : %+v %v", r, complet)
	}
	// hors des domaines d'AROME et de la grille de vagues : rien n'est attendu
	m3 := meteoEssai(t, &fauxMeteoFrance{runPublie: "2026-11-26T18.00.00Z"})
	if r, complet := m3.relever(context.Background(), -30, 150, h, h); !complet || !r.Indisponible {
		t.Errorf("hors domaine : %+v %v", r, complet)
	}
}

func TestMeteoTexte(t *testing.T) {
	v, d, p, hv := 6.12, 72, 1016.4, 0.84
	b, _ := json.Marshal(meteoJSON{HeurePrevision: time.Date(2026, 11, 26, 23, 0, 0, 0, time.UTC), Source: "Météo-France",
		VentVitesseNoeuds: &v, VentDirectionDegres: &d, PressionHpa: &p, HauteurVaguesMetres: &hv, EtatMer: etatMerDouglas(hv)})
	if got, want := meteoTexte(b, nil), "Vent 6 nœuds d'est-nord-est (72°), mer peu agitée (0,8 m de vagues), pression 1016 hPa — prévision Météo-France pour "; !strings.HasPrefix(got, want) {
		t.Errorf("meteoTexte = %q", got)
	}
	b, _ = json.Marshal(meteoJSON{Indisponible: true})
	if got := meteoTexte(b, nil); got != "Météo indisponible" {
		t.Errorf("indisponible : %q", got)
	}
	if meteoTexte(nil, nil) != "" {
		t.Error("sans relevé : texte non vide")
	}
	for deg, want := range map[int]string{0: "du nord", 180: "du sud", 225: "du sud-ouest", 90: "d'est", 290: "d'ouest-nord-ouest", 359: "du nord"} {
		if got := directionCardinale(deg); got != want {
			t.Errorf("directionCardinale(%d) = %q, attendu %q", deg, got, want)
		}
	}
	for h, want := range map[float64]string{0.05: "calme, ridée", 0.3: "belle", 0.84: "peu agitée", 2: "agitée", 3: "forte", 15: "énorme"} {
		if got := etatMerDouglas(h); got != want {
			t.Errorf("etatMerDouglas(%v) = %q, attendu %q", h, got, want)
		}
	}
	if (&meteoFrance{}).actif() || (*meteoFrance)(nil).actif() {
		t.Error("sans NAUTILINK_METEOFRANCE : météo active")
	}
}

// TestRelevesMeteoBase : RG-NAV-28, RG-NAV-38 : météo du départ relevée et
// gardée avec la navigation, affichée sur sa page ; Météo-France en panne :
// nouvel essai pendant 1 heure, puis « Météo indisponible » ; la navigation
// n'est jamais bloquée.
func TestRelevesMeteoBase(t *testing.T) {
	e := nouvelEssai(t)
	f := &fauxMeteoFrance{}
	e.a.meteo = meteoEssai(t, f)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	t0 := time.Now().UTC().Truncate(time.Hour).Add(-20 * time.Minute)
	f.runPublie = t0.Truncate(3 * time.Hour).Add(-3 * time.Hour).Format("2006-01-02T15.04.05Z")
	horloge(e, t0.Add(time.Minute))
	id, code, _ := e.naviguer(nav, bateau, tel, t0, nil)
	if code != 201 {
		t.Fatalf("démarrage : %d", code)
	}
	// MFWAM du fichier d'essai : point de départ au milieu de sa grille
	if _, err := e.a.b.pool.Exec(t.Context(), "UPDATE evenements SET latitude = 47.62, longitude = -3.5 WHERE navigation_id = $1", id); err != nil {
		t.Fatal(err)
	}
	if err := e.a.relevesMeteo(t.Context()); err != nil {
		t.Fatal(err)
	}
	var brut []byte
	if err := e.a.b.pool.QueryRow(t.Context(), "SELECT meteo_depart FROM navigations WHERE id = $1", id).Scan(&brut); err != nil || brut == nil {
		t.Fatalf("météo du départ non relevée : %v %v", err, f.appels)
	}
	var m meteoJSON
	json.Unmarshal(brut, &m)
	if m.Indisponible || m.PressionHpa == nil || m.HauteurVaguesMetres == nil {
		t.Errorf("météo du départ : %s", brut)
	}
	_, r := e.appel("GET", "/navigations/"+id, nav, nil)
	if md, _ := r["meteoDepart"].(map[string]any); md == nil || md["source"] != "Météo-France" {
		t.Errorf("API : meteoDepart = %v", r["meteoDepart"])
	}

	// fin, Météo-France en panne : rien avant 1 heure, puis « indisponible »
	f.refuser = true
	e.a.meteo.champVagues = nil // fichier MFWAM en mémoire oublié : panne complète
	fin := t0.Add(30 * time.Minute)
	horloge(e, fin.Add(time.Minute))
	if c, x := e.appel("PUT", "/navigations/"+id+"/fin", nav, map[string]any{"id": uuid(t), "type": "fin", "heureAcquisition": heure(fin)}); c != 200 {
		t.Fatalf("fin bloquée : %d %v", c, x)
	}
	e.a.meteo.dernierPassage = time.Time{}
	e.a.relevesMeteo(t.Context())
	if n := e.compter("SELECT count(*) FROM navigations WHERE id = $1 AND meteo_arrivee IS NULL", id); n != 1 {
		t.Error("météo de l'arrivée écrite avant la fin des nouveaux essais")
	}
	horloge(e, fin.Add(61*time.Minute))
	e.a.meteo.dernierPassage = time.Time{}
	e.a.relevesMeteo(t.Context())
	if err := e.a.b.pool.QueryRow(t.Context(), "SELECT meteo_arrivee FROM navigations WHERE id = $1", id).Scan(&brut); err != nil || json.Unmarshal(brut, &m) != nil || !m.Indisponible {
		t.Fatalf("après 1 heure : %s %v", brut, err)
	}
	page := e.webConnecte("nav@exemple.org").envoyer("GET", "/nautilink/navigations/"+id, nil).Body.String()
	for _, attendu := range []string{"Météo au départ</dt><dd>Vent ", "Météo à l'arrivée</dt><dd>Météo indisponible"} {
		if !strings.Contains(page, attendu) {
			t.Errorf("page de la navigation : %q absent", attendu)
		}
	}
}
