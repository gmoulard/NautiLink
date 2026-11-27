package main

import (
	"encoding/binary"
	"errors"
	"fmt"
	"math"
)

// Lecture des fichiers GRIB2 de Météo-France (RG-NAV-28, TODO-4.10) :
// grille régulière en latitude et longitude (modèle de grille 3.0), valeurs
// en compression simple (modèle de représentation 5.0) ou CCSDS (5.42, celle
// des fichiers MFWAM), avec ou sans masque (terre). Écrit en Go seul, sans
// bibliothèque C (l'image du serveur est construite sans cgo) ; vérifié
// contre eccodes par grib2_test.go. Le reste de la norme GRIB2 n'est pas lu.

// champGRIB : un champ décodé d'un message GRIB2.
type champGRIB struct {
	Discipline, Categorie, Parametre int
	Ni, Nj                           int
	La1, Lo1, Di, Dj                 float64 // degrés ; Di, Dj positifs
	Balayage                         byte    // drapeaux de balayage (modèle 3.0, octet 72)
	Valeurs                          []float64
	Present                          []bool // nil : tous les points ont une valeur
}

var errGRIBNonPris = errors.New("GRIB2 : forme non prise en charge")

// lireGRIB2 : tous les champs des messages GRIB2 du fichier.
func lireGRIB2(b []byte) ([]champGRIB, error) {
	var champs []champGRIB
	for p := 0; p+16 <= len(b); {
		if string(b[p:p+4]) != "GRIB" {
			p++
			continue
		}
		if b[p+7] != 2 {
			return nil, fmt.Errorf("GRIB : édition %d, 2 attendue", b[p+7])
		}
		total := int(binary.BigEndian.Uint64(b[p+8 : p+16]))
		if total < 16 || p+total > len(b) {
			return nil, errors.New("GRIB2 : message tronqué")
		}
		c, err := lireMessage(b[p:p+total], int(b[p+6]))
		if err != nil {
			return nil, err
		}
		champs = append(champs, c...)
		p += total
	}
	if len(champs) == 0 {
		return nil, errors.New("GRIB2 : aucun message")
	}
	return champs, nil
}

func lireMessage(m []byte, discipline int) ([]champGRIB, error) {
	var champs []champGRIB
	var grille champGRIB
	var cat, num int
	var sec5 []byte
	var masque []bool
	grilleLue := false
	for p := 16; p+4 <= len(m); {
		if string(m[p:p+4]) == "7777" {
			return champs, nil
		}
		if p+5 > len(m) {
			break
		}
		l := int(binary.BigEndian.Uint32(m[p : p+4]))
		if l < 5 || p+l > len(m) {
			return nil, errors.New("GRIB2 : section tronquée")
		}
		s := m[p : p+l]
		switch s[4] {
		case 3:
			g, err := lireGrille(s)
			if err != nil {
				return nil, err
			}
			grille, grilleLue = g, true
		case 4:
			if len(s) < 11 {
				return nil, errors.New("GRIB2 : section 4 tronquée")
			}
			cat, num = int(s[9]), int(s[10])
		case 5:
			sec5 = s
		case 6:
			if len(s) < 6 {
				return nil, errors.New("GRIB2 : section 6 tronquée")
			}
			switch s[5] {
			case 255:
				masque = nil
			case 0:
				if !grilleLue {
					return nil, errors.New("GRIB2 : masque avant la grille")
				}
				n := grille.Ni * grille.Nj
				if len(s)-6 < (n+7)/8 {
					return nil, errors.New("GRIB2 : masque tronqué")
				}
				masque = make([]bool, n)
				for i := range masque {
					masque[i] = s[6+i/8]&(0x80>>(i%8)) != 0
				}
			case 254: // masque précédent du message, gardé
			default:
				return nil, errGRIBNonPris
			}
		case 7:
			if !grilleLue || sec5 == nil {
				return nil, errors.New("GRIB2 : données sans grille ni représentation")
			}
			brutes, err := decoderValeurs(sec5, s[5:])
			if err != nil {
				return nil, err
			}
			c := grille
			c.Discipline, c.Categorie, c.Parametre = discipline, cat, num
			n := c.Ni * c.Nj
			c.Valeurs = make([]float64, n)
			if masque == nil {
				if len(brutes) != n {
					return nil, fmt.Errorf("GRIB2 : %d valeurs pour %d points", len(brutes), n)
				}
				copy(c.Valeurs, brutes)
			} else {
				c.Present = masque
				k := 0
				for i := 0; i < n; i++ {
					if masque[i] {
						if k >= len(brutes) {
							return nil, errors.New("GRIB2 : valeurs manquantes sous le masque")
						}
						c.Valeurs[i] = brutes[k]
						k++
					}
				}
			}
			champs = append(champs, c)
		}
		p += l
	}
	return nil, errors.New("GRIB2 : fin de message « 7777 » absente")
}

