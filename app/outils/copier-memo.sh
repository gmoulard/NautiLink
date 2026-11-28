#!/bin/sh
# Fabrique le mémo sécurité en mer de l'application (RG-SOS-22, D-125, D-192) :
# le texte est rédigé une seule fois, dans la section #securite de site/index.html.
# Le script en tire les sections placées entre les commentaires « memo:debut » et
# « memo:fin » (le mémo, puis l'avertissement) et leurs styles (site/memo.css),
# pour une page autonome lisible hors connexion, sans style.css ni images du site.
# La même page est la copie hors ligne de l'application (assets/memo/securite.html)
# et la page du site ouverte par le lien « Mémo sécurité en mer » des applications
# et de l'Application web (site/memo.html, D-193) ; les deux sont versionnées.
# Lancé par le workflow « Site GitHub Pages » avant chaque construction ;
# l'essai test/memo_test.dart échoue si une copie n'est plus à jour.
# Usage : outils/copier-memo.sh [fichier de sortie]   (par défaut les deux copies)
set -eu
ici=$(cd "$(dirname "$0")/.." && pwd)
site="$ici/../site"
sortie=${1:-"$ici/assets/memo/securite.html"}
mkdir -p "$(dirname "$sortie")"
if ! grep -q '<!-- memo:debut -->' "$site/index.html"; then
  echo "copier-memo.sh : aucun commentaire memo:debut dans site/index.html" >&2
  exit 1
fi
{
  cat <<'FIN'
<!doctype html>
<html lang="fr" class="hors-site">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>Mémo sécurité en mer · NautiLink</title>
<!-- Fichier fabriqué par app/outils/copier-memo.sh à partir de site/index.html et site/memo.css : ne pas le modifier. -->
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Inter:ital,wght@0,400;0,500;0,600;0,700;0,800;1,500&family=JetBrains+Mono:wght@500&display=swap">
<style>
FIN
  cat "$site/memo.css"
  cat <<'FIN'
</style>
</head>
<body>
<main>
FIN
  sed -n '/<!-- memo:debut -->/,/<!-- memo:fin -->/p' "$site/index.html"
  cat <<'FIN'
</main>
</body>
</html>
FIN
} > "$sortie"
[ $# -gt 0 ] || cp "$sortie" "$site/memo.html"
