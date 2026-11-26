package main

import (
	"bytes"
	"compress/zlib"
	"errors"
	"fmt"
	"strconv"
	"strings"
)

// Petit rédacteur de PDF (export d'une navigation, RG-NAV-19, TODO-6.4),
// sans bibliothèque (08-architecture.md §7) : pages A4, polices standard
// Helvetica et Helvetica-Bold en codage WinAnsi (français compris), texte
// coupé à la largeur de la page, traits, cercles, rectangles et photos JPEG
// incluses telles quelles. Les coordonnées partent du haut de la page.

const (
	largeurA4, hauteurA4 = 595.28, 841.89
	margePDF             = 48.0
)

type imagePDF struct {
	donnees               []byte
	largeur, hauteur, can int
}

type docPDF struct {
	pages   []*bytes.Buffer
	page    *bytes.Buffer
	images  []imagePDF
	y       float64 // position courante depuis le haut
	piedDe  func(numero int) string
	numeros []int
}

func nouveauPDF(pied func(numero int) string) *docPDF {
	d := &docPDF{piedDe: pied}
	d.nouvellePage()
	return d
}

func (d *docPDF) nouvellePage() {
	d.page = &bytes.Buffer{}
	d.pages = append(d.pages, d.page)
	d.y = margePDF
	if d.piedDe != nil {
		d.texte(margePDF, hauteurA4-margePDF/2, 8, false, d.piedDe(len(d.pages)))
	}
}

// besoin : nouvelle page s'il reste moins de h points.
func (d *docPDF) besoin(h float64) {
	if d.y+h > hauteurA4-margePDF {
		d.nouvellePage()
	}
}

func f(v float64) string { return strconv.FormatFloat(v, 'f', 2, 64) }

// winAnsi : texte en codage WinAnsi ; un caractère absent devient « ? ».
func winAnsi(s string) []byte {
	speciaux := map[rune]byte{'€': 0x80, '‚': 0x82, 'ƒ': 0x83, '„': 0x84, '…': 0x85, '†': 0x86, '‡': 0x87, 'ˆ': 0x88,
		'‰': 0x89, 'Š': 0x8A, '‹': 0x8B, 'Œ': 0x8C, 'Ž': 0x8E, '‘': 0x91, '’': 0x92, '“': 0x93, '”': 0x94, '•': 0x95,
		'–': 0x96, '—': 0x97, '˜': 0x98, '™': 0x99, 'š': 0x9A, '›': 0x9B, 'œ': 0x9C, 'ž': 0x9E, 'Ÿ': 0x9F,
		' ': ' ', ' ': 0xA0}
	var b []byte
	for _, r := range s {
		switch c, ok := speciaux[r]; {
		case ok:
			b = append(b, c)
		case r == '\t':
			b = append(b, ' ')
		case r >= 0x20 && r < 0x7F, r >= 0xA0 && r <= 0xFF:
			b = append(b, byte(r))
		case r == '\n' || r == '\r':
		default:
			b = append(b, '?')
		}
	}
	return b
}

// chainePDF : chaîne littérale PDF.
func chainePDF(b []byte) string {
	var s strings.Builder
	s.WriteByte('(')
	for _, c := range b {
		if c == '(' || c == ')' || c == '\\' {
			s.WriteByte('\\')
		}
		s.WriteByte(c)
	}
	s.WriteByte(')')
	return s.String()
}

// largeursHelvetica : chasses de Helvetica (millièmes) de l'espace au tilde.
var largeursHelvetica = [...]int{278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278,
	556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556, 1015, 667, 667, 722, 722, 667,
	611, 778, 722, 278, 500, 667, 556, 833, 722, 778, 667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278,
	278, 278, 469, 556, 333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556, 556, 556,
	333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584}

// largeurTexte : largeur en points ; le gras est compté un peu plus large.
func largeurTexte(s string, taille float64, gras bool) float64 {
	total := 0
	for _, c := range winAnsi(s) {
		if c >= 0x20 && c <= 0x7E {
			total += largeursHelvetica[c-0x20]
		} else {
			total += 556
		}
	}
	l := float64(total) * taille / 1000
	if gras {
		l *= 1.08
	}
	return l
}

// texte : une ligne, y étant la ligne de base depuis le haut de la page.
func (d *docPDF) texte(x, y, taille float64, gras bool, s string) {
	police := "F1"
	if gras {
		police = "F2"
	}
	fmt.Fprintf(d.page, "BT /%s %s Tf %s %s Td %s Tj ET\n", police, f(taille), f(x), f(hauteurA4-y), chainePDF(winAnsi(s)))
}

