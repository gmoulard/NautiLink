package main

import (
	"context"
	"errors"
	"net/http"
	"slices"
	"time"

	"github.com/jackc/pgx/v5"
)

// Paramètres généraux synchronisés (TODO-4.4) : RG-PRM-01, RG-PRM-02,
// RG-SMS-02, RG-SMS-05, RG-NAV-05, RG-SOS-14, RG-COM-04. Les valeurs d'un
// nouveau compte ne sont pas décidées (Q-52) : un paramètre jamais réglé vaut
// null.

var frequences = []int{15, 30, 60, 120, 180, 360, 720, 1440, 2880, 14400} // RG-NAV-05

type smsParTypeJSON struct {
	Debut                 *bool `json:"debut"`
	PositionsAutomatiques *bool `json:"positionsAutomatiques"`
	PositionsManuelles    *bool `json:"positionsManuelles"`
	Notes                 *bool `json:"notes"`
	Photos                *bool `json:"photos"`
	NotesVocales          *bool `json:"notesVocales"`
	Incidents             *bool `json:"incidents"` // RG-JRN-11, D-154
	Fin                   *bool `json:"fin"`
}

type parametresJSON struct {
	Version            int            `json:"version"`
	SmsActifs          *bool          `json:"smsActifs"`
	SmsParType         smsParTypeJSON `json:"smsParType"`
	PhotoEnMms         *bool          `json:"photoEnMms"`
	FrequenceParDefaut *int           `json:"frequenceParDefaut"`
	ModifieLe          *time.Time     `json:"modifieLe,omitempty"`
}

func (p *parametresJSON) types() map[string]**bool {
	t := &p.SmsParType
	return map[string]**bool{"debut": &t.Debut, "positionsAutomatiques": &t.PositionsAutomatiques,
		"positionsManuelles": &t.PositionsManuelles, "notes": &t.Notes, "photos": &t.Photos,
		"notesVocales": &t.NotesVocales, "incidents": &t.Incidents, "fin": &t.Fin}
}

func (a *app) parametres(ctx context.Context, utilisateur string) (parametresJSON, error) {
	var p parametresJSON
	t := &p.SmsParType
	err := a.b.pool.QueryRow(ctx, `SELECT version, sms_actifs, sms_debut, sms_positions_automatiques, sms_positions_manuelles,
		sms_notes, sms_photos, sms_notes_vocales, sms_fin, photo_en_mms, frequence_par_defaut, modifie_le, sms_incidents
		FROM parametres WHERE utilisateur_id = $1`, utilisateur).Scan(&p.Version, &p.SmsActifs, &t.Debut,
		&t.PositionsAutomatiques, &t.PositionsManuelles, &t.Notes, &t.Photos, &t.NotesVocales, &t.Fin,
		&p.PhotoEnMms, &p.FrequenceParDefaut, &p.ModifieLe, &t.Incidents)
	if errors.Is(err, pgx.ErrNoRows) {
		return parametresJSON{}, nil
	}
	return p, err
}

// modifierParametres : depuis l'application mobile ou le Web ; seuls les
// champs présents changent, la dernière modification reçue l'emporte, champ
// par champ, sans refus (RG-COM-04). Ces réglages ne touchent jamais aux SMS
// SOS (RG-SOS-14).
func (a *app) modifierParametres(ctx context.Context, utilisateur string, c champs) (parametresJSON, error) {
	tx, err := a.b.pool.Begin(ctx)
	if err != nil {
		return parametresJSON{}, err
	}
	defer tx.Rollback(ctx)
	if _, err := tx.Exec(ctx, "INSERT INTO parametres (utilisateur_id) VALUES ($1) ON CONFLICT DO NOTHING", utilisateur); err != nil {
		return parametresJSON{}, err
	}
	if _, err := tx.Exec(ctx, "SELECT 1 FROM parametres WHERE utilisateur_id = $1 FOR UPDATE", utilisateur); err != nil {
		return parametresJSON{}, err
	}
	p, err := a.parametres(ctx, utilisateur)
	if err != nil {
		return p, err
	}
	for nom, v := range map[string]**bool{"smsActifs": &p.SmsActifs, "photoEnMms": &p.PhotoEnMms} {
		if c.a(nom) {
			if err := c.lire(nom, v); err != nil {
				return p, err
			}
		}
	}
	if c.a("smsParType") {
		var t champs
		if err := c.lire("smsParType", &t); err != nil {
			return p, err
		}
		for nom, v := range p.types() {
			if t.a(nom) {
				if err := t.lire(nom, v); err != nil {
					return p, err
				}
			}
		}
	}
	if c.a("frequenceParDefaut") {
		if err := c.lire("frequenceParDefaut", &p.FrequenceParDefaut); err != nil {
			return p, err
		}
		if p.FrequenceParDefaut != nil && !slices.Contains(frequences, *p.FrequenceParDefaut) {
			return p, errInvalide("Fréquence invalide : 15, 30, 60, 120, 180, 360, 720, 1440, 2880 ou 14400 minutes.")
		}
	}
	t := &p.SmsParType
	if _, err := tx.Exec(ctx, `UPDATE parametres SET sms_actifs = $2, sms_debut = $3, sms_positions_automatiques = $4,
		sms_positions_manuelles = $5, sms_notes = $6, sms_photos = $7, sms_notes_vocales = $8, sms_fin = $9,
		photo_en_mms = $10, frequence_par_defaut = $11, sms_incidents = $12, version = version + 1, modifie_le = now()
		WHERE utilisateur_id = $1`, utilisateur, p.SmsActifs, t.Debut, t.PositionsAutomatiques, t.PositionsManuelles,
		t.Notes, t.Photos, t.NotesVocales, t.Fin, p.PhotoEnMms, p.FrequenceParDefaut, t.Incidents); err != nil {
		return p, err
	}
	if err := tx.Commit(ctx); err != nil {
		return p, err
	}
	return a.parametres(ctx, utilisateur)
}

func (a *app) routesParametres(mux *http.ServeMux, v string) {
	mux.HandleFunc("GET "+v+"/parametres", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		p, err := a.parametres(r.Context(), s.utilisateur)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, p)
		return nil
	}))
	mux.HandleFunc("PATCH "+v+"/parametres", a.api(true, func(w http.ResponseWriter, r *http.Request, s *session) error {
		var c champs
		if err := lireJSON(r, &c); err != nil {
			return err
		}
		p, err := a.modifierParametres(r.Context(), s.utilisateur, c)
		if err != nil {
			return err
		}
		ecrireJSON(w, http.StatusOK, p)
		return nil
	}))
}
