#!/bin/sh
# Déploiement de test reproductible (TODO-3.4) : construit et lance
# compose.test.yaml, vérifie le point de santé (base « ok »), envoie un e-mail
# d'essai et vérifie qu'il est capturé par Mailpit, puis arrête tout.
# Garder l'environnement lancé : GARDER=1 ./essai-test.sh
# Fichiers compose : COMPOSE_FILE (par défaut compose.test.yaml), par exemple pour
# ajouter un fichier de surcharge propre au poste.
set -eu
cd "$(dirname "$0")"
export COMPOSE_FILE="${COMPOSE_FILE:-compose.test.yaml}"
dc="docker compose"
arreter() { [ "${GARDER:-0}" = 1 ] || $dc down -v --remove-orphans >/dev/null 2>&1; }
trap arreter EXIT

$dc up -d --build --wait --wait-timeout 180

i=0
until sante=$(curl -fsS http://127.0.0.1:8080/nautilink/api/sante 2>/dev/null) && echo "$sante" | grep -q '"base":"ok"'; do
  i=$((i + 1))
  [ "$i" -lt 30 ] || { echo "échec : point de santé : ${sante:-sans réponse}"; $dc logs nautilink; exit 1; }
  sleep 1
done
echo "santé : $sante"

$dc exec -T nautilink /nautilink-server mail-essai essai@example.org
i=0
until curl -fsS http://127.0.0.1:8025/api/v1/messages | grep -q 'essai@example.org'; do
  i=$((i + 1))
  [ "$i" -lt 15 ] || { echo "échec : e-mail d'essai non reçu par Mailpit"; exit 1; }
  sleep 1
done
echo "e-mail d'essai reçu par Mailpit"

# Création d'un compte par l'API : migrations faites, e-mail de vérification envoyé.
code=$(curl -s -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' \
  -d '{"email":"marin@example.org","motDePasse":"motdepasse","nom":"Marin","avertissementVersion":"2026-11-24"}' \
  http://127.0.0.1:8080/nautilink/api/v1/comptes)
[ "$code" = 201 ] || { echo "échec : création de compte : $code"; $dc logs nautilink; exit 1; }
i=0
until curl -fsS http://127.0.0.1:8025/api/v1/messages | grep -q 'marin@example.org'; do
  i=$((i + 1))
  [ "$i" -lt 15 ] || { echo "échec : e-mail de vérification non reçu par Mailpit"; exit 1; }
  sleep 1
done
echo "compte créé, e-mail de vérification reçu"
echo "essai réussi"