// couper : lignes d'au plus largeur points, coupées aux espaces.
func couper(s string, largeur, taille float64, gras bool) []string {
	var lignes []string
	for _, para := range strings.Split(strings.ReplaceAll(s, "\r", ""), "\n") {
		ligne := ""
		for _, mot := range strings.Fields(para) {
			essai := strings.TrimSpace(ligne + " " + mot)
			if ligne != "" && largeurTexte(essai, taille, gras) > largeur {
				lignes = append(lignes, ligne)
				essai = mot
			}
			// Mot plus long que la ligne : coupé à la lettre.
			for largeurTexte(essai, taille, gras) > largeur && len([]rune(essai)) > 1 {
				r := []rune(essai)
				n := len(r) - 1
				for n > 1 && largeurTexte(string(r[:n]), taille, gras) > largeur {
					n--
				}
				lignes = append(lignes, string(r[:n]))
				essai = string(r[n:])
			}
			ligne = essai
		}
		lignes = append(lignes, ligne)
	}
	return lignes
}

// paragraphe : texte coupé à la largeur de la page, à partir de retrait,
// avec les sauts de page nécessaires.
func (d *docPDF) paragraphe(s string, taille float64, gras bool, retrait float64) {
	interligne := taille * 1.35
	for _, l := range couper(s, largeurA4-2*margePDF-retrait, taille, gras) {
		d.besoin(interligne)
		d.y += interligne
		d.texte(margePDF+retrait, d.y, taille, gras, l)
	}
}

func (d *docPDF) espace(h float64) { d.y += h }

func couleur(r, g, b int, remplir bool) string {
	op := "RG"
	if remplir {
		op = "rg"
	}
	return fmt.Sprintf("%s %s %s %s ", f(float64(r)/255), f(float64(g)/255), f(float64(b)/255), op)
}

// rectangle : rempli et bordé, depuis le coin haut gauche.
func (d *docPDF) rectangle(x, y, l, h float64, fond [3]int) {
	fmt.Fprintf(d.page, "q %s%s0.5 w %s %s %s %s re B Q\n", couleur(fond[0], fond[1], fond[2], true), couleur(150, 170, 190, false),
		f(x), f(hauteurA4-y-h), f(l), f(h))
}

// polyligne : points (x, y depuis le haut) reliés.
func (d *docPDF) polyligne(points [][2]float64, epaisseur float64, c [3]int) {
	if len(points) < 2 {
		return
	}
	fmt.Fprintf(d.page, "q %s%s w 1 J 1 j %s %s m", couleur(c[0], c[1], c[2], false), f(epaisseur), f(points[0][0]), f(hauteurA4-points[0][1]))
	for _, p := range points[1:] {
		fmt.Fprintf(d.page, " %s %s l", f(p[0]), f(hauteurA4-p[1]))
	}
	d.page.WriteString(" S Q\n")
}

// cercle : disque plein bordé de blanc (quatre arcs de Bézier).
func (d *docPDF) cercle(x, y, r float64, c [3]int) {
	k := 0.5523 * r
	y = hauteurA4 - y
	fmt.Fprintf(d.page, "q %s1 1 1 RG 1 w %s %s m %s %s %s %s %s %s c %s %s %s %s %s %s c %s %s %s %s %s %s c %s %s %s %s %s %s c b Q\n",
		couleur(c[0], c[1], c[2], true), f(x+r), f(y),
		f(x+r), f(y+k), f(x+k), f(y+r), f(x), f(y+r),
		f(x-k), f(y+r), f(x-r), f(y+k), f(x-r), f(y),
		f(x-r), f(y-k), f(x-k), f(y-r), f(x), f(y-r),
		f(x+k), f(y-r), f(x+r), f(y-k), f(x+r), f(y))
}

// dimensionsJPEG : largeur, hauteur et composantes, lues dans l'en-tête SOF.
func dimensionsJPEG(b []byte) (largeur, hauteur, composantes int, err error) {
	if len(b) < 4 || b[0] != 0xFF || b[1] != 0xD8 {
		return 0, 0, 0, errors.New("pas un JPEG")
	}
	for i := 2; i+9 < len(b); {
		if b[i] != 0xFF {
			i++
			continue
		}
		m := b[i+1]
		if m == 0xD8 || m == 0x01 || (m >= 0xD0 && m <= 0xD7) || m == 0xFF {
			i++
			continue
		}
		longueur := int(b[i+2])<<8 | int(b[i+3])
		if m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC {
			return int(b[i+7])<<8 | int(b[i+8]), int(b[i+5])<<8 | int(b[i+6]), int(b[i+9]), nil
		}
		i += 2 + longueur
	}
	return 0, 0, 0, errors.New("JPEG sans dimensions")
}

