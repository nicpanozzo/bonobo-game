# Architettura

Come è fatto Bonobo Game e perché, in una pagina. Le regole operative per gli agenti restano in [AGENTS.md](../AGENTS.md).

## Tre strati

```
src/shared/   IL GIOCO     regole, fisica, arene, personaggi, protocollo. TypeScript puro.
src/server/   LA RETE      stanze, Socket.IO, orologio a passo fisso.
godot/        LO SCHERMO   client Godot 4.5 (GDScript): disegno, menu, suoni. È il gioco ufficiale.
```

Le frecce vanno in una sola direzione: `server` usa `shared`, mai il contrario; Godot riceve i dati di `shared` come JSON (`npm run export:godot`) e parla col server solo con il protocollo di `types.ts`. `shared` non importa Socket.IO, Express o il DOM. Il vecchio client web in `src/client/` (Phaser) è congelato: solo correzioni.

| Strato | File principali | Cosa sa |
|---|---|---|
| Gioco | `match.ts` (una partita intera), `physics/` (un passo di simulazione), `rules.ts`, `stages.ts`, `stageGenerator.ts`, `characters.ts`, `items.ts`, `constants.ts`, `types.ts` | tutto quello che succede, niente di come si vede o di come viaggia |
| Rete | `server/index.ts` (stanze), `server/Room.ts` (passo fisso a 60 Hz, snapshot a 30 Hz, ganci per bot e Discord) | quando far avanzare la partita e a chi mandarla |
| Schermo | `godot/scripts/`: `main.gd` (regista), `world_view.gd`, `hud.gd`, `audio.gd`, `lobby.gd`, `options.gd`, `pause_menu.gd`, `snapshot_buffer.gd`, `socket_io.gd` | come mostrare lo stato e quali tasti sono premuti |

## Il giro di una partita

1. Il client manda solo `InputState` (quali tasti sono premuti), quando cambia.
2. Il server, a passo fisso, chiama `Match.step()`: fisica, colpi, KO, vittoria. Ne escono **eventi** (`hit`, `ko`, `jump`, `land`, `taunt`, `matchStart`, `matchEnd`...).
3. Ogni due passi manda uno `GameSnapshot`: lo stato di tutti più gli eventi dall'ultimo snapshot. La compressione del WebSocket lo riduce di molto.
4. Il client disegna il passato di 80 ms interpolando tra due snapshot (`snapshot_buffer.gd`), e reagisce agli eventi: suoni, effetti, classifica, telecamera.

Il client non decide mai niente: se un giorno serve la predizione dei propri movimenti, il client farà girare la stessa `physics/` e si correggerà con gli snapshot.

## Dati invece di codice

Personaggi, arene, regole, oggetti e tutti i numeri sono **oggetti semplici** (serializzabili in JSON) in `src/shared/`. Aggiungere un'arena o un personaggio è un blocco di dati, non codice nuovo. Le arene casuali sono un seme: `casuale-123` dà la stessa arena ovunque.

## Godot

Dal 6 ottobre 2026 il client ufficiale è Godot (#59). La strada scelta è stata **cambiare solo lo schermo**:

- Il server Node resta com'è ed è l'arbitro. Il client Godot parla lo stesso protocollo (`types.ts`: Socket.IO con JSON) con un piccolo client Socket.IO scritto a mano (`socket_io.gd`): legge `GameSnapshot`, interpola, suona sugli eventi, manda `InputState`.
- Arene, personaggi e numeri si esportano in JSON da `src/shared/` (`npm run export:godot`), così Godot li legge invece di riscriverli a mano. Arene casuali e percorsi della Corsa arrivano interi dal server nel `welcome`.
- Se servirà il gioco in locale dentro Godot (offline, predizione), si traducono `match.ts` e `physics/`: sono poche centinaia di righe senza dipendenze, con test che descrivono il comportamento atteso.

Per non chiudersi questa porta:

- niente logica di gioco nel client;
- numeri in `constants.ts`, contenuti in file di dati;
- il client sa cosa è successo solo dagli eventi, non tenendo il conto da solo;
- fisica deterministica: niente `Math.random` o orologi in `physics/` (il generatore di arene usa il suo seme).
