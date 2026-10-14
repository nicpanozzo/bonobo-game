# Regole per `src/shared/` e `src/server/` (logica e arbitro)

Valgono insieme a [AGENTS.md](../../AGENTS.md) della radice. Mappa dei moduli: [docs/architettura.md](../../docs/architettura.md).

- **`physics/` è puro e deterministico:** niente import da `socket.io`, `express` o dal DOM, niente `Math.random` né orologi (`determinism.test.ts` lo controlla). Un giorno girerà anche nel client per la predizione.
- **Numeri in `constants.ts`**, con nome e unità nel commento (pixel/s, ms). Niente valori magici sparsi.
- **`types.ts` è il protocollo:** si cambia solo in una PR `Protocollo: ...` che aggiorna anche il client Godot. Un nuovo tipo di `GameEvent` è un cambio di protocollo.
- **Eventi Socket.IO tipizzati** con i tipi di `types.ts` (`Server<ClientToServer, ServerToClient>`), mai stringhe libere.
- **Test accanto al file** (`nome.test.ts`, runner di Node) per ogni logica nuova o cambiata.
- **Dopo ogni modifica a `src/shared/`** (o a `public/assets/`) rilancia `npm run export:godot` e committa `godot/data`: la CI fallisce se non è allineato.
- **Il server** (`src/server/`) gestisce stanze (`index.ts`, `game.ts`) e fa girare la partita (`Room.ts`, ganci per bot e Discord); non calcola fisica fuori da `src/shared/`.
