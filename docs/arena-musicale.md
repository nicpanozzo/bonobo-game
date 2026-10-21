# Arena musicale: come funziona (#423)

Un'arena in cui **la musica muove la mappa**. Le tracce di un brano MIDI diventano piattaforme che si muovono o compaiono con le note. I **bottoni sonori** sul pavimento, attivati dai lottatori, suonano e cambiano la mappa per qualche secondo. Il primo esempio è **Sala Prove** (`musica` in `src/shared/stages.ts`), con un brano nostro di 32 secondi in La minore.

Questa guida è per chi vuole capire come funziona, cambiare il brano o farne un'altra. Le regole generali delle arene sono in [arene.md](arene.md).

## In partita

- **Basso** (azzurro): due ascensori ai lati del palco che salgono e scendono con le note, uno al contrario dell'altro. Sono anche la via per tornare sul palco.
- **Accordi** (verde): una navetta in mezzo che scivola di lato quando cambia l'accordo.
- **Melodia** (arancio): otto tasti in alto, come un piano roll (più acuta la nota, più a destra e più in alto). Un tasto c'è solo mentre suona la sua nota, almeno 0,9 s. Mezzo secondo prima di comparire lampeggia. Quando sparisce, chi ci sta sopra cade.
- **Battimani** (rosa): una piattaforma in cima che compare ogni due battute.
- **Bottoni sonori** sul pavimento, tre: si premono **saltandoci sopra** (atterrando, non camminando) o **colpendoli** con un attacco. Non ci sono tasti nuovi.

| Bottone | Suono | Effetto | Durata | Attesa |
|---|---|---|---|---|
| a sinistra, arancio (nota) | accordo di La minore | accende tutti i tasti della melodia: una scala fino in cima | 4 s | 12 s |
| al centro, verde (riga) | piatto | alza la navetta sopra i tasti | 3,5 s | 9 s |
| a destra, azzurro (cerchio) | cassa | spara in alto i due ascensori | 4 s | 12 s |

Un bottone carico pulsa nel suo colore. Appena premuto si schiaccia, poi diventa grigio e una barra sotto si riempie fino a quando si può ripremere. L'attesa serve perché nessuno tenga la mappa sempre accesa e perché i bottoni restino un momento da sfruttare (o da negare all'avversario).

## Il percorso dei dati

```
brano.mid
  │  npm run midi:import -- brano.mid <id> "Nome"      (scripts/midi-import.ts, scripts/midi.ts)
  ├─► src/shared/music/<id>.ts      le note: [inizio ms, durata ms, nota] per traccia
  └─► public/assets/music/<id>.ogg  il brano suonato da un sintetizzatore semplice (ffmpeg)
        │
src/shared/stages.ts: songMovers(brano, ruoli)  (src/shared/musicStage.ts)
  └─► movers con keys / on / group, pads, song  →  npm run export:godot  →  godot/data/game.json
        │
SERVER (arbitro, src/shared/physics/)                     CLIENT GODOT (disegna e suona)
  elements.ts  moverPosition / moverOn / padFx  ═════════  stage_motion.gd  mover_position / mover_on / pad_fx
  pads.ts      chi preme un bottone, evento "pad"  ──────►  audio.gd suona pad_<suono>; world_view.gd scintille
  snapshot: stageMs (tempo dell'arena), pads  ───────────►  world_view.gd ricalcola e disegna le piattaforme
                                                           audio.gd sync_song: il brano segue stageMs
```

Le funzioni a sinistra e a destra della doppia riga **fanno lo stesso calcolo in due lingue** (TypeScript e GDScript): se se ne cambia una, si cambia anche l'altra. I test di tutte e due (`musicStage.test.ts`, `physics/pads.test.ts`, `godot/tests/test_music_stage.gd`) usano gli stessi casi.

### Perché così

- **Il server decide tutto** (regola del progetto): dove sono le piattaforme e chi preme un bottone si calcola in `src/shared/physics/`. Le piattaforme sono funzioni pure del tempo dell'arena, quindi in rete non viaggiano le loro posizioni ma solo `stageMs` e i tempi delle pressioni dei bottoni (`pads`). Godot ricalcola il resto.
- **Il MIDI si legge una volta, fuori dal gioco.** `midi:import` lo trasforma in dati TypeScript: il server non legge file musicali e il brano diventa parte del codice controllato dai test.
- **Il brano è un file audio vero**, non sintetizzato in Godot durante la partita: costa poco e un domani si può mettere al suo posto una registrazione migliore, purché duri quanto il MIDI.
- **Sincronia:** il brano e le piattaforme girano sullo stesso giro (`song.lengthMs` = `periodMs` di ogni piattaforma). Godot porta il brano al tempo dell'arena del frame che disegna, più la latenza dell'audio. Se si sposta di più di 80 ms (`SONG_DRIFT_S` in `audio.gd`) lo rimette a posto con un salto. Al rallentatore dell'allenamento il brano non insegue l'arena.

## I pezzi, uno per uno

### Le note (`Song`, `src/shared/musicStage.ts`)

`src/shared/music/<id>.ts` è generato: non si modifica a mano, si rilancia l'import. Contiene `bpm`, `lengthMs` (fino alla fine dell'ultima traccia del MIDI) e per ogni traccia il `name` del MIDI, `drums` (canale 10) e le `notes`.

### Dalle tracce alle piattaforme (`songMovers`)

