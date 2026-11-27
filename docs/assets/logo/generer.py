#!/usr/bin/env python3
"""Génère les fichiers du logo NautiLink (TODO-8.1).

Redessin vectoriel du logo validé (D-98, ../logo-nautilink.png), puis
déclinaisons (claire, sombre, monochrome) et icônes Android, iPhone et Web.

Dépendances : Pillow, cairosvg, fonttools (pip install pillow cairosvg fonttools).
Lancement depuis la racine du dépôt : python3 docs/assets/logo/generer.py

Les textes sont convertis en tracés : les SVG ne dépendent d'aucune police.
Polices (licence OFL) dans polices/ : Montserrat ExtraBold Italic (nom),
Open Sans Medium Italic (signature).
"""

import io
import json
import math
import os

import cairosvg
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from PIL import Image

ICI = os.path.dirname(os.path.abspath(__file__))
RACINE = os.path.normpath(os.path.join(ICI, "..", "..", ".."))
APP = os.path.join(RACINE, "app")

# Couleurs de marque (docs/05-identite-marque.md §6 et §14)
MARINE = "#082B46"
TURQUOISE = "#13A6AD"
AQUA = "#7EDDE4"
ORANGE = "#F89D29"
BLANC = "#FFFFFF"
BLEU_ACTION = "#0E6BA8"

# Repère de dessin : carré de 1254 unités, celui de l'image validée.
T = 1254
CX = 628  # axe vertical du symbole


# --------------------------------------------------------------------------
# Outils géométriques
# --------------------------------------------------------------------------

def pt(cx, cy, r, a):
    t = math.radians(a)
    return cx + r * math.cos(t), cy + r * math.sin(t)


def arc(cx, cy, r, a1, a2):
    """Arc de cercle de a1 à a2 degrés (sens horaire, repère SVG)."""
    x1, y1 = pt(cx, cy, r, a1)
    x2, y2 = pt(cx, cy, r, a2)
    grand = 1 if (a2 - a1) % 360 > 180 else 0
    return f"M{x1:.1f},{y1:.1f}A{r},{r} 0 {grand} 1 {x2:.1f},{y2:.1f}"


def catmull(points, n=24):
    """Courbe lisse passant par les points (Catmull-Rom), échantillonnée."""
    p = [points[0]] + points + [points[-1]]
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for k in range(n):
            t = k / n
            t2, t3 = t * t, t * t * t
            out.append(tuple(
                0.5 * (2 * p1[j] + (-p0[j] + p2[j]) * t
                       + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                       + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3)
                for j in range(2)))
    out.append(points[-1])
    return out


