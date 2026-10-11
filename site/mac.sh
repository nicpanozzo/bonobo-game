#!/bin/bash
# Installa (o reinstalla) Bonobo Game su Mac senza il blocco "Apple could not verify..." (#219).
# Uso, nel Terminale: curl -fsSL https://nicpanozzo.github.io/bonobo-game/mac.sh | bash
# Il blocco scatta solo sui file scaricati dal browser, che li segna come "da internet".
# Scaricata con curl l'app non ha quel segno: la notarizzazione Apple costa 99$ l'anno e non la facciamo.
set -euo pipefail

URL="https://github.com/nicpanozzo/bonobo-game/releases/latest/download/bonobo-game-mac.zip"
APP="Bonobo Game.app"
DEST="/Applications"
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "Scarico l'ultima versione di Bonobo Game..."
curl -fL --progress-bar -o "$TMP/bonobo-game-mac.zip" "$URL"
ditto -xk "$TMP/bonobo-game-mac.zip" "$TMP"

# Se era già installata (magari scaricata dal browser e bloccata) si sostituisce
rm -rf "$DEST/$APP"
mv "$TMP/$APP" "$DEST/"
xattr -cr "$DEST/$APP" 2>/dev/null || true

echo "Fatto: Bonobo Game è in $DEST. La apro."
open "$DEST/$APP"
