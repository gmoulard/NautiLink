package main

import (
	"testing"
	"time"
)

// Heures envoyées aux amis : heure locale du
// téléphone puis UTC (RG-PRM-07, D-146).
func TestHeureEnvoyee(t *testing.T) {
	plusUn, moinsQuatre := 60, -240
	h := time.Date(2026, 11, 26, 13, 32, 0, 0, time.UTC)
	cas := []struct {
		t        time.Time
		decalage *int
		date     bool
		attendu  string
	}{
		{h, &plusUn, false, "14:32 (13:32 UTC)"},
		{h, &plusUn, true, "2026-11-26 14:32 (13:32 UTC)"},
		{time.Date(2026, 11, 26, 23, 30, 0, 0, time.UTC), &plusUn, true, "2026-11-27 00:30 (2026-11-26 23:30 UTC)"},
		{time.Date(2026, 7, 1, 2, 5, 0, 0, time.UTC), &moinsQuatre, false, "22:05 (02:05 UTC)"},
		{h, nil, true, "2026-11-26 13:32 UTC"},
		{h, nil, false, "13:32 UTC"},
	}
	for _, c := range cas {
		if r := heureEnvoyee(c.t, c.decalage, c.date); r != c.attendu {
			t.Errorf("heureEnvoyee(%v, %v, %v) = %q, attendu %q", c.t, c.decalage, c.date, r, c.attendu)
		}
	}
	if d := decalageHoraire(time.Date(2026, 11, 26, 14, 32, 0, 0, time.FixedZone("", 3600))); d == nil || *d != 60 {
		t.Errorf("decalageHoraire : %v", d)
	}
}
