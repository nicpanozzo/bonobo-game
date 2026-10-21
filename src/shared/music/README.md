# Brani delle arene musicali (#423)

Come funziona tutta l'arena musicale, bottoni compresi: [docs/arena-musicale.md](../../../docs/arena-musicale.md).

I file `<id>.ts` qui dentro sono generati: le note di un MIDI in millisecondi, una lista per traccia.

## Un brano nuovo

1. Prepara un MIDI (va bene qualunque programma gratuito: MuseScore, LMMS, Online Sequencer...). Dai un nome a ogni traccia: è quello con cui l'arena la sceglie. Sala Prove usa `Basso`, `Accordi`, `Melodia` e `Batteria` (canale 10).
2. `npm run midi:import -- percorso/brano.mid <id> "Nome del brano"`: scrive `src/shared/music/<id>.ts` e suona il brano con un sintetizzatore semplice in `public/assets/music/<id>.ogg` (serve ffmpeg; senza, esce un `.wav`). Se hai già il brano registrato meglio, metti il tuo `.ogg` con lo stesso nome, ma deve durare quanto il MIDI.
3. In `stages.ts` copia il blocco `musica`, importa il brano e scegli cosa fa ogni traccia (`lift`, `slide`, `keys`).
4. `npm run export:godot`, `npm test` e una riga in `public/assets/CREDITS.md` per il brano.

Il giro delle piattaforme dura quanto il MIDI (fino alla fine dell'ultima traccia): fai finire il brano a fine battuta, così il loop torna dritto.
Il brano di prova si rifà con `npx tsx scripts/midi-demo.ts` e poi l'import su `public/assets/music/midi/sala-prove.mid`.
