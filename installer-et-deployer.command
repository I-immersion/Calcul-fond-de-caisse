#!/bin/bash
set -u
PROJ="$(cd "$(dirname "$0")" && pwd)"
MARQUEUR="Calcul fond de caisse"
CIBLE="index.html"
REPO_URL="https://github.com/I-immersion/Calcul-fond-de-caisse.git"
PAGE="https://i-immersion.github.io/Calcul-fond-de-caisse/"
ZONES=("$HOME/Downloads" "$HOME/Desktop")

echo "════════════════════════════════════════"
echo "   LUMIIA · Calcul fond de caisse"
echo "════════════════════════════════════════"

for Z in "${ZONES[@]}"; do
  [ -d "$Z" ] || continue
  while IFS= read -r zip; do
    TMP=$(mktemp -d)
    if unzip -qo "$zip" -d "$TMP" 2>/dev/null && grep -rq "$MARQUEUR" "$TMP" 2>/dev/null; then
      find "$TMP" -type f -name '*.html' -exec cp {} "$Z"/ \;
      rm -f "$zip"
      echo "📦 Zip déballé : $(basename "$zip")"
    fi
    rm -rf "$TMP"
  done < <(find "$Z" -maxdepth 1 -type f -name '*.zip' -mtime -2 2>/dev/null)
done

SRC=""
for Z in "${ZONES[@]}"; do
  [ -d "$Z" ] || continue
  while IFS= read -r f; do
    grep -q "$MARQUEUR" "$f" 2>/dev/null || continue
    if [ -z "$SRC" ] || [ "$f" -nt "$SRC" ]; then SRC="$f"; fi
  done < <(find "$Z" -maxdepth 1 -type f -name '*.html' 2>/dev/null)
done

if [ -z "$SRC" ]; then
  echo "❌ Aucun fichier de ce projet dans Téléchargements ni sur le Bureau."
  echo "   → Clique d'abord la carte du fichier dans la conversation, puis relance cette ligne."
  exit 1
fi

VER=$(sed -n '1,6p' "$SRC" | grep -oE 'v[0-9]+[.][0-9]+' | head -1)
if [ -z "$VER" ]; then
  echo "❌ Pas de marqueur de version dans $(basename "$SRC") — fichier non déployé."
  exit 1
fi
echo "📄 Trouvé : $(basename "$SRC")  →  $VER"

mkdir -p "$PROJ/_versions"
if [ -f "$PROJ/$CIBLE" ] && cmp -s "$SRC" "$PROJ/$CIBLE"; then
  echo "ℹ️  $VER déjà en place, aucune copie nécessaire."
else
  if [ -f "$PROJ/$CIBLE" ]; then
    OLD=$(sed -n '1,6p' "$PROJ/$CIBLE" | grep -oE 'v[0-9]+[.][0-9]+' | head -1)
    OLD=${OLD:-inconnue}
    cp "$PROJ/$CIBLE" "$PROJ/_versions/index_${OLD}_$(date +%Y%m%d-%H%M%S).html"
    echo "💾 Ancienne version sauvegardée ($OLD)"
  fi
  cp "$SRC" "$PROJ/$CIBLE"
  echo "✓ $CIBLE remplacé par $VER"
fi
mv -f "$SRC" "$PROJ/_versions/caisse_${VER}.html" 2>/dev/null || true

cd "$PROJ" || exit 1
if [ ! -d .git ]; then
  echo "⚙️  Premier déploiement — initialisation du dépôt"
  git init -q
  git branch -M main
  git remote add origin "$REPO_URL"
  git config user.email "contact@lumiia.fr"
  git config user.name "Emmanuel"
  git fetch -q origin && git reset --mixed -q origin/main
fi
printf '.DS_Store\n*.rtf\n_versions/\n' > .gitignore

git add -A
if git diff --cached --quiet; then
  echo "ℹ️  Rien de nouveau à envoyer sur GitHub."
else
  git commit -q -m "$VER"
  git pull --rebase -q >/dev/null 2>&1 || true
  if git push -q -u origin HEAD; then
    echo "🚀 $VER déployée"
  else
    echo "❌ Push refusé — le dépôt distant a divergé. Préviens Claude."
    exit 1
  fi
fi

echo "⏳ Vérification de la publication (jusqu'à 2 min)..."
OK=""
for i in $(seq 1 12); do
  sleep 10
  SERVI=$(curl -s -m 10 -H 'Cache-Control: no-cache' "${PAGE}?probe=$(date +%s)" 2>/dev/null | sed -n '1,6p' | grep -oE 'v[0-9]+[.][0-9]+' | head -1)
  if [ "$SERVI" = "$VER" ]; then OK="oui"; break; fi
  printf '.'
done
echo
if [ -n "$OK" ]; then
  echo "✅ $VER EN LIGNE : $PAGE"
else
  echo "⚠  Le push a réussi mais GitHub Pages sert encore ${SERVI:-une version illisible}."
  echo "   Le build a probablement échoué côté GitHub. Ce n'est PAS ton cache."
  echo "   1. Regarde https://github.com/I-immersion/Calcul-fond-de-caisse/actions"
  echo "   2. Relance par un commit à vide :"
  echo "      cd \"$PROJ\" && git commit --allow-empty -m \"relance build pages $VER\" && git push origin HEAD"
fi
