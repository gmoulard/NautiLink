package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
)

// Météo du début et de la fin d'une navigation (RG-NAV-28, RG-NAV-38,
// TODO-4.10, D-172) : vent et pression du modèle AROME (service WCS de
// Météo-France, petite grille en GRIB2 autour du point), hors de son domaine
// du modèle ARPEGE, Europe à 0,1° puis Globe à 0,25° (même service WCS,
// TODO-4.12, D-181), état de la mer du
// modèle de vagues MFWAM (fichier GRIB2 CCSDS entier, lu au point de grille
// de mer le plus proche, grib2.go). Adresses et ressources : étude
// docs/etudes/meteofrance-connexion.md § 6 et § 9.1.

const (
	adresseJetonMeteoFrance = "https://portail-api.meteofrance.fr/token"
	adresseAromeWCS         = "https://public-api.meteofrance.fr/public/arome/1.0/wcs/MF-NWP-HIGHRES-AROME-001-FRANCE-WCS/GetCoverage"
	adresseArpegeEuropeWCS  = "https://public-api.meteofrance.fr/public/arpege/1.0/wcs/MF-NWP-GLOBAL-ARPEGE-01-EUROPE-WCS/GetCoverage"
	adresseArpegeGlobeWCS   = "https://public-api.meteofrance.fr/public/arpege/1.0/wcs/MF-NWP-GLOBAL-ARPEGE-025-GLOBE-WCS/GetCoverage"
	adresseVagues           = "https://public-api.meteofrance.fr/previnum/DPPaquetWAVESMODELS/v1/models/MFWAM/grids/"
	sourceMeteo             = "Météo-France"
	// delaiMeteo : nouveaux essais pendant 1 heure, puis « Météo
	// indisponible » (RG-NAV-38).
	delaiMeteo = time.Hour
	// intervalleMeteo : un passage de la tâche de relevé toutes les 5 minutes.
	intervalleMeteo = 5 * time.Minute
	noeudsParMs     = 3600.0 / 1852.0
)

// meteoJSON : météo relevée, gardée avec la navigation (colonnes
// meteo_depart et meteo_arrivee) et rendue par l'API (schéma Meteo).
type meteoJSON struct {
	ReleveeLe           time.Time `json:"releveeLe"`
	HeurePrevision      time.Time `json:"heurePrevision"`
	Source              string    `json:"source"`
	Indisponible        bool      `json:"indisponible,omitempty"`
	VentVitesseNoeuds   *float64  `json:"ventVitesseNoeuds,omitempty"`
	VentDirectionDegres *int      `json:"ventDirectionDegres,omitempty"`
	PressionHpa         *float64  `json:"pressionHpa,omitempty"`
	HauteurVaguesMetres *float64  `json:"hauteurVaguesMetres,omitempty"`
	EtatMer             string    `json:"etatMer,omitempty"`
}

// meteoFrance : client des API de Météo-France ; adresses remplacées dans
// les essais.
type meteoFrance struct {
	// Code d'accès (identifiant d'application encodé pour « Authorization:
	// Basic ») : celui posé dans l'espace administrateur l'emporte sur la
	// variable NAUTILINK_METEOFRANCE (RG-ADM-08, D-174).
	muCode              sync.RWMutex
	variable, reglage   string
	jetonURL, aromeURL  string
	arpegeEuropeURL     string
	arpegeGlobeURL      string
	vaguesURL           string
	client              *http.Client
	pause               time.Duration // entre deux appels (60 appels par minute au plus)
	mu                  sync.Mutex
	jeton, jetonPour    string // jetonPour : code qui a obtenu le jeton
	jetonFin            time.Time
	dernierPassage      time.Time
	cacheVagues         string // adresse du dernier fichier MFWAM lu
	champVagues         *champGRIB
	runArome, runVagues time.Time // dernier calcul trouvé, essayé en premier
	runArpege           map[string]time.Time
}

