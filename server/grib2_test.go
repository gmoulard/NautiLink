package main

import (
	"encoding/binary"
	"encoding/json"
	"math"
	"os"
	"testing"
)

// TestGRIB2ContreEccodes : TODO-4.10 : le décodage GRIB2 CCSDS (modèle 5.42,
// drapeaux 14, blocs de 32, intervalles de 128, comme les fichiers MFWAM)
// donne les mêmes valeurs qu'eccodes de l'ECMWF. testdata/ :
// mfwam-essai-ccsds.grib2 et les valeurs décodées par eccodes 2.x
// (mfwam-essai-ccsds.json), fabriqués par testdata/fabrique-grib2.py : champ
// lisse sans masque, champ masqué (terre) balayé du sud vers le nord en 12
// bits, champ presque constant (blocs nuls, seconde extension).
func TestGRIB2ContreEccodes(t *testing.T) {
	b, err := os.ReadFile("testdata/mfwam-essai-ccsds.grib2")
	if err != nil {
		t.Fatal(err)
	}
	j, err := os.ReadFile("testdata/mfwam-essai-ccsds.json")
	if err != nil {
		t.Fatal(err)
	}
	var refs []struct {
		Ni, Nj  int
		Flags   int
		Bloc    int
		Rsi     int
		Valeurs []*float64
	}
	if err := json.Unmarshal(j, &refs); err != nil {
		t.Fatal(err)
	}
	champs, err := lireGRIB2(b)
	if err != nil {
		t.Fatal(err)
	}
	if len(champs) != len(refs) {
		t.Fatalf("%d champs, %d attendus", len(champs), len(refs))
	}
	for k, c := range champs {
		r := refs[k]
		if c.Discipline != 10 || c.Categorie != 0 || c.Parametre != 3 || c.Ni != r.Ni || c.Nj != r.Nj {
			t.Fatalf("champ %d : %d/%d/%d %dx%d", k, c.Discipline, c.Categorie, c.Parametre, c.Ni, c.Nj)
		}
		ecarts := 0
		for i, v := range r.Valeurs {
			present := c.Present == nil || c.Present[i]
			switch {
			case v == nil && present, v != nil && !present:
				t.Errorf("champ %d, point %d : présence %v, eccodes %v", k, i, present, v != nil)
				ecarts++
			case v != nil && math.Abs(c.Valeurs[i]-*v) > 1e-5:
				t.Errorf("champ %d, point %d : %v, eccodes %v", k, i, c.Valeurs[i], *v)
				ecarts++
			}
			if ecarts > 5 {
				t.FailNow()
			}
		}
	}
	// point au milieu de la première grille (48° N à 47,25° N, 4° O à 3° O)
	v, ok := champs[0].valeurPres(47.625, -3.5, 0)
	if want := *refs[0].Valeurs[15*41+20]; !ok || math.Abs(v-want) > 1e-5 {
		t.Errorf("valeurPres = %v %v, attendu %v", v, ok, want)
	}
	if _, ok := champs[0].valeurPres(40, -3.5, 2); ok {
		t.Error("point hors de la grille trouvé")
	}
	// champ masqué : coin nord-est en terre ; le point de mer le plus proche est pris
	if _, ok := champs[1].valeurPres(47.80, -3.20, 0); ok {
		t.Error("point de terre : valeur rendue")
	}
	if v, ok := champs[1].valeurPres(47.80, -3.20, 4); !ok || v == 0 {
		t.Errorf("point de terre, rayon 4 : %v %v", v, ok)
	}
}

// grib2Simple : message GRIB2 d'essai en compression simple (modèle 5.0) :
// grille régulière du nord au sud, valeurs entières sur 16 bits (D = dec).
func grib2Simple(discipline, cat, num, ni, nj int, la1, lo1, pas float64, valeurs []float64, dec int) []byte {
	sec := func(n byte, corps []byte) []byte {
		s := make([]byte, 5, 5+len(corps))
		binary.BigEndian.PutUint32(s, uint32(5+len(corps)))
		s[4] = n
		return append(s, corps...)
	}
	u32 := func(b []byte, o int, v uint32) { binary.BigEndian.PutUint32(b[o:], v) }
	signe := func(v float64) uint32 {
		x := int64(math.Round(v * 1e6))
		if x < 0 {
			return uint32(-x) | 1<<31
		}
		return uint32(x)
	}
	s1 := make([]byte, 16)
	g := make([]byte, 67) // section 3 sans ses 5 premiers octets : octets 6 à 72
	u32(g, 30-5, uint32(ni))
	u32(g, 34-5, uint32(nj))
	u32(g, 46-5, signe(la1))
	u32(g, 50-5, signe(lo1))
	u32(g, 55-5, signe(la1-float64(nj-1)*pas))
	u32(g, 59-5, signe(lo1+float64(ni-1)*pas))
	u32(g, 63-5, uint32(math.Round(pas*1e6)))
	u32(g, 67-5, uint32(math.Round(pas*1e6)))
	s4 := make([]byte, 29)
	s4[4], s4[5] = byte(cat), byte(num)
	min := math.Inf(1)
	for _, v := range valeurs {
		min = math.Min(min, v)
	}
	f := math.Pow(10, float64(dec))
	r := math.Floor(min * f)
	s5 := make([]byte, 16)
	u32(s5, 0, uint32(len(valeurs)))
	u32(s5, 6, math.Float32bits(float32(r)))
	binary.BigEndian.PutUint16(s5[10:], 0)
	binary.BigEndian.PutUint16(s5[12:], uint16(dec))
	s5[14] = 16
	donnees := make([]byte, 2*len(valeurs))
	for i, v := range valeurs {
		binary.BigEndian.PutUint16(donnees[2*i:], uint16(math.Round(v*f-r)))
	}
	var m []byte
	m = append(m, sec(1, s1)...)
	m = append(m, sec(3, g)...)
	m = append(m, sec(4, s4)...)
	m = append(m, sec(5, s5)...)
	m = append(m, sec(6, []byte{255})...)
	m = append(m, sec(7, donnees)...)
	m = append(m, "7777"...)
	t := make([]byte, 16, 16+len(m))
	copy(t, "GRIB")
	t[6], t[7] = byte(discipline), 2
	binary.BigEndian.PutUint64(t[8:], uint64(16+len(m)))
	return append(t, m...)
}

func TestGRIB2Simple(t *testing.T) {
	b := grib2Simple(0, 2, 2, 3, 3, 47.56, -3.56, 0.01, []float64{1, 2, 3, 4, 5.5, 6, 7, 8, 9}, 1)
	c, err := lireGRIB2(b)
	if err != nil {
		t.Fatal(err)
	}
	if v, ok := c[0].valeurPres(47.55, -3.55, 0); !ok || math.Abs(v-5.5) > 1e-6 {
		t.Errorf("point central : %v %v", v, ok)
	}
	if v, ok := c[0].valeurPres(47.54, -3.54, 0); !ok || v != 9 {
		t.Errorf("coin sud-est : %v %v", v, ok)
	}
	if _, err := lireGRIB2([]byte("pas un GRIB")); err == nil {
		t.Error("fichier quelconque accepté")
	}
	if _, err := lireGRIB2(b[:len(b)-10]); err == nil {
		t.Error("message tronqué accepté")
	}
}
