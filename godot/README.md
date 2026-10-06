# Client Godot (prototipo)

Un secondo modo di disegnare Bonobo Game, fatto con [Godot 4.5](https://godotengine.org). Il gioco vero resta sul **server Node** (`src/server/`, `src/shared/`): questo client fa solo quello che fa `src/client/`, cioè manda i tasti premuti e disegna gli snapshot che riceve. Si può giocare insieme: chi usa il client web e chi usa quello Godot stanno nella stessa stanza.

Serve a capire se passare a Godot conviene. La decisione la prende il canale, vedi #59.

## Provarlo

1. Avvia il server: `npm run dev` dalla radice della repo.
2. Apri Godot 4.5, **Importa** e scegli `godot/project.godot`.
3. Premi Play (F5): scegli nome, stanza e arena e premi **Entra**. Nella stessa stanza puoi entrare anche dal browser (`http://localhost:5173/?room=amici`).

Da riga di comando si entra subito: `godot --path godot -- --server=http://localhost:3000 --room=amici --name=Nico`.

Nella versione web gli stessi valori vanno nell'indirizzo: `index.html?server=https://il-server&room=amici&name=Nico`.

## Esportarlo

- **Web:** Progetto → Esporta → Web. Il preset è già pronto (senza thread, così funziona su qualsiasi hosting, anche GitHub Pages). Serve il pacchetto "Export templates" di Godot 4.5.1.
- **Linux:** preset "Linux". Windows e Mac si aggiungono se il canale sceglie l'app da scaricare.

Da riga di comando: `godot --headless --path godot --export-release Web build/web/index.html`.

## Com'è fatto

```
project.godot          impostazioni (1280x720 come WORLD, renderer Compatibility per il web)
main.tscn              la scena unica
scripts/main.gd        collegamento, lobby, tasti → InputState, eventi → disegno
scripts/socket_io.gd   client Socket.IO minimo (Engine.IO v4 su WebSocket), niente plugin
scripts/snapshot_buffer.gd   interpolazione, la stessa di src/client/interpolation.ts
scripts/world_view.gd  arena, lottatori, colpi, scintille e scossa sui KO
scripts/hud.gd         percentuali, vite, tempo, vincitore
scripts/lobby.gd       nome, stanza, arena, server
data/game.json         arene, personaggi e numeri, GENERATO da npm run export:godot
```

Non modificare `data/game.json` a mano: cambia `src/shared/stages.ts`, `characters.ts` o `constants.ts` e rilancia `npm run export:godot`.

## Cosa manca

- Arene casuali (`casuale-<seme>`): si generano sul server, qui si vede l'arena base. Servirà che il server mandi l'arena nel messaggio `welcome` (PR `Protocollo:`).
- Sprite dei personaggi, suoni, musica, menu di pausa, tasti personalizzabili, squadre nell'HUD.
