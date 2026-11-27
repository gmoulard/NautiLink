package main

import (
	"bytes"
	"context"
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/jpeg"
	"image/png"
	"io"
	"log"
	"net/http"
	"sync"
	"time"
)

// Fond de carte du PDF (TODO-6.18, D-180, RG-NAV-29) : le serveur télécharge
// les dalles d'OpenStreetMap et le balisage d'OpenSeaMap de la carte, les
// assemble en une seule image (JPEG) sous le tracé. Règles d'usage des
// serveurs de dalles : client identifié, dalles gardées en mémoire (7 jours,
// 2 000 au plus), 4 téléchargements à la fois ; une dalle indisponible laisse
// le fond uni de la mer à sa place. Adresses remplacées dans les essais.

type fournisseurDalles struct {
	fond, balise string // adresses de base, sans « / » final
	client       *http.Client
	agent        string

	mu    sync.Mutex
	cache map[string]dalleGardee
}

type dalleGardee struct {
	img image.Image // nil : dalle absente (404, transparente)
	le  time.Time
}

const (
	dureeDalles = 7 * 24 * time.Hour
	maxDalles   = 2000
)

func nouveauxDalles() *fournisseurDalles {
	return &fournisseurDalles{fond: adresseOSM, balise: adresseOSea, client: &http.Client{Timeout: 10 * time.Second},
		agent: "NautiLink/" + version + " (+" + depot + ")", cache: map[string]dalleGardee{}}
}

// dalle : image d'une dalle, nil si le serveur n'en a pas (404) ; erreur si
// le serveur ne répond pas.
func (f *fournisseurDalles) dalle(ctx context.Context, adresse string) (image.Image, error) {
	f.mu.Lock()
	if g, ok := f.cache[adresse]; ok && time.Since(g.le) < dureeDalles {
		f.mu.Unlock()
		return g.img, nil
	}
	f.mu.Unlock()
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, adresse, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", f.agent)
	rep, err := f.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer rep.Body.Close()
	var img image.Image
	switch rep.StatusCode {
	case http.StatusOK:
		corps, err := io.ReadAll(io.LimitReader(rep.Body, 1<<20))
		if err != nil {
			return nil, err
		}
		if img, _, err = image.Decode(bytes.NewReader(corps)); err != nil {
			return nil, err
		}
	case http.StatusNotFound: // pas de balisage sur cette dalle
	default:
		return nil, fmt.Errorf("dalle %s : %s", adresse, rep.Status)
	}
	f.mu.Lock()
	if len(f.cache) >= maxDalles {
		for k, g := range f.cache {
			if time.Since(g.le) >= dureeDalles || len(f.cache) >= maxDalles {
				delete(f.cache, k)
			}
		}
	}
	f.cache[adresse] = dalleGardee{img: img, le: time.Now()}
	f.mu.Unlock()
	return img, nil
}

// composer : fond de la carte c en JPEG, nil si aucune dalle du fond n'a pu
// être téléchargée (le PDF garde alors le fond uni).
func (f *fournisseurDalles) composer(ctx context.Context, c *carte) []byte {
	if f == nil || c == nil || len(c.Dalles) == 0 {
		return nil
	}
	ctx, fin := context.WithTimeout(ctx, 20*time.Second)
	defer fin()
	l, h := int(c.Largeur), int(c.Hauteur)
	toile := image.NewRGBA(image.Rect(0, 0, l, h))
	draw.Draw(toile, toile.Bounds(), &image.Uniform{color.RGBA{0xAA, 0xD3, 0xDF, 0xFF}}, image.Point{}, draw.Src)
	fonds := make([]image.Image, len(c.Dalles))
	balises := make([]image.Image, len(c.Dalles))
	var attente sync.WaitGroup
	jetons := make(chan struct{}, 4)
	var mu sync.Mutex
	recues := 0
	for i, d := range c.Dalles {
		for _, x := range []struct {
			adresse string
			dest    []image.Image
			fond    bool
		}{{f.fond + d.Chemin, fonds, true}, {f.balise + d.Chemin, balises, false}} {
			attente.Add(1)
			go func(i int, adresse string, dest []image.Image, fond bool) {
				defer attente.Done()
				jetons <- struct{}{}
				defer func() { <-jetons }()
				img, err := f.dalle(ctx, adresse)
				if err != nil {
					log.Printf("carte du PDF : %v", err)
					return
				}
				dest[i] = img
				if fond && img != nil {
					mu.Lock()
					recues++
					mu.Unlock()
				}
			}(i, x.adresse, x.dest, x.fond)
		}
	}
	attente.Wait()
	if recues == 0 {
		return nil
	}
	for _, couche := range [][]image.Image{fonds, balises} {
		for i, img := range couche {
			if img == nil {
				continue
			}
			d := c.Dalles[i]
			p := image.Pt(int(d.X+0.5), int(d.Y+0.5))
			draw.Draw(toile, image.Rectangle{Min: p, Max: p.Add(img.Bounds().Size())}, img, img.Bounds().Min, draw.Over)
		}
	}
	var b bytes.Buffer
	if err := jpeg.Encode(&b, toile, &jpeg.Options{Quality: 85}); err != nil {
		return nil
	}
	return b.Bytes()
}

// jpegSurBlanc : image PNG (le logo) posée sur du blanc et codée en JPEG, le
// seul format d'image du PDF (pdf.go).
func jpegSurBlanc(pngOctets []byte) ([]byte, error) {
	img, err := png.Decode(bytes.NewReader(pngOctets))
	if err != nil {
		return nil, err
	}
	toile := image.NewRGBA(img.Bounds())
	draw.Draw(toile, toile.Bounds(), image.White, image.Point{}, draw.Src)
	draw.Draw(toile, toile.Bounds(), img, img.Bounds().Min, draw.Over)
	var b bytes.Buffer
	if err := jpeg.Encode(&b, toile, &jpeg.Options{Quality: 92}); err != nil {
		return nil, err
	}
	return b.Bytes(), nil
}
