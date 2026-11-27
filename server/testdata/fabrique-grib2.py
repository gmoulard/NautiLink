# Fabrique des fichiers GRIB2 d'essai avec eccodes (référence de décodage) :
# grille régulière lat/lon, hauteur des vagues (discipline 10, catégorie 0,
# paramètre 3), compression CCSDS (modèle 5.42), avec et sans masque.
import sys, json, math
import numpy as np
import eccodes as ec

sortie = sys.argv[1]

def message(ni, nj, la1, lo1, la2, lo2, di, dj, valeurs, masque, scan, bits, f):
    h = ec.codes_grib_new_from_samples("regular_ll_sfc_grib2")
    ec.codes_set(h, "discipline", 10)
    ec.codes_set(h, "parameterCategory", 0)
    ec.codes_set(h, "parameterNumber", 3)
    ec.codes_set(h, "typeOfFirstFixedSurface", 1)
    ec.codes_set(h, "dataDate", 20261126)
    ec.codes_set(h, "dataTime", 1200)
    ec.codes_set(h, "stepUnits", 1)
    ec.codes_set(h, "forecastTime", 11)
    ec.codes_set(h, "Ni", ni)
    ec.codes_set(h, "Nj", nj)
    ec.codes_set(h, "jScansPositively", 1 if scan & 0x40 else 0)
    ec.codes_set(h, "iScansNegatively", 0)
    ec.codes_set(h, "latitudeOfFirstGridPointInDegrees", la1)
    ec.codes_set(h, "longitudeOfFirstGridPointInDegrees", lo1)
    ec.codes_set(h, "latitudeOfLastGridPointInDegrees", la2)
    ec.codes_set(h, "longitudeOfLastGridPointInDegrees", lo2)
    ec.codes_set(h, "iDirectionIncrementInDegrees", di)
    ec.codes_set(h, "jDirectionIncrementInDegrees", dj)
    ec.codes_set(h, "packingType", "grid_ccsds")
    ec.codes_set(h, "bitsPerValue", bits)
    if masque is not None:
        ec.codes_set(h, "bitmapPresent", 1)
        ec.codes_set(h, "missingValue", 9999)
        v = np.where(masque, 9999.0, valeurs)
    else:
        v = valeurs
    ec.codes_set_values(h, v.flatten())
    ec.codes_write(h, f)
    # relecture par eccodes : valeurs décodées de référence
    ec.codes_release(h)

with open(sortie + ".grib2", "wb") as f:
    # 1) grille 41 x 31 sans masque, du nord au sud (scan 0), 0,025°
    ni, nj = 41, 31
    j, i = np.mgrid[0:nj, 0:ni]
    a = 0.84 + 0.6 * np.sin(i / 5.0) * np.cos(j / 7.0) + 0.002 * i * j
    message(ni, nj, 48.0, 356.0, 47.25, 357.0, 0.025, 0.025, a, None, 0, 16, f)
    # 2) même grille avec terre masquée (coin nord-est), sud vers nord (scan 0x40), 12 bits
    b = 1.5 + 0.9 * np.cos(i / 3.0 + j / 4.0)
    masque = (i > 30) & (j > 20)
    message(ni, nj, 47.25, 356.0, 48.0, 357.0, 0.025, 0.025, b, masque, 0x40, 12, f)
    # 3) champ presque constant (blocs nuls, seconde extension), 16 bits
    c = np.full((nj, ni), 2.0); c[10, 10] = 2.5; c[20, 5:9] = 2.25
    message(ni, nj, 48.0, 356.0, 47.25, 357.0, 0.025, 0.025, c, None, 0, 16, f)

# valeurs de référence décodées par eccodes
ref = []
with open(sortie + ".grib2", "rb") as f:
    while True:
        h = ec.codes_grib_new_from_file(f)
        if h is None:
            break
        vals = ec.codes_get_values(h)
        miss = ec.codes_get(h, "missingValue")
        ref.append({
            "ni": ec.codes_get(h, "Ni"), "nj": ec.codes_get(h, "Nj"),
            "packing": ec.codes_get(h, "packingType"),
            "flags": ec.codes_get(h, "ccsdsFlags"), "bloc": ec.codes_get(h, "ccsdsBlockSize"),
            "rsi": ec.codes_get(h, "ccsdsRsi"),
            "valeurs": [None if v == miss else round(float(v), 6) for v in vals],
        })
        ec.codes_release(h)
with open(sortie + ".json", "w") as f:
    json.dump(ref, f)
print([(r["packing"], r["flags"], r["bloc"], r["rsi"], len(r["valeurs"])) for r in ref])
