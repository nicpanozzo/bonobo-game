#!/usr/bin/env bash
# Pubblica la Release dell'app dal Mac, come fa .github/workflows/app.yml, quando GitHub Actions è fermo.
# Costruisce da una copia pulita di origin/main (la cartella di lavoro non si tocca):
# il gioco per Windows, Mac e Linux, il pacchetto .pck con la versione per l'app che si aggiorna da sola
# e il server con un doppio clic per i 4 sistemi. Poi crea la Release app-<N> con N = l'ultima + 1.
#
#   scripts/locale/rilascio.sh           costruisce e pubblica
#   scripts/locale/rilascio.sh --prova   costruisce soltanto: i file restano in ~/Library/Caches/bonobo-locale/out
#
# Serve: Mac, node e npm, gh con l'accesso alla repo. Godot 4.5.1, i suoi modelli e node 22 li scarica da solo.
set -euo pipefail

PROVA=false
REF=origin/main
while [ $# -gt 0 ]; do
  case "$1" in
    --prova) PROVA=true ;;
    --ref) REF="$2"; shift ;;
    *) echo "Opzione sconosciuta: $1" >&2; exit 2 ;;
  esac
  shift
done

REPO=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
source "$REPO/scripts/locale/comune.sh"
GH_REPO=nicpanozzo/bonobo-game

passo "Commit da pubblicare"
git -C "$REPO" fetch -q origin main
SHA=$(git -C "$REPO" rev-parse "$REF^{commit}")
git -C "$REPO" log -1 --oneline "$SHA"

# La versione è un numero che cresce: l'app si aggiorna se quella della Release è più alta della sua
ULTIMA=$(gh release list --repo "$GH_REPO" --limit 50 --json tagName -q '.[].tagName' | sed -n 's/^app-\([0-9]*\)$/\1/p' | sort -n | tail -1)
N=$(( ${ULTIMA:-0} + 1 ))
TAG="app-$N"
echo "Ultima Release: app-$ULTIMA  ->  nuova: $TAG"

GODOT=$(godot_bin)
godot_templates
NODE_HOST=$(node22_bin darwin-arm64)
[ "$(uname -m)" = arm64 ] || NODE_HOST=$(node22_bin darwin-x64)

B="$CACHE/build"
OUT="$CACHE/out"
copia_commit "$SHA" "$B"
rm -rf "$OUT"; mkdir -p "$OUT"
cd "$B"

passo "Versione $N nel gioco"
printf '{"version": %s, "godot": "%s", "commit": "%s"}\n' "$N" "$GODOT_VERSION" "${SHA:0:7}" > godot/data/build.json
cat godot/data/build.json
V=$(node -p "require('./package.json').version")
sed -i '' "s/^application\/short_version=.*/application\/short_version=\"$V\"/; s/^application\/version=.*/application\/version=\"$N\"/" godot/export_presets.cfg

passo "Esporto il gioco per Windows, Mac e Linux"
mkdir -p godot/build/windows godot/build/macos godot/build/linux
"$GODOT" --headless --path godot --import > "$CACHE/import.log" 2>&1 || true
"$GODOT" --headless --path godot --export-release Windows build/windows/bonobo-game.exe
"$GODOT" --headless --path godot --export-release macOS build/macos/bonobo-game.zip
"$GODOT" --headless --path godot --export-release Linux build/linux/bonobo-game.x86_64
(cd godot/build/windows && zip -q "$OUT/bonobo-game-windows.zip" bonobo-game.exe)
cp godot/build/macos/bonobo-game.zip "$OUT/bonobo-game-mac.zip"
(cd godot/build/linux && chmod +x bonobo-game.x86_64 && zip -q "$OUT/bonobo-game-linux.zip" bonobo-game.x86_64)

passo "Pacchetto del gioco per l'aggiornamento automatico"
"$GODOT" --headless --path godot --export-pack Linux build/bonobo-game.pck
cp godot/build/bonobo-game.pck "$OUT/"
SIZE=$(stat -f %z "$OUT/bonobo-game.pck")
printf '{"version": %s, "godot": "%s", "size": %s}\n' "$N" "$GODOT_VERSION" "$SIZE" > "$OUT/bonobo-game-version.json"
cat "$OUT/bonobo-game-version.json"

