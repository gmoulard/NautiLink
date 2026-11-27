package main

import (
	"bytes"
	"context"
	"image"
	"image/color"
	"image/draw"
	"image/jpeg"
	"image/png"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
)

// fauxServeurDalles : dalles du fond vertes et opaques ; balisage rouge
// sur un quart de dalle, transparent ailleurs, absent (404) une fois sur deux.
func fauxServeurDalles(t *testing.T) (*fournisseurDalles, *atomic.Int32, *atomic.Value) {
	t.Helper()
	var appels atomic.Int32
	var agent atomic.Value
	dalle := func(fond bool) []byte {
		img := image.NewRGBA(image.Rect(0, 0, tailleDalle, tailleDalle))
		if fond {
			draw.Draw(img, img.Bounds(), &image.Uniform{color.RGBA{40, 160, 60, 255}}, image.Point{}, draw.Src)
		} else {
			draw.Draw(img, image.Rect(0, 0, 64, 64), &image.Uniform{color.RGBA{220, 30, 30, 255}}, image.Point{}, draw.Src)
		}
		var b bytes.Buffer
		if err := png.Encode(&b, img); err != nil {
			t.Fatal(err)
		}
		return b.Bytes()
	}
	fond, balise := dalle(true), dalle(false)
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		appels.Add(1)
		agent.Store(r.Header.Get("User-Agent"))
		switch {
		case strings.HasPrefix(r.URL.Path, "/fond/"):
			w.Header().Set("Content-Type", "image/png")
			w.Write(fond)
		case strings.HasPrefix(r.URL.Path, "/balise/") && appels.Load()%2 == 0:
			w.Header().Set("Content-Type", "image/png")
			w.Write(balise)
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(srv.Close)
	f := nouveauxDalles()
	f.fond, f.balise, f.client = srv.URL+"/fond", srv.URL+"/balise", srv.Client()
	return f, &appels, &agent
}

// TestComposerFond : D-180 : dalles téléchargées, assemblées à la taille
// de la carte, gardées en mémoire ; client identifié ; sans serveur, rien.
func TestComposerFond(t *testing.T) {
	f, appels, agent := fauxServeurDalles(t)
	c := carteDe(journalEssai(), false, nil, 499, 300, true)
	j := f.composer(context.Background(), c)
	img, err := jpeg.Decode(bytes.NewReader(j))
	if err != nil {
		t.Fatal(err)
	}
	if img.Bounds().Dx() != 499 || img.Bounds().Dy() != 300 {
		t.Fatalf("taille : %v", img.Bounds())
	}
	if r, g, _, _ := img.At(250, 150).RGBA(); g>>8 < 130 || r>>8 > 90 {
		t.Fatalf("fond non dessiné : %v", img.At(250, 150))
	}
	if n := int(appels.Load()); n != 2*len(c.Dalles) {
		t.Fatalf("%d téléchargements pour %d dalles", n, len(c.Dalles))
	}
	if a, _ := agent.Load().(string); !strings.HasPrefix(a, "NautiLink/") {
		t.Fatalf("client : %q", a)
	}
	f.composer(context.Background(), c)
	if n := int(appels.Load()); n != 2*len(c.Dalles) {
		t.Fatalf("dalles non gardées : %d téléchargements", n)
	}
	f.fond, f.balise, f.cache = "http://127.0.0.1:1", "http://127.0.0.1:1", map[string]dalleGardee{}
	if f.composer(context.Background(), c) != nil {
		t.Fatal("serveur absent : fond attendu nil")
	}
}

// TestJpegSurBlanc : logo PNG transparent posé sur du blanc.
func TestJpegSurBlanc(t *testing.T) {
	logo, err := fichiersWeb.ReadFile("web/static/logo-nautilink.png")
	if err != nil {
		t.Fatal(err)
	}
	j, err := jpegSurBlanc(logo)
	if err != nil {
		t.Fatal(err)
	}
	if l, h, c, err := dimensionsJPEG(j); err != nil || l != 96 || h != 96 || c != 3 {
		t.Fatalf("logo : %d %d %d %v", l, h, c, err)
	}
}