// signeGRIB : entier signé de la norme GRIB (bit de signe, puis valeur).
func signeGRIB(v uint32, bits uint) int64 {
	signe := uint32(1) << (bits - 1)
	if v&signe != 0 {
		return -int64(v &^ signe)
	}
	return int64(v)
}

func lireGrille(s []byte) (champGRIB, error) {
	var g champGRIB
	if len(s) < 72 || binary.BigEndian.Uint16(s[12:14]) != 0 {
		return g, errGRIBNonPris // seule la grille régulière lat/lon (3.0) est lue
	}
	u := func(o int) uint32 { return binary.BigEndian.Uint32(s[o-1 : o+3]) } // octet o, compté depuis 1
	g.Ni, g.Nj = int(u(31)), int(u(35))
	unite := 1e-6
	if angle, sub := u(39), u(43); angle != 0 && angle != math.MaxUint32 && sub != 0 && sub != math.MaxUint32 {
		unite = float64(angle) / float64(sub)
	}
	g.La1 = float64(signeGRIB(u(47), 32)) * unite
	g.Lo1 = float64(signeGRIB(u(51), 32)) * unite
	g.Di = float64(u(64)) * unite
	g.Dj = float64(u(68)) * unite
	g.Balayage = s[71]
	if g.Ni <= 0 || g.Nj <= 0 || g.Di <= 0 || g.Dj <= 0 || g.Balayage&0x20 != 0 {
		return g, errGRIBNonPris
	}
	return g, nil
}

// decoderValeurs : valeurs de la section 7, selon la section 5 (Y = (R +
// X × 2^E) / 10^D).
func decoderValeurs(s5, donnees []byte) ([]float64, error) {
	if len(s5) < 21 {
		return nil, errors.New("GRIB2 : section 5 tronquée")
	}
	n := int(binary.BigEndian.Uint32(s5[5:9]))
	modele := binary.BigEndian.Uint16(s5[9:11])
	r := float64(math.Float32frombits(binary.BigEndian.Uint32(s5[11:15])))
	e := signeGRIB(uint32(binary.BigEndian.Uint16(s5[15:17])), 16)
	d := signeGRIB(uint32(binary.BigEndian.Uint16(s5[17:19])), 16)
	bits := int(s5[19])
	var x []uint32
	var err error
	switch {
	case bits == 0:
		x = make([]uint32, n) // champ constant : toutes les valeurs valent R
	case modele == 0:
		x, err = decoderSimple(donnees, bits, n)
	case modele == 42:
		if len(s5) < 25 {
			return nil, errors.New("GRIB2 : section 5 tronquée")
		}
		x, err = decoderAEC(donnees, bits, int(s5[22]), int(binary.BigEndian.Uint16(s5[23:25])), int(s5[21]), n)
	default:
		return nil, errGRIBNonPris
	}
	if err != nil {
		return nil, err
	}
	echelle, dix := math.Pow(2, float64(e)), math.Pow(10, float64(-d))
	v := make([]float64, n)
	for i, xi := range x {
		v[i] = (r + float64(xi)*echelle) * dix
	}
	return v, nil
}