// image : photo JPEG dans un cadre de l × h points au plus, proportions
// gardées, depuis le coin haut gauche ; rend la hauteur occupée.
func (d *docPDF) image(jpeg []byte, x, y, l, h float64) (float64, error) {
	lp, hp, can, err := dimensionsJPEG(jpeg)
	if err != nil || lp == 0 || hp == 0 || (can != 1 && can != 3 && can != 4) {
		return 0, errors.New("photo illisible")
	}
	echelle := min(l/float64(lp), h/float64(hp))
	lr, hr := float64(lp)*echelle, float64(hp)*echelle
	d.images = append(d.images, imagePDF{donnees: jpeg, largeur: lp, hauteur: hp, can: can})
	fmt.Fprintf(d.page, "q %s 0 0 %s %s %s cm /Im%d Do Q\n", f(lr), f(hr), f(x), f(hauteurA4-y-hr), len(d.images))
	return hr, nil
}

// octets : le document complet.
func (d *docPDF) octets() []byte {
	var sortie bytes.Buffer
	var positions []int
	objet := func(contenu string, flux []byte) int {
		positions = append(positions, sortie.Len())
		n := len(positions)
		fmt.Fprintf(&sortie, "%d 0 obj\n%s", n, contenu)
		if flux != nil {
			sortie.WriteString("\nstream\n")
			sortie.Write(flux)
			sortie.WriteString("\nendstream")
		}
		sortie.WriteString("\nendobj\n")
		return n
	}
	sortie.WriteString("%PDF-1.4\n%\xE2\xE3\xCF\xD3\n")
	// 1 catalogue, 2 arbre des pages, 3 et 4 polices : numéros fixés d'avance.
	positions = append(positions, 0, 0, 0, 0)
	ressourcesImages := ""
	for i, im := range d.images {
		espace := map[int]string{1: "/DeviceGray", 3: "/DeviceRGB", 4: "/DeviceCMYK"}[im.can]
		decode := ""
		if im.can == 4 {
			decode = " /Decode [1 0 1 0 1 0 1 0]"
		}
		n := objet(fmt.Sprintf("<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace %s /BitsPerComponent 8 /Filter /DCTDecode%s /Length %d >>",
			im.largeur, im.hauteur, espace, decode, len(im.donnees)), im.donnees)
		if i == 0 {
		}
		ressourcesImages += fmt.Sprintf(" /Im%d %d 0 R", i+1, n)
	}
	var kids []string
	for _, p := range d.pages {
		var z bytes.Buffer
		w := zlib.NewWriter(&z)
		w.Write(p.Bytes())
		w.Close()
		c := objet(fmt.Sprintf("<< /Length %d /Filter /FlateDecode >>", z.Len()), z.Bytes())
		pg := objet(fmt.Sprintf("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %s %s] /Contents %d 0 R /Resources << /Font << /F1 3 0 R /F2 4 0 R >> /XObject <<%s >> >> >>",
			f(largeurA4), f(hauteurA4), c, ressourcesImages), nil)
		kids = append(kids, strconv.Itoa(pg)+" 0 R")
	}
	fixe := func(n int, contenu string) {
		positions[n-1] = sortie.Len()
		fmt.Fprintf(&sortie, "%d 0 obj\n%s\nendobj\n", n, contenu)
	}
	fixe(1, "<< /Type /Catalog /Pages 2 0 R >>")
	fixe(2, fmt.Sprintf("<< /Type /Pages /Kids [%s] /Count %d >>", strings.Join(kids, " "), len(kids)))
	fixe(3, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>")
	fixe(4, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>")
	debutXref := sortie.Len()
	fmt.Fprintf(&sortie, "xref\n0 %d\n0000000000 65535 f \n", len(positions)+1)
	for _, p := range positions {
		fmt.Fprintf(&sortie, "%010d 00000 n \n", p)
	}
	fmt.Fprintf(&sortie, "trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n", len(positions)+1, debutXref)
	return sortie.Bytes()
}
