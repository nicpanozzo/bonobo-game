# CLAUDE.md

Le regole del progetto per tutti gli agenti sono in AGENTS.md, importato qui sotto. Non duplicarle in questo file.

@AGENTS.md

## Solo per Claude Code

- Le regole di `godot/` e `src/shared/` (anche per `src/server/`) arrivano da sole dai `CLAUDE.md` di quelle cartelle quando ci lavori: non serve leggerle prima.
- `.claude/settings.json` blocca la lettura dei file generati e archiviati: non aggirarlo con `cat`.
- Usa `gh` per issue e PR se c'è, altrimenti gli strumenti GitHub che hai.
- Preferenze personali (modello, permessi, note tue) vanno in `CLAUDE.local.md` o in `~/.claude/CLAUDE.md`, che non si committano.
