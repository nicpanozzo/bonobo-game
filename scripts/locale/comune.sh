# Pezzi comuni a rilascio.sh e ci.sh: scaricano una volta Godot e node nella cache del Mac.
# Servono finché GitHub Actions è fermo: fanno sul Mac di Nicola quello che fanno app.yml e ci.yml.

GODOT_VERSION=4.5.1
CACHE="${BONOBO_CACHE:-$HOME/Library/Caches/bonobo-locale}"
GODOT_BASE="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"
mkdir -p "$CACHE"

passo() { printf '\n\033[1m== %s\033[0m\n' "$*"; }

# L'editor Godot per Mac (universale), lo stesso numero di versione della CI
godot_bin() {
  local app="$CACHE/godot-$GODOT_VERSION/Godot.app"
  if [ ! -x "$app/Contents/MacOS/Godot" ]; then
    passo "Scarico Godot $GODOT_VERSION (una volta sola)" >&2
    mkdir -p "$CACHE/godot-$GODOT_VERSION"
    curl -fsSL -o "$CACHE/godot.zip" "$GODOT_BASE/Godot_v${GODOT_VERSION}-stable_macos.universal.zip"
    unzip -oq "$CACHE/godot.zip" -d "$CACHE/godot-$GODOT_VERSION"
    rm "$CACHE/godot.zip"
    xattr -cr "$app" 2>/dev/null || true
  fi
  echo "$app/Contents/MacOS/Godot"
}

# I modelli di esportazione per desktop, dove Godot li cerca sul Mac. Dal pacchetto da ~1 GB si tengono 4 file
godot_templates() {
  local t="$HOME/Library/Application Support/Godot/export_templates/${GODOT_VERSION}.stable"
  if [ ! -f "$t/macos.zip" ] || [ ! -f "$t/windows_release_x86_64.exe" ] || [ ! -f "$t/linux_release.x86_64" ]; then
    passo "Scarico i modelli di esportazione di Godot $GODOT_VERSION (una volta sola, ~1 GB)"
    mkdir -p "$t"
    curl -fSL --progress-bar -o "$CACHE/templates.tpz" "$GODOT_BASE/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
    unzip -joq "$CACHE/templates.tpz" 'templates/version.txt' 'templates/windows_release_x86_64.exe' \
      'templates/linux_release.x86_64' 'templates/macos.zip' -d "$t"
    rm "$CACHE/templates.tpz"
  fi
}

# L'ultima node 22 (quella della CI): il blob del server va fatto con la stessa versione del node che ci finisce dentro
NODE22_VERSION=""
node22_version() {
  [ -n "$NODE22_VERSION" ] || NODE22_VERSION=$(curl -fsSL https://nodejs.org/dist/index.json |
    node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>console.log(JSON.parse(s).find(r=>r.version.startsWith("v22.")).version))')
  echo "$NODE22_VERSION"
}

# node22_bin <darwin-arm64|darwin-x64|linux-x64|win-x64>: percorso del binario node scaricato
node22_bin() {
  local plat="$1" v; v=$(node22_version)
  local dir="$CACHE/node-$v/$plat"
  local out="$dir/node"; [ "$plat" = win-x64 ] && out="$dir/node.exe"
  if [ ! -f "$out" ]; then
    mkdir -p "$dir"
    if [ "$plat" = win-x64 ]; then
      curl -fsSL -o "$out" "https://nodejs.org/dist/$v/win-x64/node.exe"
    else
      curl -fsSL "https://nodejs.org/dist/$v/node-$v-$plat.tar.gz" | tar -xz -C "$dir" --strip-components=2 "node-$v-$plat/bin/node"
    fi
  fi
  echo "$out"
}

# Una copia pulita di un commit, senza toccare la cartella di lavoro: ci si costruisce sopra
copia_commit() {
  local sha="$1" dest="$2"
  rm -rf "$dest"; mkdir -p "$dest"
  git -C "$REPO" archive "$sha" | tar -x -C "$dest"
}
