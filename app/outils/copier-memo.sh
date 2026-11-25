#!/bin/sh
# Copie le mémo sécurité en mer du site dans les ressources de l'application
# (RG-SOS-22, D-125) : le texte est rédigé une seule fois, dans site/securite.html.
# Lancé par le workflow « Site GitHub Pages » avant chaque construction ;
# l'essai test/memo_test.dart échoue si la copie n'est plus à jour.
set -eu
ici=$(cd "$(dirname "$0")/.." && pwd)
mkdir -p "$ici/assets/memo"
cp "$ici/../site/securite.html" "$ici/assets/memo/securite.html"
