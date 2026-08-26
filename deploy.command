#!/bin/bash
cd "$(dirname "$0")" || exit 1
git add -A
git commit -m "maj $(date '+%Y-%m-%d %H:%M')" || echo "(rien de nouveau à envoyer)"
git pull --rebase
git push -u origin HEAD && echo "✓ Déployé"
read -n 1 -s -r -p "Appuie sur une touche pour fermer"
