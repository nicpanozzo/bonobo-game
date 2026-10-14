# Regole per `godot/` (il client ufficiale)

Valgono insieme a [AGENTS.md](../AGENTS.md) della radice. La mappa degli script è in [README.md](README.md), sezione "Com'è fatto".

- **Il client disegna e suona, non decide.** Manda `InputState` e disegna gli snapshot; effetti, suoni e telecamera partono dai `GameEvent`. Una regola di gioco nuova va in `src/shared/physics/`, non qui.
- **`data/` è generato** da `npm run export:godot` (arene, personaggi, numeri, sprite): non si modifica né si legge a mano. Cambia `src/shared/` o `public/assets/` e rigeneralo; la CI controlla che sia allineato.
- **File lunghi** (`world_view.gd`, `lobby.gd`, `stage_life.gd`, `main.gd`): cerca la funzione con `grep -n "func "` e leggi solo quel pezzo. Sono file caldi: aggiungi righe, non riordinare.
- **GDScript:** tab, nomi in inglese in `snake_case`, tipi espliciti. Con `:=` su un valore letto da un `Dictionary` Godot dà "Cannot infer the type": scrivi il tipo (`var x: float = d.x`).
- **UI:** un `Control` già nella scena si allarga a tutto lo schermo con `set_anchors_and_offsets_preset(...)`; `set_anchors_preset` da solo lo lascia grande zero.
- **Test:** chi tocca il client aggiunge o aggiorna un `tests/test_*.gd` (runner nostro, niente addon, niente `class_name` nei test).
- **Provare:** con `npm run dev` acceso, F5 in due istanze (menu Debug, più istanze) oppure `godot --path godot -- --room=test --name=A` due volte. Script, test, prestazioni e screenshot li controlla la CI: se non hai già Godot (4.5.1), non scaricarlo.

```bash
godot --headless --path godot --import            # carica il progetto
godot --headless --path godot --quit-after 60     # nessun "SCRIPT ERROR" = gli script si caricano
npm run test:godot                                # test del client
```