Ogni ruolo prende una traccia per nome:

| Ruolo | Cosa fa | Campi |
|---|---|---|
| `lift` | ascensore in `x`: la nota più bassa della traccia sta a `yLow`, la più alta a `yHigh`; a ogni nota scivola in `MUSIC_STAGE.liftGlideMs` | `x`, `width`, `yLow`, `yHigh`, `invert` |
| `slide` | navetta a `y`: la nota più bassa a `xLow`, la più alta a `xHigh`; scivola in `slideGlideMs` | `y`, `width`, `xLow`, `xHigh` |
| `keys` | tasti fissi negli `slots`: ogni altezza diversa ha il suo (dalla più bassa), e c'è solo mentre suona (almeno `keyMinOnMs`) | `slots`, `width`, `pitches` (solo quelle note, es. `[39]` il battimani) |

Tutti hanno `tint` (il colore) e `group` (il nome che usano i bottoni). Le note che partono insieme (un accordo) contano come la più bassa.

### La piattaforma mobile, con i campi nuovi (`MovingPlatform` in `stages.ts`)

- `keys: [ms, x, y][]`: posizioni a tempo nel giro; tra due chiavi va dritta, dopo l'ultima torna verso la prima del giro dopo.
- `on: [da, a][]`: finestre del giro in cui c'è. Fuori non la si può prendere e chi ci sta sopra cade.
- `group`: i bottoni con lo stesso gruppo la cambiano.
- `kind: "nota"` e `tint`: solo disegno.

### I bottoni (`SoundPad` in `stages.ts`, logica in `physics/pads.ts`)

```ts
{ x: 262, y: MAIN.y, width: 56, sound: "accordo", cooldownMs: 12000,
  effect: { group: "melodia", durationMs: 4000, on: true } }
```

- **Si preme** quando un lottatore ci **atterra** sopra (evento `land` di quel tick con i piedi sul bottone) o quando un **colpo attivo** tocca la zona sopra di lui (`PAD.hitPx`, basta un colpo da in piedi accanto). Le prese no. Camminarci sopra o restarci fermi non conta.
- Se è carico: si segna il tempo in `ctx.padsMs`, parte l'evento `{ type: "pad", index, sound, id, x, y }` e il bottone resta scarico per `cooldownMs`.
- **Effetto** (`padFx` in `elements.ts`) per `durationMs` sulle piattaforme del suo `group`: `on: true` le accende tutte; `dy` le sposta in verticale (negativo = su), entrando e uscendo in `PAD.rampMs`. Chi ci sta sopra viene portato. Più bottoni sullo stesso gruppo si sommano.
- **Suoni** in `audio.gd` (`_sounds.pad_accordo`, `pad_cassa`, `pad_piatto`, sintetizzati in La minore). Un suono nuovo = una ricetta `pad_<nome>` lì e un colore in `PAD_COLORS` di `world_view.gd`; senza, suona l'accordo.

### I numeri

In `src/shared/constants.ts`: `MUSIC_STAGE` (scivolate, durata minima dei tasti) e `PAD` (altezza, zona del colpo, entrata dell'effetto). Durate ed attese dei singoli bottoni stanno nei dati dell'arena.

## Ricette

**Cambiare brano.** Prepara un MIDI con un programma gratuito (MuseScore, LMMS, Online Sequencer) e dai alle tracce gli stessi nomi (`Basso`, `Accordi`, `Melodia`, `Batteria` con il battimani sulla nota 39). Fallo finire a fine battuta, così il giro torna dritto. Poi:

```bash
npm run midi:import -- percorso/brano.mid sala-prove "Sala Prove"   # sovrascrive il brano di prova
npm run export:godot && npm test
```

Se le note escono dallo schermo, `npm test` lo dice (test "Sala Prove" in `musicStage.test.ts`). Registra il brano in `public/assets/CREDITS.md`.

**Un'altra arena musicale.** Importa il brano con un `<id>` nuovo, copia il blocco `musica` in `stages.ts` con un altro `id`, importa la costante del brano e scegli i ruoli delle sue tracce. I nomi delle tracce in `stages.ts` devono essere quelli del MIDI (`songMovers` si ferma con un errore se ne manca una).

**Un bottone nuovo.** Un blocco in `pads` con un `group` che qualche ruolo usa. Tienilo su una superficie (`y` = superficie) e lontano dai punti di partenza e dal punto di rientro (`respawn`), sennò lo preme chi ricompare. Il test di Sala Prove controlla che il gruppo esista e che l'attesa sia più lunga dell'effetto.

**Un effetto nuovo** (per esempio "inverte la navetta"): va in `padFx` di `elements.ts` e in `pad_fx` di `stage_motion.gd`, con un test in tutti e due. Se cambia cosa viaggia in rete, la PR ha `Protocollo:` nel titolo.

**Il brano di prova** si rifà con `npx tsx scripts/midi-demo.ts` e poi l'import di `public/assets/music/midi/sala-prove.mid`.

## Limiti di adesso

- Il sintetizzatore dell'import è semplice (basso, lead a onda quadra, pad, batteria): per un brano bello conviene un OGG registrato al posto di quello generato, della stessa durata.
- Le piattaforme seguono le note, non il volume o il timbro.
- I bottoni non sono messi a tempo: suonano quando li si preme, non sul battito.
- L'editor delle arene sul sito non conosce `keys`, `on` e `pads`: mostra le piattaforme ferme.