func nouvelleMeteoFrance(cfg config) *meteoFrance {
	return &meteoFrance{
		variable: cfg.MeteoFrance,
		jetonURL: adresseJetonMeteoFrance, aromeURL: adresseAromeWCS, vaguesURL: adresseVagues,
		arpegeEuropeURL: adresseArpegeEuropeWCS, arpegeGlobeURL: adresseArpegeGlobeWCS,
		client: &http.Client{Timeout: 90 * time.Second},
		pause:  time.Second,
	}
}

func (m *meteoFrance) actif() bool { return m != nil && m.identifiant() != "" }

// identifiant : code en service, celui de l'espace administrateur sinon
// celui de la variable.
func (m *meteoFrance) identifiant() string {
	m.muCode.RLock()
	defer m.muCode.RUnlock()
	if m.reglage != "" {
		return m.reglage
	}
	return m.variable
}

// poserReglage : code de l'espace administrateur ; vide : retour à la
// variable. Le jeton du code précédent n'est plus utilisé (jetonPour).
func (m *meteoFrance) poserReglage(v string) {
	m.muCode.Lock()
	m.reglage = v
	m.muCode.Unlock()
}

var (
	errMeteoIntrouvable = errors.New("Météo-France : ressource introuvable")
	// errCodeRefuse : Météo-France refuse le code d'accès (400, 401, 403).
	errCodeRefuse = errors.New("Météo-France refuse le code d'accès")
)

// obtenirJeton : jeton OAuth2 gardé en mémoire jusqu'à 5 minutes avant son
// expiration (étude § 6), ou jusqu'au changement du code.
func (m *meteoFrance) obtenirJeton(ctx context.Context, renouveler bool) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	code := m.identifiant()
	if !renouveler && m.jeton != "" && m.jetonPour == code && time.Now().Before(m.jetonFin) {
		return m.jeton, nil
	}
	jeton, duree, err := m.demanderJeton(ctx, code)
	if err != nil {
		return "", err
	}
	m.jeton, m.jetonPour, m.jetonFin = jeton, code, time.Now().Add(duree-5*time.Minute)
	return m.jeton, nil
}

// enteteCle : code d'accès qui est une clé d'API (jeton JWT donné par le
// portail, envoyé tel quel à chaque appel, sans passer par /token) : en-tête
// à poser ; forme gardée « apikey <clé> » ou « Bearer <clé> » (en-tête
// constaté à la vérification), ou la clé seule (en-tête « apikey »). Sinon :
// identifiant d'application, pour /token.
func enteteCle(code string) (nom, valeur string, cle bool) {
	switch {
	case strings.HasPrefix(code, "apikey "):
		return "apikey", code[len("apikey "):], true
	case strings.HasPrefix(code, "Bearer "):
		return "Authorization", code, true
	case estJWT(code):
		return "apikey", code, true
	}
	return "", "", false
}

// estJWT : trois parties en base64url séparées par des points, la première
// étant un en-tête JSON.
func estJWT(v string) bool {
	p := strings.Split(v, ".")
	if len(p) != 3 || p[0] == "" || p[1] == "" {
		return false
	}
	var t map[string]any
	b, err := base64.RawURLEncoding.DecodeString(strings.TrimRight(p[0], "="))
	return err == nil && json.Unmarshal(b, &t) == nil
}

// finJWT : date d'expiration (« exp ») d'une clé JWT ; zéro sans date.
func finJWT(v string) time.Time {
	p := strings.Split(v, ".")
	if len(p) != 3 {
		return time.Time{}
	}
	b, err := base64.RawURLEncoding.DecodeString(strings.TrimRight(p[1], "="))
	var c struct {
		Exp float64 `json:"exp"`
	}
	if err != nil || json.Unmarshal(b, &c) != nil || c.Exp <= 0 {
		return time.Time{}
	}
	return time.Unix(int64(c.Exp), 0).UTC()
}

