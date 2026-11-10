#!/usr/bin/env bash
# I controlli di .github/workflows/ci.yml (job check e godot) sul Mac, quando GitHub Actions è fermo.
# Lavora su una copia pulita del commit: la cartella di lavoro non si tocca.
#
#   scripts/locale/ci.sh 591          la PR #591 (l'ultimo commit del suo branch)
#   scripts/locale/ci.sh origin/main  un branch o un commit
#
# Esce con 0 solo se passa tutto. Gli screenshot finiscono in ~/Library/Caches/bonobo-locale/ci-<sha>/screenshot
set -uo pipefail

[ $# -eq 1 ] || { echo "Uso: scripts/locale/ci.sh <numero PR | ref>" >&2; exit 2; }
REPO=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
source "$REPO/scripts/locale/comune.sh"

if [[ "$1" =~ ^[0-9]+$ ]]; then
  git -C "$REPO" fetch -q origin "pull/$1/head" || exit 1
  SHA=$(git -C "$REPO" rev-parse FETCH_HEAD)
  # Come la CI: la PR unita a main, così si vede anche se va in conflitto con quello che è entrato dopo
  git -C "$REPO" fetch -q origin main
  BASE=$(git -C "$REPO" rev-parse origin/main)
  MERGE=$(git -C "$REPO" merge-tree --write-tree "$BASE" "$SHA") || { echo "La PR #$1 va in conflitto con main"; exit 1; }
  TREE=$(echo "$MERGE" | head -1)
  REF=$(git -C "$REPO" commit-tree "$TREE" -p "$BASE" -p "$SHA" -m "prova locale PR #$1")
  echo "PR #$1: $(git -C "$REPO" log -1 --format='%h %s' "$SHA") (unita a main ${BASE:0:7})"
else
  git -C "$REPO" fetch -q origin
  REF=$(git -C "$REPO" rev-parse "$1^{commit}") || exit 1
  SHA=$REF
  git -C "$REPO" log -1 --oneline "$REF"
fi

DIR="$CACHE/ci-${SHA:0:7}"
copia_commit "$REF" "$DIR"
cd "$DIR"
GODOT=$(godot_bin)
NODE_DIR=$(dirname "$(node22_bin "$( [ "$(uname -m)" = arm64 ] && echo darwin-arm64 || echo darwin-x64)")")
export PATH="$NODE_DIR:$PATH" # node 22 come la CI; npm resta quello di sistema
FALLITI=()
prova() { local nome="$1"; shift; passo "$nome"; if "$@"; then echo "OK: $nome"; else echo "FALLITO: $nome"; FALLITI+=("$nome"); fi; }

passo "npm ci (node $(node -v))"
npm ci --silent --no-audit --no-fund || exit 1

prova "typecheck" npm run typecheck
prova "test" npm test
cp -R godot/data "$CACHE/data-prima"
prova "godot/data allineato" bash -c 'npm run export:godot >/dev/null && diff -r "$0" godot/data' "$CACHE/data-prima"
rm -rf "$CACHE/data-prima"
prova "prestazioni del server" npm run bench -- --check

LOG="$DIR/log"; mkdir -p "$LOG"
carica() {
  "$GODOT" --headless --path godot --import > "$LOG/import.log" 2>&1
  "$GODOT" --headless --path godot --quit-after 60 > "$LOG/run.log" 2>&1
  ! grep -E "SCRIPT ERROR|Parse Error|Failed to load script" "$LOG/import.log" "$LOG/run.log"
}
test_client() {
  "$GODOT" --headless --path godot --script res://tests/run_tests.gd > "$LOG/test.log" 2>&1
  local rc=$?; tail -5 "$LOG/test.log"
  [ $rc -eq 0 ] && ! grep -E "SCRIPT ERROR|Parse Error" "$LOG/test.log"
}
prova "Godot: carica il progetto e gli script" carica
prova "Godot: test del client" test_client
prova "Godot: prestazioni del client" "$GODOT" --headless --path godot --script res://tools/bench_client.gd -- --check
# Lo screenshot vuole una finestra vera: sul Mac se ne apre una per qualche secondo
prova "Godot: screenshot" "$GODOT" --path godot --script res://tools/screenshot.gd -- --out="$DIR/screenshot"

passo "Risultato"
echo "Log in $LOG, screenshot in $DIR/screenshot"
if [ ${#FALLITI[@]} -eq 0 ]; then echo "Tutto verde (${SHA:0:7})"; exit 0; fi
printf 'Rosso: %s\n' "${FALLITI[@]}"; exit 1