def vague(points, epaisseur, pic=0.5):
    """Bande effilée aux deux bouts le long d'une courbe (vagues, souligné)."""
    c = catmull(points)
    long = [0.0]
    for a, b in zip(c, c[1:]):
        long.append(long[-1] + math.dist(a, b))
    haut, bas = [], []
    for i, (x, y) in enumerate(c):
        u = long[i] / long[-1]
        # profil : 0 aux extrémités, maximum en « pic »
        v = u / pic if u < pic else (1 - u) / (1 - pic)
        w = epaisseur * math.sin(math.pi / 2 * max(v, 0)) ** 0.8 / 2
        a = c[max(i - 1, 0)]
        b = c[min(i + 1, len(c) - 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        n = math.hypot(dx, dy) or 1
        nx, ny = -dy / n, dx / n
        haut.append((x + nx * w, y + ny * w))
        bas.append((x - nx * w, y - ny * w))
    tout = haut + bas[::-1]
    return "M" + "L".join(f"{x:.1f},{y:.1f}" for x, y in tout) + "Z"


# --------------------------------------------------------------------------
# Textes en tracés
# --------------------------------------------------------------------------

def texte(police, chaine, x_centre, ligne, largeur, espace=0.0):
    """Tracé SVG d'une chaîne, centrée sur x_centre, ajustée à la largeur."""
    f = TTFont(os.path.join(ICI, "polices", police))
    cmap = f.getBestCmap()
    gs = f.getGlyphSet()
    hmtx = f["hmtx"]
    upm = f["head"].unitsPerEm
    noms = [cmap[ord(c)] for c in chaine]
    avance = sum(hmtx[n][0] for n in noms) + espace * upm * (len(noms) - 1)
    # chasse du dernier glyphe sans approche droite
    e = largeur / avance
    x0 = x_centre - largeur / 2
    morceaux = []
    x = 0.0
    for n in noms:
        pen = SVGPathPen(gs)
        tp = TransformPen(pen, (e, 0, 0, -e, x0 + x * e, ligne))
        gs[n].draw(tp)
        morceaux.append(pen.getCommands())
        x += hmtx[n][0] + espace * upm
    return morceaux


# --------------------------------------------------------------------------
# Géométrie du logo (relevée sur l'image validée)
# --------------------------------------------------------------------------

ANNEAU = (CX, 495, 385)
INTERIEUR = (CX, 495, 285)
AMIS = [(372, 370, 64), (CX, 210, 76), (884, 370, 64)]
REPERE = (CX, 345, 60, 452)  # centre, rayon de la tête, pointe


def anneau_traces():
    cx, cy, r = ANNEAU
    morceaux = [(3.3, 15.8), (164.2, 176.7), (187.2, 261.0), (279.0, 352.8)]
    return [arc(cx, cy, r, a, b) for a, b in morceaux]


def arcs_interieurs():
    cx, cy, r = INTERIEUR
    return [arc(cx, cy, r, 223.4, 250.2), arc(cx, cy, r, 289.8, 316.6)]


def pointes():
    nord = f"M{CX},25L{CX + 30},131Q{CX},113 {CX - 30},131Z"
    ouest = "M162,482L284,452Q268,482 284,512Z"
    est = f"M{2 * CX - 162},482L{2 * CX - 284},452Q{2 * CX - 268},482 {2 * CX - 284},512Z"
    return [nord, ouest, est]


def ami(cx, cy, R, i):
    rc = R - 10  # le buste rejoint le cercle
    tete = f'<circle cx="{cx}" cy="{cy - 0.2 * R:.1f}" r="{0.3 * R:.1f}"/>'
    corps = (f'<ellipse cx="{cx}" cy="{cy + 0.68 * R:.1f}" rx="{0.64 * R:.1f}" '
             f'ry="{0.5 * R:.1f}" clip-path="url(#clip-s{i})"/>')
    clip = f'<clipPath id="clip-s{i}"><circle cx="{cx}" cy="{cy}" r="{rc:.1f}"/></clipPath>'
    return clip, tete + corps


def repere_trace(trou):
    cx, cy, R, pointe = REPERE
    d = pointe - cy
    th = math.degrees(math.asin(R / d))
    a1, a2 = 90 - (90 - th), 90 + (90 - th)
    x1, y1 = pt(cx, cy, R, a1)
    x2, y2 = pt(cx, cy, R, a2)
    p = f"M{cx},{pointe}L{x1:.1f},{y1:.1f}A{R},{R} 0 1 0 {x2:.1f},{y2:.1f}Z"
    if trou:
        r = 28
        p += f"M{cx - r},{cy}a{r},{r} 0 1 0 {2 * r},0a{r},{r} 0 1 0 {-2 * r},0Z"
    return p


GRAND_VOILE = "M636,462Q560,505 511,598Q570,580 627,575Z"
FOC = "M665,430Q649,500 639,573L737,573Z"
PONT = "M558,590L741,582L744,594L566,599Z"
COQUE = "M470,618L801,592L742,666L606,656Q532,642 470,618Z"

VAGUE_1 = vague([(135, 668), (250, 632), (330, 626), (450, 652), (560, 696),
                 (650, 704), (760, 676), (880, 650), (1000, 636), (1120, 626)], 48, 0.27)
VAGUE_2 = vague([(300, 694), (450, 688), (600, 712), (760, 690), (900, 676),
                 (1010, 678)], 26, 0.45)
SOULIGNE = vague([(72, 996), (250, 968), (450, 966), (600, 960), (750, 950),
                  (912, 942)], 46, 0.5)


# --------------------------------------------------------------------------
# Palettes des déclinaisons
# --------------------------------------------------------------------------

DEFS_COULEUR = f"""
<linearGradient id="g-fond" x1="0" y1="1254" x2="1254" y2="0" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#02386E"/><stop offset="0.45" stop-color="#011E4C"/>
  <stop offset="0.75" stop-color="#03498A"/><stop offset="1" stop-color="#00A8E0"/>
</linearGradient>
<linearGradient id="g-anneau" x1="0" y1="100" x2="0" y2="620" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#FFFFFF"/><stop offset="0.55" stop-color="#E4F5FF"/>
  <stop offset="1" stop-color="#8FD8FD"/>
</linearGradient>
<linearGradient id="g-repere" x1="0" y1="285" x2="0" y2="452" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#FDC444"/><stop offset="0.5" stop-color="{ORANGE}"/>
  <stop offset="1" stop-color="#E2832A"/>
</linearGradient>
<linearGradient id="g-foc" x1="639" y1="0" x2="737" y2="0" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#BFE2F7"/><stop offset="0.45" stop-color="#FFFFFF"/>
</linearGradient>
<linearGradient id="g-coque" x1="0" y1="610" x2="0" y2="666" gradientUnits="userSpaceOnUse">
  <stop offset="0.35" stop-color="#FFFFFF"/><stop offset="1" stop-color="#8FD0F5"/>
</linearGradient>
<linearGradient id="g-vague1" x1="135" y1="0" x2="1118" y2="0" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#2FB8EE"/><stop offset="0.3" stop-color="#5DD3FA"/>
  <stop offset="0.6" stop-color="#47C6F5"/><stop offset="1" stop-color="#1E9BE6"/>
</linearGradient>
<linearGradient id="g-vague2" x1="300" y1="0" x2="1000" y2="0" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#1C86DD"/><stop offset="0.45" stop-color="#5FE0FF"/>
  <stop offset="0.7" stop-color="#2A9BEA"/><stop offset="1" stop-color="#1252B0"/>
</linearGradient>
<linearGradient id="g-link" x1="700" y1="0" x2="1150" y2="0" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#14B4E6"/><stop offset="1" stop-color="#3CE5FD"/>
</linearGradient>
<linearGradient id="g-souligne" x1="72" y1="0" x2="912" y2="0" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#2FC4F2"/><stop offset="0.5" stop-color="#22B6E8"/>
  <stop offset="1" stop-color="#0E9FD6"/>
</linearGradient>
"""

SOMBRE = dict(
    defs=DEFS_COULEUR, anneau="url(#g-anneau)", trait=BLANC,
    ondes=["#2A8BE8", "#1F73D6", "#1A5FC0"], ondes_op=[1, 0.8, 0.5],
    repere="url(#g-repere)", trou=BLANC, liseré="#E07A14",
    voile=BLANC, foc="url(#g-foc)", coque="url(#g-coque)",
    vague1="url(#g-vague1)", vague2="url(#g-vague2)",
    nauti=BLANC, link="url(#g-link)", souligne="url(#g-souligne)", signature=BLANC,
)

# Fond clair : le blanc devient bleu marine, le cyan devient turquoise
# (le cyan d'origine est illisible sur blanc). Choix non décidé, à valider.
CLAIR = dict(
    defs=f"""
<linearGradient id="g-vague1" x1="135" y1="0" x2="1118" y2="0" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="{TURQUOISE}"/><stop offset="0.4" stop-color="#3FC3D6"/>
  <stop offset="1" stop-color="{BLEU_ACTION}"/>
</linearGradient>
<linearGradient id="g-repere" x1="0" y1="285" x2="0" y2="452" gradientUnits="userSpaceOnUse">
  <stop offset="0" stop-color="#FDC444"/><stop offset="0.5" stop-color="{ORANGE}"/>
  <stop offset="1" stop-color="#E2832A"/>
</linearGradient>""",
    anneau=MARINE, trait=MARINE,
    ondes=[BLEU_ACTION, BLEU_ACTION, BLEU_ACTION], ondes_op=[0.9, 0.65, 0.4],
    repere="url(#g-repere)", trou=BLANC, liseré="#E07A14",
    voile=MARINE, foc=MARINE, coque=MARINE,
    vague1="url(#g-vague1)", vague2=AQUA,
    nauti=MARINE, link=TURQUOISE, souligne=TURQUOISE, signature=MARINE,
)


def mono(c):
    return dict(defs="", anneau=c, trait=c, ondes=[c, c, c], ondes_op=[1, 1, 1],
                repere=c, trou=None, liseré=None, voile=c, foc=c, coque=c,
                vague1=c, vague2=c, nauti=c, link=c, souligne=c, signature=c)


# --------------------------------------------------------------------------
# Assemblage
# --------------------------------------------------------------------------

def symbole(P):
    defs, corps = [], []
    # ondes autour du repère
    cx, cy = REPERE[0], REPERE[1] + 14
    for r, c, o in zip((88, 122, 156), P["ondes"], P["ondes_op"]):
        for a, b in ((146, 214), (-34, 34)):
            corps.append(f'<path d="{arc(cx, cy, r, a, b)}" fill="none" stroke="{c}" '
                         f'stroke-opacity="{o}" stroke-width="15" stroke-linecap="round"/>')
    # anneau, pointes, arcs entre amis
    for d in anneau_traces():
        corps.append(f'<path d="{d}" fill="none" stroke="{P["anneau"]}" stroke-width="14"/>')
    for d in pointes():
        corps.append(f'<path d="{d}" fill="{P["trait"]}"/>')
    for d in arcs_interieurs():
        corps.append(f'<path d="{d}" fill="none" stroke="{P["trait"]}" stroke-width="11"/>')
    # amis
    for i, (x, y, R) in enumerate(AMIS):
        clip, perso = ami(x, y, R, i)
        defs.append(clip)
        corps.append(f'<circle cx="{x}" cy="{y}" r="{R - 6.5}" fill="none" '
                     f'stroke="{P["trait"]}" stroke-width="13"/>')
        corps.append(f'<g fill="{P["trait"]}">{perso}</g>')
    # repère GPS
    cx, cy = REPERE[0], REPERE[1]
    if P["trou"]:
        corps.append(f'<path d="{repere_trace(False)}" fill="{P["repere"]}"/>')
        corps.append(f'<circle cx="{cx}" cy="{cy}" r="28" fill="{P["trou"]}" '
                     f'stroke="{P["liseré"]}" stroke-width="5"/>')
    else:
        corps.append(f'<path d="{repere_trace(True)}" fill="{P["repere"]}" fill-rule="evenodd"/>')
    # vagues, découpées sous la coque
    defs.append('<mask id="m-coque" maskUnits="userSpaceOnUse" x="0" y="0" width="1254" height="1254">'
                '<rect width="1254" height="1254" fill="#fff"/>'
                f'<path d="{COQUE}" fill="#000" stroke="#000" stroke-width="16" stroke-linejoin="round"/>'
                '</mask>')
    defs.append('<mask id="m-vague1" maskUnits="userSpaceOnUse" x="0" y="0" width="1254" height="1254">'
                '<rect width="1254" height="1254" fill="#fff"/>'
                f'<path d="{VAGUE_1}" fill="#000" stroke="#000" stroke-width="10"/>'
                '</mask>')
    corps.append(f'<g mask="url(#m-coque)"><path d="{VAGUE_2}" fill="{P["vague2"]}" mask="url(#m-vague1)"/>'
                 f'<path d="{VAGUE_1}" fill="{P["vague1"]}"/></g>')
    # bateau
    corps.append(f'<path d="{GRAND_VOILE}" fill="{P["voile"]}"/>')
    corps.append(f'<path d="{FOC}" fill="{P["foc"]}"/>')
    corps.append(f'<path d="{PONT}" fill="{P["voile"]}"/>')
    corps.append(f'<path d="{COQUE}" fill="{P["coque"]}"/>')
    return defs, corps


def nom(P):
    morceaux = texte("montserrat-latin-800-italic.woff", "NautiLink", 628, 915, 1050, -0.01)
    nauti = "".join(morceaux[:5])
    link = "".join(morceaux[5:])
    return [f'<path d="{nauti}" fill="{P["nauti"]}"/>',
            f'<path d="{link}" fill="{P["link"]}"/>',
            f'<path d="{SOULIGNE}" fill="{P["souligne"]}"/>']


def signature(P):
    m = texte("open-sans-latin-500-italic.woff", "Your sea, your safety, your story.",
              629, 1080, 978)
    return [f'<path d="{"".join(m)}" fill="{P["signature"]}"/>']


def svg(viewbox, defs, corps, titre):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{viewbox}">\n'
            f'<title>{titre}</title>\n<defs>{"".join(defs)}</defs>\n'
            + "\n".join(corps) + "\n</svg>\n")


def composer(forme, P, fond=None, titre="NautiLink"):
    """forme : symbole, logo (symbole et nom), signature (logo et signature)."""
    defs, corps = symbole(P)
    defs = [P["defs"]] + defs
    if forme in ("logo", "signature"):
        corps += nom(P)
    if forme == "signature":
        corps += signature(P)
    vb = {"symbole": "120 10 1014 715", "logo": "50 10 1154 1010",
          "signature": "50 10 1154 1110", "carre": f"0 0 {T} {T}"}
    if fond:
        corps.insert(0, fond)
        forme = "carre"
    return svg(vb[forme], defs, corps, titre)


FOND_ARRONDI = f'<rect width="{T}" height="{T}" rx="210" fill="url(#g-fond)"/>'
FOND_CARRE = f'<rect width="{T}" height="{T}" fill="url(#g-fond)"/>'


def icone(P, echelle, fond):
    """Symbole centré dans un carré de 1254, réduit de « echelle »."""
    defs, corps = symbole(P)
    cxs, cys = 627, 367  # centre de la boîte du symbole
    g = (f'<g transform="translate(627 627) scale({echelle}) translate({-cxs} {-cys})">'
         + "".join(corps) + "</g>")
    c = ([fond] if fond else []) + [g]
    return svg(f"0 0 {T} {T}", [P["defs"]] + defs, c, "NautiLink")


def fond_seul():
    return svg(f"0 0 {T} {T}", [DEFS_COULEUR], [FOND_CARRE], "NautiLink, fond")


# --------------------------------------------------------------------------
# Rendus
# --------------------------------------------------------------------------

def png(source, chemin, taille, opaque=False):
    """Rendu PNG de largeur « taille » ; opaque : sans transparence (iPhone)."""
    data = cairosvg.svg2png(bytestring=source.encode(), output_width=taille)
    im = Image.open(io.BytesIO(data)).convert("RGBA")
    if opaque:
        fondu = Image.new("RGBA", im.size, MARINE)
        fondu.alpha_composite(im)
        im = fondu.convert("RGB")
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    im.save(chemin, optimize=True)


def ecrire(chemin, contenu):
    os.makedirs(os.path.dirname(chemin), exist_ok=True)
    with open(chemin, "w", encoding="utf-8") as f:
        f.write(contenu)


def main():
    themes = {"sombre": SOMBRE, "clair": CLAIR, "monochrome": mono(MARINE),
              "monochrome-blanc": mono(BLANC)}
    formes = {"symbole": "symbole", "logo": "logo", "signature": "logo-signature"}

    # 1. Sources vectorielles
    ecrire(os.path.join(ICI, "nautilink-icone.svg"),
           composer("signature", SOMBRE, FOND_ARRONDI, "NautiLink, logo validé"))
    for t, P in themes.items():
        for f, n in formes.items():
            ecrire(os.path.join(ICI, f"nautilink-{n}-{t}.svg"),
                   composer(f, P, titre=f"NautiLink, {n}, {t}"))

    # Icône : symbole seul (D-98, 05-identite-marque §5.4 point 3)
    avant_plan = icone(SOMBRE, 0.64, None)  # zone sûre : cercle de 66 dp sur 108
    mono_android = icone(mono(BLANC), 0.64, None)
    ios = icone(SOMBRE, 0.95, FOND_CARRE)
    ios_sombre = icone(SOMBRE, 0.95, None)
    ios_teinte = icone(mono(BLANC), 0.95, None)
    lanceur = icone(SOMBRE, 0.88, f'<rect x="40" y="40" width="1174" height="1174" rx="200" fill="url(#g-fond)"/>')
    web = icone(SOMBRE, 0.88, FOND_ARRONDI)
    web_masquable = icone(SOMBRE, 0.8, FOND_CARRE)  # zone sûre : 80 %
    sources = {"icone-avant-plan.svg": avant_plan, "icone-arriere-plan.svg": fond_seul(),
               "icone-monochrome-android.svg": mono_android, "icone-ios.svg": ios,
               "icone-ios-sombre.svg": ios_sombre, "icone-ios-teinte.svg": ios_teinte,
               "icone-lanceur.svg": lanceur}
    for n, s in sources.items():
        ecrire(os.path.join(ICI, "icones", n), s)

    # 2. PNG de référence
    for t in themes:
        for f, n in formes.items():
            png(composer(f, themes[t]), os.path.join(ICI, "png", f"nautilink-{n}-{t}.png"), 1024)
    png(composer("signature", SOMBRE, FOND_ARRONDI), os.path.join(ICI, "png", "nautilink-icone.png"), 1024)
    png(ios, os.path.join(ICI, "icones", "ios-1024.png"), 1024, opaque=True)
    png(ios_sombre, os.path.join(ICI, "icones", "ios-1024-sombre.png"), 1024)
    png(ios_teinte, os.path.join(ICI, "icones", "ios-1024-teinte.png"), 1024)
    png(ios, os.path.join(ICI, "icones", "google-play-512.png"), 512, opaque=True)
    png(avant_plan, os.path.join(ICI, "icones", "android-avant-plan-432.png"), 432)
    png(fond_seul(), os.path.join(ICI, "icones", "android-arriere-plan-432.png"), 432)
    png(mono_android, os.path.join(ICI, "icones", "android-monochrome-432.png"), 432)

    # 3. Android : mipmap
    res = os.path.join(APP, "android", "app", "src", "main", "res")
    if os.path.isdir(res):
        for d, k in {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}.items():
            m = os.path.join(res, f"mipmap-{d}")
            png(lanceur, os.path.join(m, "ic_launcher.png"), round(48 * k))
            png(avant_plan, os.path.join(m, "ic_launcher_foreground.png"), round(108 * k))
            png(fond_seul(), os.path.join(m, "ic_launcher_background.png"), round(108 * k))
            png(mono_android, os.path.join(m, "ic_launcher_monochrome.png"), round(108 * k))
        ecrire(os.path.join(res, "mipmap-anydpi-v26", "ic_launcher.xml"),
               '<?xml version="1.0" encoding="utf-8"?>\n'
               '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
               '    <background android:drawable="@mipmap/ic_launcher_background"/>\n'
               '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
               '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome"/>\n'
               '</adaptive-icon>\n')

    # 4. iPhone : AppIcon (format Flutter, opaque)
    ai = os.path.join(APP, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if os.path.isdir(ai):
        contenu = json.load(open(os.path.join(ai, "Contents.json"), encoding="utf-8"))
        for img in contenu["images"]:
            cote = float(img["size"].split("x")[0]) * int(img["scale"][0])
            png(ios, os.path.join(ai, img["filename"]), round(cote), opaque=True)

    # 5. Web
    w = os.path.join(APP, "web")
    if os.path.isdir(w):
        png(web, os.path.join(w, "favicon.png"), 32)
        png(web, os.path.join(w, "icons", "Icon-192.png"), 192)
        png(web, os.path.join(w, "icons", "Icon-512.png"), 512)
        png(web_masquable, os.path.join(w, "icons", "Icon-maskable-192.png"), 192, opaque=True)
        png(web_masquable, os.path.join(w, "icons", "Icon-maskable-512.png"), 512, opaque=True)


if __name__ == "__main__":
    main()