// lecteurBits : lecture bit à bit, poids fort en premier.
type lecteurBits struct {
	d   []byte
	pos int // en bits
}

var errBitsTronques = errors.New("GRIB2 : données tronquées")

func (l *lecteurBits) lire(n int) (uint32, error) {
	if l.pos+n > len(l.d)*8 {
		return 0, errBitsTronques
	}
	var v uint32
	for n > 0 {
		octet := l.d[l.pos/8]
		reste := 8 - l.pos%8
		pris := min(reste, n)
		v = v<<pris | uint32(octet>>(reste-pris))&(1<<pris-1)
		l.pos += pris
		n -= pris
	}
	return v, nil
}

// unaire : code « séquence fondamentale » : nombre de 0 avant le 1.
func (l *lecteurBits) unaire() (uint32, error) {
	var n uint32
	for {
		b, err := l.lire(1)
		if err != nil {
			return 0, err
		}
		if b == 1 {
			return n, nil
		}
		n++
	}
}

func decoderSimple(d []byte, bits, n int) ([]uint32, error) {
	l := lecteurBits{d: d}
	x := make([]uint32, n)
	for i := range x {
		v, err := l.lire(bits)
		if err != nil {
			return nil, err
		}
		x[i] = v
	}
	return x, nil
}

// Drapeaux CCSDS (ccsdsFlags de GRIB2, ceux de libaec).
const (
	aecSigne       = 1
	aecPretraite   = 8
	aecRestreint   = 16
	aecRemplirRSI  = 32
	aecBlocsNulsRO = 5 // « remainder of segment » : blocs nuls jusqu'à la fin du segment
)

// decoderAEC : décompression CCSDS 121.0-B (Adaptive Entropy Coding, celle
// de libaec) de n échantillons de « bits » bits : blocs de « bloc »
// échantillons, groupés par intervalles de référence de « rsi » blocs ;
// option nulle (blocs à zéro, seconde extension), découpage k, sans
// compression ; puis prédicteur à délai unitaire inversé si les données
// sont prétraitées.
func decoderAEC(d []byte, bits, bloc, rsi, drapeaux, n int) ([]uint32, error) {
	if bits < 1 || bits > 32 || bloc <= 0 || rsi <= 0 || drapeaux&aecSigne != 0 {
		return nil, errGRIBNonPris
	}
	var lgId int
	switch {
	case bits > 16:
		lgId = 5
	case bits > 8:
		lgId = 4
	case drapeaux&aecRestreint != 0 && bits <= 4:
		lgId = 2
		if bits <= 2 {
			lgId = 1
		}
	default:
		lgId = 3
	}
	idMax := uint32(1)<<lgId - 1
	pretraite := drapeaux&aecPretraite != 0
	l := lecteurBits{d: d}
	sortie := make([]uint32, 0, n)
	for len(sortie) < n {
		var tampon []uint32 // échantillons de l'intervalle, avant le prétraitement inversé
		for b := 0; b < rsi && len(sortie)+len(tampon) < n; b++ {
			ref := pretraite && b == 0
			lireRef := func() error {
				v, err := l.lire(bits)
				tampon = append(tampon, v)
				return err
			}
			id, err := l.lire(lgId)
			if err != nil {
				return nil, err
			}
			switch {
			case id == 0: // faible entropie
				choix, err := l.lire(1)
				if err != nil {
					return nil, err
				}
				debut := 0
				if ref {
					if err := lireRef(); err != nil {
						return nil, err
					}
					debut = 1
				}
				if choix == 1 { // seconde extension : paires codées ensemble
					for i := debut; i < bloc; {
						m, err := l.unaire()
						if err != nil {
							return nil, err
						}
						beta := (int(math.Sqrt(8*float64(m)+1)) - 1) / 2
						for (beta+1)*(beta+2)/2 <= int(m) {
							beta++
						}
						for beta*(beta+1)/2 > int(m) {
							beta--
						}
						d1 := int(m) - beta*(beta+1)/2
						if i&1 == 0 {
							tampon = append(tampon, uint32(beta-d1))
							i++
						}
						tampon = append(tampon, uint32(d1))
						i++
					}
				} else { // blocs nuls
					fs, err := l.unaire()
					if err != nil {
						return nil, err
					}
					z := int(fs) + 1
					if z == aecBlocsNulsRO {
						z = min(rsi-b, 64-b%64)
					} else if z > aecBlocsNulsRO {
						z--
					}
					for i := 0; i < z*bloc-debut; i++ {
						tampon = append(tampon, 0)
					}
					b += z - 1
				}
			case id == idMax: // sans compression ; la référence en est le premier échantillon
				for i := 0; i < bloc; i++ {
					v, err := l.lire(bits)
					if err != nil {
						return nil, err
					}
					tampon = append(tampon, v)
				}
			default: // découpage : k bits de poids faible, le reste en code unaire
				k := int(id - 1)
				debut := 0
				if ref {
					if err := lireRef(); err != nil {
						return nil, err
					}
					debut = 1
				}
				hauts := make([]uint32, bloc-debut)
				for i := range hauts {
					if hauts[i], err = l.unaire(); err != nil {
						return nil, err
					}
				}
				for _, h := range hauts {
					bas, err := l.lire(k)
					if err != nil {
						return nil, err
					}
					tampon = append(tampon, h<<k|bas)
				}
			}
		}
		if pretraite && len(tampon) > 0 {
			xmax := int64(1)<<bits - 1
			med := xmax/2 + 1
			dernier := int64(tampon[0])
			for i := 1; i < len(tampon); i++ {
				dd := int64(tampon[i])
				demi := dd>>1 + dd&1
				masque := int64(0)
				if dernier&med != 0 {
					masque = xmax
				}
				if demi <= masque^dernier {
					if dd&1 == 1 {
						dernier -= (dd + 1) >> 1
					} else {
						dernier += dd >> 1
					}
				} else {
					dernier = masque ^ dd
				}
				tampon[i] = uint32(dernier)
			}
		}
		sortie = append(sortie, tampon...)
		if drapeaux&aecRemplirRSI != 0 && l.pos%8 != 0 {
			l.pos += 8 - l.pos%8
		}
	}
	return sortie[:n], nil
}

