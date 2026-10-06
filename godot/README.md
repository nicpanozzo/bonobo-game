# Client Godot

**Il gioco ufficiale di Bonobo Game**, fatto con [Godot 4.5](https://godotengine.org) (dal 6 ottobre 2026, decisione di Nicola, vedi #59). Le regole restano sul **server Node** (`src/server/`, `src/shared/`): questo client manda i tasti premuti e disegna e suona gli snapshot che riceve. Ogni funzione nuova che si vede o si sente va qui; il vecchio client web in `src/client/` è congelato.

## Provarlo

1. Avvia il server: `npm run dev` dalla radice della repo.
2. Apri Godot 4.5, **Importa** e scegli `godot/project.godot`.
3. Premi Play (F5): scegli nome, stanza, lottatore, arena e regole e premi **Gioca**. Per un secondo giocatore avvia un'altra istanza (menu Debug, più istanze).

Da riga di comando si entra subito: `godot --path godot -- --server=http://localhost:3000 --room=amici --name=Nico`.

Nella versione web gli stessi valori vanno nell'indirizzo: `index.html?server=https://il-server&room=amici&name=Nico`.

## Esportarlo

- **Web:** Progetto → Esporta → Web. Il preset è già pronto (senza thread, così funziona su qualsiasi hosting, anche GitHub Pages). Serve il pacchetto "Export templates" di Godot 4.5.1.
- **Linux:** preset "Linux". Windows e Mac si aggiungono quando serve l'app da scaricare.

La versione web si pubblica da sola su GitHub Pages a ogni merge su `main` (`.github/workflows/pages.yml`): https://nicpanozzo.github.io/bonobo-game/godot/

Da riga di comando: `godot --headless --path godot --export-release Web build/web/index.html`.

## Com'è fatto

```
project.godot          impostazioni (1280x720 come WORLD, renderer Compatibility per il web)
main.tscn              la scena unica
scripts/main.gd        collegamento, tasti → InputState, telecamera, apre lobby e menu
scripts/socket_io.gd   client Socket.IO minimo (Engine.IO v4 su WebSocket), niente plugin
scripts/snapshot_buffer.gd   interpolazione (80 ms nel passato)
scripts/world_view.gd  arena, lottatori e sprite animati, scintille e scossa sui KO
scripts/hud.gd         schede con percentuale e vite, tempo, punti, vincitore e classifica
scripts/lobby.gd       nome, stanza, lottatore, arena (stage_preview.gd), regole, server
scripts/audio.gd       quale suono per quale evento, musica; synth.gd li calcola, niente file audio
scripts/options.gd     volumi e tasti; settings.gd li salva in user://bonobo.cfg
scripts/pause_menu.gd  menu con Esc; ui.gd colori e tema dei menu
data/game.json         arene, personaggi e numeri, GENERATO da npm run export:godot
data/assets/           sprite copiati da public/assets, GENERATI anche loro
```

Non modificare `data/` a mano: cambia `src/shared/stages.ts`, `characters.ts`, `constants.ts` o `public/assets/` e rilancia `npm run export:godot`. La CI controlla che sia allineato e che gli script si carichino.

Arene casuali e percorsi della Corsa arrivano interi dal server nel messaggio `welcome` (campo `stage`), perché Godot non ha il codice che li genera dal seme.