passo "Server per i 4 sistemi (node $(node22_version))"
# npm con il node 22 scaricato: un node di sistema x64 (Rosetta) installerebbe esbuild per l'altro processore
PATH="$(dirname "$NODE_HOST"):$PATH" npm ci --silent --no-audit --no-fund
CF=https://github.com/cloudflare/cloudflared/releases/latest/download
for spec in linux:linux-x64:cloudflared-linux-amd64 windows:win-x64:cloudflared-windows-amd64.exe \
            mac:darwin-arm64:cloudflared-darwin-arm64.tgz mac-intel:darwin-x64:cloudflared-darwin-amd64.tgz; do
  IFS=: read -r name plat cf <<< "$spec"
  P="$B/pacco-$name"; rm -rf "$P"; mkdir -p "$P"
  case "$cf" in
    *.exe) curl -fsSL -o "$P/cloudflared.exe" "$CF/$cf" ;;
    *.tgz) curl -fsSL "$CF/$cf" | tar -xz -C "$P" cloudflared ;;
    *) curl -fsSL -o "$P/cloudflared" "$CF/$cf" ;;
  esac
  [ -f "$P/cloudflared" ] && chmod +x "$P/cloudflared"
  case "$name" in
    windows) T=win; EXE="$P/bonobo-server.exe" ;;
    mac*) T=mac; EXE="$P/bonobo-server" ;;
    *) T=linux; EXE="$P/bonobo-server" ;;
  esac
  "$NODE_HOST" scripts/build-server.mjs --target "$T" --node "$(node22_bin "$plat")" --out "$EXE"
  cat > "$P/LEGGIMI.txt" <<'EOF'
Server di Bonobo Game: ospita una serata con un doppio clic.

1. Apri bonobo-server (su Windows bonobo-server.exe). Lascia cloudflared accanto, serve per il tunnel.
2. Dopo qualche secondo il link della serata è copiato: incollalo sul Discord.
3. Si apre il gioco nel browser: entra anche tu. Chi ha l'app incolla il link nel campo Server.
4. Lascia aperta la finestra finché giocate: chiuderla spegne la serata.

Istruzioni con le immagini: https://nicpanozzo.github.io/bonobo-game/#ospita
EOF
  (cd "$P" && zip -qry "$OUT/bonobo-server-$name.zip" .)
done

passo "Provo che il server per questo Mac parte"
SRV="$B/pacco-mac"; [ "$(uname -m)" = arm64 ] || SRV="$B/pacco-mac-intel"
if curl -sf http://localhost:3000/health >/dev/null 2>&1; then
  echo "La porta 3000 è già occupata: salto la prova"
else
  # --app-info come fa l'app: così non copia il link negli appunti e non apre il browser
  (cd "$SRV" && exec ./bonobo-server --app-info="$CACHE/server-info.json" > "$CACHE/server.log" 2>&1) &
  PID=$!
  OK=false
  for _ in $(seq 1 20); do curl -sf http://localhost:3000/health && OK=true && break; sleep 1; done
  kill "$PID" 2>/dev/null || true
  pkill -f "$SRV/cloudflared" 2>/dev/null || true
  $OK || { echo; echo "Il server non risponde su /health:"; cat "$CACHE/server.log"; exit 1; }
  echo
fi

ls -la "$OUT"
if $PROVA; then
  passo "Solo prova: niente pubblicato. I file sono in $OUT"
  exit 0
fi

passo "Pubblico $TAG"
cat > "$CACHE/note.md" <<'EOF'
Il gioco da scaricare. Apri l'app, scrivi il nome, incolla nel campo **Server** il link della serata che gira sul Discord e premi **Gioca**.

- **Windows:** scompatta lo zip e apri `bonobo-game.exe`. Se Windows dice "PC protetto", clicca "Ulteriori informazioni" e poi "Esegui comunque".
- **Mac:** il modo senza blocchi è incollare nel Terminale `curl -fsSL https://nicpanozzo.github.io/bonobo-game/mac.sh | bash`: scarica l'app, la mette in Applicazioni e la apre. Lo zip scaricato dal browser invece il Mac lo blocca ("Apple could not verify..."), perché il gioco non è notarizzato da Apple: in quel caso nel Terminale `xattr -cr "/Applications/Bonobo Game.app"`, oppure provala ad aprire una volta e poi Impostazioni di Sistema → Privacy e sicurezza → "Apri comunque".
- **Linux:** scompatta lo zip e apri `bonobo-game.x86_64`.

Senza installare niente si gioca anche dal browser: https://nicpanozzo.github.io/bonobo-game/godot/

**Per ospitare una serata** scarica `bonobo-server` per il tuo sistema (`mac` per i Mac con chip Apple, `mac-intel` per quelli più vecchi), scompatta e apri `bonobo-server`: dopo qualche secondo il link della serata è già copiato, incollalo sul Discord. Lascia aperta la finestra finché giocate.

Tutto spiegato passo per passo: https://nicpanozzo.github.io/bonobo-game/#gioca

_Pubblicata dal Mac con `scripts/locale/rilascio.sh` mentre GitHub Actions è fermo._
EOF
gh release create "$TAG" "$OUT"/*.zip "$OUT/bonobo-game.pck" "$OUT/bonobo-game-version.json" --repo "$GH_REPO" \
  --target "$SHA" --title "Bonobo Game ($TAG)" --notes-file "$CACHE/note.md" --generate-notes --latest

passo "Controllo il link latest"
curl -fsSL "https://github.com/$GH_REPO/releases/latest/download/bonobo-game-version.json"
