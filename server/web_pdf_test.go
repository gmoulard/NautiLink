package main

import (
	"bytes"
	"compress/zlib"
	"image"
	"image/color"
	"image/jpeg"
	"io"
	"os"
	"regexp"
	"strconv"
	"strings"
	"testing"
	"time"
)

// photoEssai : vrai JPEG de 64 × 48 pixels.
func photoEssai(t *testing.T) []byte {
	t.Helper()
	img := image.NewRGBA(image.Rect(0, 0, 64, 48))
	for x := range 64 {
		for y := range 48 {
			img.Set(x, y, color.RGBA{uint8(x * 4), uint8(y * 5), 200, 255})
		}
	}
	var b bytes.Buffer
	if err := jpeg.Encode(&b, img, nil); err != nil {
		t.Fatal(err)
	}
	return b.Bytes()
}

func TestWinAnsi(t *testing.T) {
	if got := winAnsi("Été — œuvre « 3 € »\n✓"); !bytes.Equal(got, []byte{0xC9, 't', 0xE9, ' ', 0x97, ' ', 0x9C, 'u', 'v', 'r', 'e', ' ', 0xAB, ' ', '3', ' ', 0x80, ' ', 0xBB, '?'}) {
		t.Fatalf("winAnsi : %v", got)
	}
	if chainePDF([]byte(`a(b)\c`)) != `(a\(b\)\\c)` {
		t.Fatal("chainePDF")
	}
}

func TestCouper(t *testing.T) {
	lignes := couper("Les dauphins nous ont accompagnés pendant une heure au large de Groix.\nPuis le vent est tombé.", 150, 10, false)
	if len(lignes) < 3 || lignes[len(lignes)-1] != "Puis le vent est tombé." {
		t.Fatalf("lignes : %q", lignes)
	}
	for _, l := range lignes {
		if largeurTexte(l, 10, false) > 150 {
			t.Fatalf("ligne trop longue : %q", l)
		}
	}
	if l := couper(strings.Repeat("x", 200), 100, 10, false); len(l) < 2 {
		t.Fatalf("mot coupé : %q", l)
	}
}

func TestDimensionsJPEG(t *testing.T) {
	l, h, c, err := dimensionsJPEG(photoEssai(t))
	if err != nil || l != 64 || h != 48 || c != 3 {
		t.Fatalf("dimensions : %d %d %d %v", l, h, c, err)
	}
	if _, _, _, err := dimensionsJPEG(jpegEssai); err == nil {
		t.Fatal("JPEG sans en-tête SOF accepté")
	}
}

// textePDF : contenu décompressé de toutes les pages.
func textePDF(t *testing.T, doc []byte) string {
	t.Helper()
	var tout strings.Builder
	re := regexp.MustCompile(`(?s)/Filter /FlateDecode >>\nstream\n(.*?)\nendstream`)
	for _, m := range re.FindAllSubmatch(doc, -1) {
		r, err := zlib.NewReader(bytes.NewReader(m[1]))
		if err != nil {
			t.Fatal(err)
		}
		b, _ := io.ReadAll(r)
		tout.Write(b)
	}
	return tout.String()
}