// valeurPres : valeur au point de grille valide le plus proche de (lat,
// lon), cherché jusqu'à « rayon » points autour (un port est souvent un
// point de terre du modèle de vagues) ; false hors de la grille ou sans
// point valide assez près.
func (c champGRIB) valeurPres(lat, lon float64, rayon int) (float64, bool) {
	dlat := c.Dj
	if c.Balayage&0x40 == 0 {
		dlat = -c.Dj // du nord vers le sud
	}
	dlon := c.Di
	if c.Balayage&0x80 != 0 {
		dlon = -c.Di
	}
	lon = math.Mod(lon-c.Lo1, 360)
	if dlon > 0 && lon < 0 {
		lon += 360
	} else if dlon < 0 && lon > 0 {
		lon -= 360
	}
	fi, fj := lon/dlon, (lat-c.La1)/dlat
	i0, j0 := int(math.Round(fi)), int(math.Round(fj))
	if i0 < -rayon || i0 >= c.Ni+rayon || j0 < -rayon || j0 >= c.Nj+rayon {
		return 0, false
	}
	meilleure, trouve := math.Inf(1), false
	var v float64
	for j := j0 - rayon; j <= j0+rayon; j++ {
		for i := i0 - rayon; i <= i0+rayon; i++ {
			if i < 0 || j < 0 || i >= c.Ni || j >= c.Nj {
				continue
			}
			k := j*c.Ni + i
			if c.Present != nil && !c.Present[k] {
				continue
			}
			dx := (float64(i) - fi) * math.Cos(lat*math.Pi/180)
			dy := float64(j) - fj
			if dist := dx*dx + dy*dy; dist < meilleure {
				meilleure, v, trouve = dist, c.Valeurs[k], true
			}
		}
	}
	return v, trouve
}
