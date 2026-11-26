package main

import (
	"math"
	"strconv"
	"strings"
)

// Carte de la page d'une navigation (TODO-6.2, cahier des charges 6.2) :
// fond OpenStreetMap et balisage OpenSeaMap, avec leurs mentions de source
// (RG-NAV-29, D-79). Calculée par le serveur et dessinée en SVG, sans
// bibliothèque ni JavaScript (08-architecture.md §2) : dalles de 256 pixels
// en projection de Mercator, tracé des positions non masquées (RG-NAV-22),
// points des événements et des alertes SOS (RG-NAV-31). Le même calcul, sans
// les dalles, sert à l'aperçu du tableau de bord et au PDF (RG-NAV-19).

const (
	tailleDalle = 256
	zoomMax     = 16
	adresseOSM  = "https://tile.openstreetmap.org"
	adresseOSea = "https://tiles.openseamap.org/seamark"
)

// pointCarte : un point à placer, en degrés ; Sorte : « position »,
// « depart », « arrivee », « derniere », « evenement » ou « sos ».
type pointCarte struct {
	Latitude, Longitude float64
	Sorte, Titre        string
	X, Y                float64 // calculés par cadrer
}

type dalleCarte struct {
	X, Y         float64 // coin haut gauche, en pixels de la carte
	Fond, Balise string  // adresses des images
}

// carte : ce que dessine le gabarit « carte ».
type carte struct {
	Largeur, Hauteur float64
	Zoom             int
	Dalles           []dalleCarte
	Trace            string // points du tracé, « x,y x,y … »
	Points           []pointCarte
	traceXY          [][2]float64 // le tracé en points, pour le PDF
}

// mercator : coordonnées en pixels du monde entier au zoom z.
func mercator(lat, lon float64, z int) (float64, float64) {
	lat = math.Max(-85.05112878, math.Min(85.05112878, lat))
	monde := tailleDalle * math.Exp2(float64(z))
	x := (lon + 180) / 360 * monde
	s := math.Sin(lat * math.Pi / 180)
	y := (0.5 - math.Log((1+s)/(1-s))/(4*math.Pi)) * monde
	return x, y
}

// cadrer : carte de largeur × hauteur pixels qui montre tous les points
// (tracé et marques), au plus grand zoom possible avec une marge ; nil sans
// point. avecDalles : adresses des dalles du fond et du balisage.
func cadrer(trace, marques []pointCarte, largeur, hauteur float64, avecDalles bool) *carte {
	tous := append(append([]pointCarte{}, trace...), marques...)
	if len(tous) == 0 {
		return nil
	}
	const marge = 24
	zoom := zoomMax
	var x0, y0 float64
	for ; zoom >= 0; zoom-- {
		minX, minY := math.Inf(1), math.Inf(1)
		maxX, maxY := math.Inf(-1), math.Inf(-1)
		for _, p := range tous {
			x, y := mercator(p.Latitude, p.Longitude, zoom)
			minX, maxX = math.Min(minX, x), math.Max(maxX, x)
			minY, maxY = math.Min(minY, y), math.Max(maxY, y)
		}
		if maxX-minX <= largeur-2*marge && maxY-minY <= hauteur-2*marge || zoom == 0 {
			x0, y0 = (minX+maxX)/2-largeur/2, (minY+maxY)/2-hauteur/2
			break
		}
	}
	c := &carte{Largeur: largeur, Hauteur: hauteur, Zoom: zoom}
	placer := func(p pointCarte) pointCarte {
		x, y := mercator(p.Latitude, p.Longitude, zoom)
		p.X, p.Y = arrondi(x-x0), arrondi(y-y0)
		return p
	}
	var b strings.Builder
	for i, p := range trace {
		p = placer(p)
		c.traceXY = append(c.traceXY, [2]float64{p.X, p.Y})
		if i > 0 {
			b.WriteByte(' ')
		}
		b.WriteString(strconv.FormatFloat(p.X, 'f', -1, 64) + "," + strconv.FormatFloat(p.Y, 'f', -1, 64))
	}
	c.Trace = b.String()
	for _, p := range marques {
		c.Points = append(c.Points, placer(p))
	}
	if avecDalles {
		n := int(math.Exp2(float64(zoom)))
		for ty := int(math.Floor(y0 / tailleDalle)); float64(ty*tailleDalle) < y0+hauteur; ty++ {
			if ty < 0 || ty >= n {
				continue
			}
			for tx := int(math.Floor(x0 / tailleDalle)); float64(tx*tailleDalle) < x0+largeur; tx++ {
				chemin := "/" + strconv.Itoa(zoom) + "/" + strconv.Itoa(((tx%n)+n)%n) + "/" + strconv.Itoa(ty) + ".png"
				c.Dalles = append(c.Dalles, dalleCarte{X: arrondi(float64(tx*tailleDalle) - x0), Y: arrondi(float64(ty*tailleDalle) - y0),
					Fond: adresseOSM + chemin, Balise: adresseOSea + chemin})
			}
		}
	}
	return c
}

func arrondi(v float64) float64 { return math.Round(v*10) / 10 }

// sourcesCarte : serveurs des dalles, permis par la politique de sécurité du
// contenu (routes.go).
const sourcesCarte = "https://tile.openstreetmap.org https://tiles.openseamap.org"