// TestExportPDF : RG-NAV-19 (TS-NAV-20) : informations, tracé, alertes SOS
// et journal avec la photo ; structure du PDF valide (table des objets).
func TestExportPDF(t *testing.T) {
	d := donneesNavEssai(false, false).D.(donneesNavigation)
	long := strings.Repeat("Mer belle, vent de nord-ouest force 3. ", 200)
	evts := journalEssai()
	evts[2].Texte = &long
	d.Journal = journalPresente(evts, nil, false)
	doc := exportPDF(d, evts, map[string][]byte{"e4": photoEssai(t)})
	if !bytes.HasPrefix(doc, []byte("%PDF-1.4")) || !bytes.HasSuffix(doc, []byte("%%EOF\n")) {
		t.Fatal("en-tête ou fin du PDF")
	}
	// Chaque entrée de la table des objets pointe sur son objet.
	xref := bytes.LastIndex(doc, []byte("\nxref\n"))
	if xref < 0 {
		t.Fatal("pas de table des objets")
	}
	debut, _ := strconv.Atoi(string(regexp.MustCompile(`startxref\n(\d+)`).FindSubmatch(doc)[1]))
	if debut != xref+1 {
		t.Fatalf("startxref %d, table à %d", debut, xref+1)
	}
	for i, m := range regexp.MustCompile(`(\d{10}) 00000 n `).FindAllSubmatch(doc[xref:], -1) {
		p, _ := strconv.Atoi(string(m[1]))
		if !bytes.HasPrefix(doc[p:], []byte(strconv.Itoa(i+1)+" 0 obj")) {
			t.Fatalf("objet %d mal placé (%d)", i+1, p)
		}
	}
	if !bytes.Contains(doc, []byte("/Subtype /Image /Width 64 /Height 48 /ColorSpace /DeviceRGB")) {
		t.Fatal("photo absente")
	}
	if n := bytes.Count(doc, []byte("/Type /Page ")); n < 2 {
		t.Fatalf("%d page(s) : le long texte doit passer à la page suivante", n)
	}
	texte := textePDF(t, doc)
	for _, attendu := range []string{"Alizé — Glénan", "Informations", "Navigateur : Paul", "Personnes à bord : 3",
		"Port d'attache : Lorient", "Amis : Léa, Secours", "Tracé", "Alertes SOS", "Voie d'eau",
		"Journal de bord", "Début de navigation · 2026-11-20 09:00 UTC", "Note vocale, à écouter sur l'Application web.",
		"en dehors des heures affichées", "page 2"} {
		if !strings.Contains(texte, chainePDF(winAnsi(attendu))[1:len(chainePDF(winAnsi(attendu)))-1]) {
			t.Errorf("%q absent du PDF", attendu)
		}
	}
	if !strings.Contains(texte, "/Im1 Do") || !strings.Contains(texte, " c b Q") || !strings.Contains(texte, " l S Q") {
		t.Error("photo, points ou tracé non dessinés")
	}
	if dossier := os.Getenv("NAUTILINK_PDF_ESSAI"); dossier != "" {
		_ = os.WriteFile(dossier+"/navigation-essai.pdf", doc, 0o644)
	}
}

// TestPDFWeb : avec PostgreSQL : PDF du navigateur et du suiveur
// (RG-NAV-19, RG-PAR-08), refusé sans accès.
func TestPDFWeb(t *testing.T) {
	e := nouvelEssai(t)
	nav, bateau, tel := e.marin("nav@exemple.org", "Navigateur", "Alizé")
	t0 := time.Now().Add(-5 * time.Hour).Truncate(time.Second)
	fin := t0.Add(2 * time.Hour)
	id, _, _ := e.naviguer(nav, bateau, tel, t0, nil)
	photo := uuid(t)
	e.appel("PUT", "/navigations/"+id+"/evenements/"+photo, nav, map[string]any{"type": "photo", "heureAcquisition": heure(t0.Add(time.Hour)),
		"fichier": map[string]any{"typeMedia": "image/jpeg"}})
	if code := e.fichier("PUT", photo, nav, "image/jpeg", photoEssai(t)); code != 204 {
		t.Fatal("photo")
	}
	e.appel("PUT", "/navigations/"+id+"/fin", nav, map[string]any{"id": uuid(t), "type": "fin", "heureAcquisition": heure(fin)})
	lea := e.compte("lea@exemple.org", "Léa")
	e.suivre(nav, lea, "lea@exemple.org", "navigateur", "")
	for _, email := range []string{"nav@exemple.org", "lea@exemple.org"} {
		rec := e.webConnecte(email).envoyer("GET", "/nautilink/navigations/"+id+"/pdf", nil)
		if rec.Code != 200 || rec.Header().Get("Content-Type") != "application/pdf" || !bytes.HasPrefix(rec.Body.Bytes(), []byte("%PDF")) ||
			!strings.Contains(rec.Header().Get("Content-Disposition"), "attachment") || !bytes.Contains(rec.Body.Bytes(), []byte("/Subtype /Image")) {
			t.Fatalf("PDF pour %s : %d %q", email, rec.Code, rec.Header().Get("Content-Type"))
		}
	}
	e.compte("eve@exemple.org", "Ève")
	if rec := e.webConnecte("eve@exemple.org").envoyer("GET", "/nautilink/navigations/"+id+"/pdf", nil); rec.Code != 404 {
		t.Fatalf("PDF sans accès : %d", rec.Code)
	}
}