// verifierCle : appel léger (liste des grilles MFWAM) avec la clé d'API et
// l'en-tête donnés ; errCodeRefuse si Météo-France la refuse.
func (m *meteoFrance) verifierCle(ctx context.Context, code string) error {
	nom, valeur, _ := enteteCle(code)
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimSuffix(m.vaguesURL, "/"), nil)
	if err != nil {
		return err
	}
	req.Header.Set(nom, valeur)
	req.Header.Set("User-Agent", "NautiLink/"+version)
	resp, err := m.client.Do(req)
	if err != nil {
		return err
	}
	io.Copy(io.Discard, io.LimitReader(resp.Body, 1<<20))
	resp.Body.Close()
	switch resp.StatusCode {
	case http.StatusUnauthorized, http.StatusForbidden:
		return fmt.Errorf("%w (%s)", errCodeRefuse, resp.Status)
	case http.StatusOK, http.StatusNotFound, http.StatusBadRequest:
		return nil // accès accepté (ressource absente : la clé est passée)
	}
	return fmt.Errorf("Météo-France : %s", resp.Status)
}

// demanderJeton : jeton OAuth2 demandé à Météo-France pour ce code, sans le
// garder ; errCodeRefuse si Météo-France refuse le code.
func (m *meteoFrance) demanderJeton(ctx context.Context, code string) (string, time.Duration, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, m.jetonURL,
		strings.NewReader(url.Values{"grant_type": {"client_credentials"}}.Encode()))
	if err != nil {
		return "", 0, err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Authorization", "Basic "+code)
	resp, err := m.client.Do(req)
	if err != nil {
		return "", 0, err
	}
	defer resp.Body.Close()
	switch resp.StatusCode {
	case http.StatusOK:
	case http.StatusBadRequest, http.StatusUnauthorized, http.StatusForbidden:
		return "", 0, fmt.Errorf("%w (%s)", errCodeRefuse, resp.Status)
	default:
		return "", 0, fmt.Errorf("Météo-France, jeton : %s", resp.Status)
	}
	var r struct {
		Jeton string `json:"access_token"`
		Duree int    `json:"expires_in"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&r); err != nil {
		return "", 0, err
	}
	if r.Jeton == "" {
		return "", 0, errors.New("Météo-France, jeton : réponse sans jeton")
	}
	if r.Duree <= 0 {
		r.Duree = 3600
	}
	return r.Jeton, time.Duration(r.Duree) * time.Second, nil
}

// obtenir : appel d'une API avec le jeton ; un refus 401 fait redemander un
// jeton, une fois ; 400 et 404 : ressource introuvable (calcul pas encore
// publié, échéance hors du calcul).
func (m *meteoFrance) obtenir(ctx context.Context, adresse string, limite int64) ([]byte, error) {
	if m.pause > 0 {
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(m.pause):
		}
	}
	for essai := 0; essai < 2; essai++ {
		nom, valeur, cle := enteteCle(m.identifiant())
		if !cle {
			jeton, err := m.obtenirJeton(ctx, essai > 0)
			if err != nil {
				return nil, err
			}
			nom, valeur = "Authorization", "Bearer "+jeton
		} else if essai > 0 {
			break // clé d'API refusée : pas de nouveau jeton à demander
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, adresse, nil)
		if err != nil {
			return nil, err
		}
		req.Header.Set(nom, valeur)
		req.Header.Set("User-Agent", "NautiLink/"+version)
		resp, err := m.client.Do(req)
		if err != nil {
			return nil, err
		}
		b, err := io.ReadAll(io.LimitReader(resp.Body, limite))
		resp.Body.Close()
		switch {
		case resp.StatusCode == http.StatusUnauthorized && essai == 0:
			continue
		case resp.StatusCode == http.StatusNotFound || resp.StatusCode == http.StatusBadRequest:
			return nil, errMeteoIntrouvable
		case resp.StatusCode != http.StatusOK:
			return nil, fmt.Errorf("Météo-France : %s", resp.Status)
		}
		return b, err
	}
	return nil, errors.New("Météo-France : accès refusé")
}

// dansArome : domaine du modèle AROME à 0,01° (étude § 9.1).
func dansArome(lat, lon float64) bool { return lat >= 37.5 && lat <= 55.4 && lon >= -12 && lon <= 16 }

// dansArpegeEurope : domaine d'ARPEGE Europe à 0,1° (20° à 72° N, 32° O à
// 42° E ; à constater sur le catalogue, étude § 9.1, TODO-4.12).
func dansArpegeEurope(lat, lon float64) bool {
	return lat >= 20 && lat <= 72 && lon >= -32 && lon <= 42
}

// modeleWCS : modèle de vent et de pression interrogé par le service WCS.
type modeleWCS struct {
	nom     string        // AROME, ARPEGE Europe, ARPEGE Globe
	adresse string        // point GetCoverage
	pas     float64       // pas de la grille, en degrés
	calcul  time.Duration // un nouveau calcul toutes les « calcul » heures
}

// modeleVent : AROME dans son domaine, sinon ARPEGE Europe, sinon ARPEGE
// Globe (RG-NAV-28, D-181).
func (m *meteoFrance) modeleVent(lat, lon float64) modeleWCS {
	switch {
	case dansArome(lat, lon):
		return modeleWCS{"AROME", m.aromeURL, 0.01, 3 * time.Hour}
	case dansArpegeEurope(lat, lon):
		return modeleWCS{"ARPEGE Europe", m.arpegeEuropeURL, 0.1, 6 * time.Hour}
	}
	return modeleWCS{"ARPEGE Globe", m.arpegeGlobeURL, 0.25, 6 * time.Hour}
}

// grilleVagues : grille MFWAM à 0,025° sur les côtes françaises (38° à 53°
// N, 8° O à 12° E), sinon celle à 0,1°.
func grilleVagues(lat, lon float64) string {
	if lat >= 38 && lat <= 53 && lon >= -8 && lon <= 12 {
		return "0.025"
	}
	return "0.1"
}

// calculs : heures de calcul à essayer, du plus récent au plus ancien, pour
// une prévision à l'heure h (calculs toutes les « pas » heures, dont celui
// déjà trouvé en premier).
func calculs(h time.Time, pas time.Duration, nombre int, connu time.Time) []time.Time {
	var l []time.Time
	if !connu.IsZero() && !connu.After(h) && h.Sub(connu) <= 36*time.Hour {
		l = append(l, connu)
	}
	r := h.Truncate(pas)
	for i := 0; i < nombre; i++ {
		if t := r.Add(-time.Duration(i) * pas); !t.Equal(connu) {
			l = append(l, t)
		}
	}
	return l
}

// valeurWCS : une couverture du modèle au point, à l'heure h : petite
// grille en GRIB2 autour du point (3 × 3 points), lue au point le plus
// proche ; calculs cherchés en remontant, le dernier trouvé en premier.
func (m *meteoFrance) valeurWCS(ctx context.Context, mod modeleWCS, couverture string, hauteur bool, lat, lon float64, h time.Time) (float64, error) {
	var derniere error = errMeteoIntrouvable
	connu := m.runArome
	if mod.adresse != m.aromeURL {
		connu = m.runArpege[mod.adresse]
	}
	demi := 1.5 * mod.pas
	for _, run := range calculs(h, mod.calcul, 5, connu) {
		q := url.Values{"service": {"WCS"}, "version": {"2.0.1"},
			"coverageid": {couverture + "___" + run.UTC().Format("2006-01-02T15.04.05Z")},
			"format":     {"application/wmo-grib"},
			"subset": {"time(" + h.UTC().Format(time.RFC3339) + ")",
				fmt.Sprintf("lat(%.3f,%.3f)", lat-demi, lat+demi),
				fmt.Sprintf("long(%.3f,%.3f)", lon-demi, lon+demi)}}
		if hauteur {
			q["subset"] = append(q["subset"], "height(10)")
		}
		b, err := m.obtenir(ctx, mod.adresse+"?"+q.Encode(), 1<<20)
		if errors.Is(err, errMeteoIntrouvable) {
			continue
		}
		if err != nil {
			return 0, err
		}
		champs, err := lireGRIB2(b)
		if err != nil {
			return 0, err
		}
		v, ok := champs[0].valeurPres(lat, lon, 2)
		if !ok {
			return 0, errors.New(mod.nom + " : point absent de la grille rendue")
		}
		if mod.adresse == m.aromeURL {
			m.runArome = run
		} else {
			if m.runArpege == nil {
				m.runArpege = map[string]time.Time{}
			}
			m.runArpege[mod.adresse] = run
		}
		return v, nil
	}
	return 0, derniere
}

// hauteurVagues : hauteur significative des vagues (SWH, discipline 10,
// catégorie 0, paramètre 3) du modèle MFWAM, au point de mer le plus proche
// (4 points autour au plus) ; ok false : point hors de la grille ou sans
// mer assez près.
func (m *meteoFrance) hauteurVagues(ctx context.Context, lat, lon float64, h time.Time) (float64, bool, error) {
	grille := grilleVagues(lat, lon)
	cible := h.Add(-time.Hour)
	for _, run := range calculs(cible, 6*time.Hour, 4, m.runVagues) {
		echeance := int(h.Sub(run).Round(time.Hour) / time.Hour)
		if echeance < 1 || echeance > 102 {
			continue
		}
		adresse := m.vaguesURL + grille + "/packages/SP1/productMFWAM?" + url.Values{
			"referencetime": {run.UTC().Format("2006-01-02T15:04:05Z")},
			"time":          {fmt.Sprintf("%03dH", echeance)}, "format": {"grib2"}}.Encode()
		if m.cacheVagues != adresse || m.champVagues == nil {
			b, err := m.obtenir(ctx, adresse, 64<<20)
			if errors.Is(err, errMeteoIntrouvable) {
				continue
			}
			if err != nil {
				return 0, false, err
			}
			champs, err := lireGRIB2(b)
			if err != nil {
				return 0, false, err
			}
			m.champVagues = nil
			for i := range champs {
				if c := champs[i]; c.Discipline == 10 && c.Categorie == 0 && c.Parametre == 3 {
					m.champVagues = &c
					break
				}
			}
			if m.champVagues == nil {
				return 0, false, errors.New("MFWAM : hauteur des vagues absente du fichier")
			}
			m.cacheVagues = adresse
		}
		m.runVagues = run
		v, ok := m.champVagues.valeurPres(lat, lon, 4)
		return v, ok, nil
	}
	return 0, false, errMeteoIntrouvable
}

// etatMerDouglas : terme de l'échelle de Douglas (état de la mer, code 3700
// de l'OMM) pour une hauteur significative des vagues.
func etatMerDouglas(h float64) string {
	switch {
	case h <= 0:
		return "calme"
	case h <= 0.1:
		return "calme, ridée"
	case h <= 0.5:
		return "belle"
	case h <= 1.25:
		return "peu agitée"
	case h <= 2.5:
		return "agitée"
	case h <= 4:
		return "forte"
	case h <= 6:
		return "très forte"
	case h <= 9:
		return "grosse"
	case h <= 14:
		return "très grosse"
	}
	return "énorme"
}

func arrondiA(v float64, chiffres int) *float64 {
	f := math.Pow(10, float64(chiffres))
	r := math.Round(v*f) / f
	return &r
}

// relever : météo au point et à l'heure h (arrondie à l'heure) ; complet
// false si une donnée attendue manque (Météo-France n'a pas répondu) ; une
// donnée hors du domaine d'un modèle n'est pas attendue.
func (m *meteoFrance) relever(ctx context.Context, lat, lon float64, h time.Time, maintenant time.Time) (meteoJSON, bool) {
	h = h.UTC().Round(time.Hour)
	r := meteoJSON{ReleveeLe: maintenant.UTC(), HeurePrevision: h, Source: sourceMeteo}
	complet := true
	// Vent et pression partout dans le monde : AROME, sinon ARPEGE (D-181).
	mod := m.modeleVent(lat, lon)
	u, err1 := m.valeurWCS(ctx, mod, "U_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", true, lat, lon, h)
	var v float64
	var err2 error
	if err1 == nil {
		v, err2 = m.valeurWCS(ctx, mod, "V_COMPONENT_OF_WIND__SPECIFIC_HEIGHT_LEVEL_ABOVE_GROUND", true, lat, lon, h)
	}
	if err := errors.Join(err1, err2); err != nil {
		log.Printf("météo, vent : %v", err)
		complet = false
	} else {
		r.VentVitesseNoeuds = arrondiA(math.Hypot(u, v)*noeudsParMs, 1)
		d := int(math.Round(math.Mod(math.Atan2(-u, -v)*180/math.Pi+360, 360))) % 360 // d'où vient le vent
		r.VentDirectionDegres = &d
	}
	if p, err := m.valeurWCS(ctx, mod, "PRESSURE__MEAN_SEA_LEVEL", false, lat, lon, h); err != nil {
		log.Printf("météo, pression : %v", err)
		complet = false
	} else {
		r.PressionHpa = arrondiA(p/100, 1)
	}
	if hv, ok, err := m.hauteurVagues(ctx, lat, lon, h); err != nil {
		log.Printf("météo, vagues : %v", err)
		complet = false
	} else if ok {
		r.HauteurVaguesMetres = arrondiA(hv, 2)
		r.EtatMer = etatMerDouglas(hv)
	}
	if r.VentVitesseNoeuds == nil && r.PressionHpa == nil && r.HauteurVaguesMetres == nil {
		r.Indisponible = true
	}
	return r, complet
}

// relevesMeteo : tâche de fond (RG-NAV-28, RG-NAV-38) : météo du départ des
// navigations commencées depuis moins de 2 heures et de l'arrivée de celles
// terminées depuis moins de 2 heures, encore sans météo. Nouvel essai à
// chaque passage pendant 1 heure ; ensuite ce qui a été obtenu est gardé,
// ou « indisponible ». Les navigations plus anciennes ne sont pas reprises.
func (a *app) relevesMeteo(ctx context.Context) error {
	m := a.meteo
	if m == nil {
		return nil
	}
	if err := a.chargerCodeMeteo(ctx); err != nil {
		return err
	}
	if !m.actif() {
		return nil
	}
	now := a.maintenant()
	if !m.dernierPassage.IsZero() && now.Sub(m.dernierPassage) < intervalleMeteo {
		return nil
	}
	m.dernierPassage = now
	type releve struct {
		id, colonne string
		heure       time.Time
	}
	lignes, err := a.b.pool.Query(ctx, `SELECT id, 'meteo_depart', debut FROM navigations
			WHERE meteo_depart IS NULL AND supprimee_le IS NULL AND debut > $1::timestamptz - interval '2 hours' AND debut <= $1::timestamptz
		UNION ALL SELECT id, 'meteo_arrivee', fin FROM navigations
			WHERE meteo_arrivee IS NULL AND supprimee_le IS NULL AND fin_enregistree IS NOT NULL
			AND fin > $1::timestamptz - interval '2 hours' AND fin <= $1::timestamptz`, now)
	if err != nil {
		return err
	}
	aRelever, err := pgx.CollectRows(lignes, func(l pgx.CollectableRow) (releve, error) {
		var r releve
		return r, l.Scan(&r.id, &r.colonne, &r.heure)
	})
	if err != nil {
		return err
	}
	for _, r := range aRelever {
		// point de départ : première position de la navigation ; d'arrivée : la dernière
		ordre := "ASC"
		if r.colonne == "meteo_arrivee" {
			ordre = "DESC"
		}
		var lat, lon float64
		err := a.b.pool.QueryRow(ctx, `SELECT e.latitude, e.longitude FROM evenements e JOIN navigations n ON n.id = e.navigation_id
			WHERE e.navigation_id = $1 AND e.latitude IS NOT NULL AND e.supprime_le IS NULL
			AND e.heure_acquisition >= n.debut AND (n.fin IS NULL OR e.heure_acquisition <= n.fin)
			ORDER BY e.heure_acquisition `+ordre+` LIMIT 1`, r.id).Scan(&lat, &lon)
		echu := now.Sub(r.heure) >= delaiMeteo
		var mj meteoJSON
		switch {
		case errors.Is(err, pgx.ErrNoRows) && !echu:
			continue // pas encore de position : nouvel essai au prochain passage
		case errors.Is(err, pgx.ErrNoRows):
			mj = meteoJSON{ReleveeLe: now.UTC(), HeurePrevision: r.heure.UTC().Round(time.Hour), Source: sourceMeteo, Indisponible: true}
		case err != nil:
			return err
		default:
			var complet bool
			mj, complet = m.relever(ctx, lat, lon, r.heure, now)
			if !complet && !echu {
				continue
			}
		}
		b, err := json.Marshal(mj)
		if err != nil {
			return err
		}
		if _, err := a.b.pool.Exec(ctx, "UPDATE navigations SET "+r.colonne+" = $2 WHERE id = $1 AND "+r.colonne+" IS NULL", r.id, b); err != nil {
			return err
		}
	}
	return nil
}

// meteoTexte : présentation de la météo relevée sur la page de la
// navigation et dans le PDF (RG-NAV-28, RG-NAV-38) ; vide sans relevé.
func meteoTexte(brut json.RawMessage, decalage *int) string {
	if len(brut) == 0 {
		return ""
	}
	var m meteoJSON
	if err := json.Unmarshal(brut, &m); err != nil {
		return ""
	}
	if m.Indisponible {
		return "Météo indisponible"
	}
	var parties []string
	if m.VentVitesseNoeuds != nil {
		v := "Vent " + strconv.FormatFloat(math.Round(*m.VentVitesseNoeuds), 'f', 0, 64) + " nœuds"
		if m.VentDirectionDegres != nil {
			v += " " + directionCardinale(*m.VentDirectionDegres) + " (" + strconv.Itoa(*m.VentDirectionDegres) + "°)"
		}
		parties = append(parties, v)
	}
	if m.HauteurVaguesMetres != nil {
		parties = append(parties, "mer "+m.EtatMer+" ("+strings.Replace(strconv.FormatFloat(*m.HauteurVaguesMetres, 'f', 1, 64), ".", ",", 1)+" m de vagues)")
	}
	if m.PressionHpa != nil {
		parties = append(parties, "pression "+strconv.FormatFloat(math.Round(*m.PressionHpa), 'f', 0, 64)+" hPa")
	}
	return strings.Join(parties, ", ") + " — prévision " + sourceMeteo + " pour " + heureWeb(m.HeurePrevision, decalage)
}

// directionCardinale : d'où vient le vent, rose des vents à 16 directions
// (« du nord », « d'est »).
func directionCardinale(deg int) string {
	noms := []string{"nord", "nord-nord-est", "nord-est", "est-nord-est", "est", "est-sud-est", "sud-est", "sud-sud-est",
		"sud", "sud-sud-ouest", "sud-ouest", "ouest-sud-ouest", "ouest", "ouest-nord-ouest", "nord-ouest", "nord-nord-ouest"}
	n := noms[int(math.Round(float64(((deg%360)+360)%360)/22.5))%16]
	if strings.HasPrefix(n, "est") || strings.HasPrefix(n, "ouest") {
		return "d'" + n
	}
	return "du " + n
}
