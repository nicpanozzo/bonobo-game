# Bonobot

Personaggio di test per mosse e abilità, manichino da allenamento (#20) e personaggio giocabile, proposto da Riccardo (GiovannifRana). Statistiche di riferimento: tutto a 1.0 (#13). Suprema: Omar (#102, disegni in `omar/`).

## Sprite: formato a cartella (E7)

Un PNG per stato in questa cartella, con i fotogrammi in fila da sinistra. È il formato spiegato in [../README.md](../README.md).

- Fotogrammi da **336×368 px**, disegnati a 2x: nel gioco si mostrano a metà (`scale: 0.5`).
- **Piedi a 286 px dall'alto** (`footY`), al centro del fotogramma. Sotto restano 82 px per il corpo di chi è appeso al bordo, che sta sotto lo spigolo.
- Guarda **a destra**: per andare a sinistra il gioco specchia il fotogramma.
- `portrait.png` è il ritratto per la lobby e l'HUD: testa e spalle del fermo.

| Stato | Fotogrammi | fps | Ciclo | Cosa fa |
|---|---|---|---|---|
| `idle` | 24 | 12 | sì | respiro, peso che passa da un piede all'altro, battito di ciglia, ciuffi e fumo |
| `walk` | 8 | 24 | sì | galoppo sulle nocche: mani e piedi a terra scorrono alla velocità di `groundSpeed` |
| `jump` | 7 | 24 | no | slancio con le braccia, poi si raccoglie |
| `fall` | 12 | 24 | sì | braccia larghe, gambe pronte all'atterraggio |
| `light` | 10 | 24 | no | schiaffo di rovescio a frusta; colpisce dal fotogramma 2 (`hitFrame`) |
| `heavy` | 18 | 24 | no | martello a due pugni: su in punta di piedi, poi giù di peso; colpisce dal fotogramma 8 |
| `hit` | 8 | 24 | no | contraccolpo, testa e braccia in ritardo |
| `doubleJump` | 9 | 24 | no | capriola in avanti che si apre verso la caduta |
| `tumble` | 12 | 24 | sì | rotola all'indietro quando vola via dopo un colpo forte |
| `ledge` | 24 | 12 | sì | appeso con le due mani sullo spigolo, piedi contro la parete, dondola piano |
| `climb` | 10 | 24 | no | si tira su e torna in piedi in `LEDGE.climbMs`; l'ultimo fotogramma è la posa del fermo |
| `land` | 6 | 24 | no | atterra di peso piegando le ginocchia |
| `taunt` | 24 | 12 | no | si toglie la canna, soffia il fumo verso l'avversario e si batte il petto |
| `dash` | 6 | 24 | sì | scatto e corsa: lo stesso galoppo della camminata, più disteso, alla velocità di `DASH.runSpeed` |
| `shield` | 12 | 12 | sì | in guardia dentro la bolla, i pugni davanti alla faccia, respira piano |
| `grab` | 15 | 24 | no | si allunga con le due mani (`hitFrame: 2`), poi tiene l'altro stretto al petto (ultimo fotogramma, finché dura la presa) |
| `throw` | 8 | 24 | no | i quattro lanci: scaglia con le braccia in avanti e in alto (`hitFrame: 0`, si lascia subito) |
| `grabbed` | 12 | 12 | sì | tenuto da qualcuno: si dimena e scalcia |
| `lightUp` | 8 | 24 | no | schiaffo verso l'alto, guardando su (`hitFrame: 2`) |
| `lightDown` | 8 | 24 | no | spazzata bassa col dorso della mano, accucciato con l'altra mano a terra (`hitFrame: 2`) |
| `lightAir` | 8 | 24 | no | rovescio in aria (`hitFrame: 2`) |
| `heavyUp` | 19 | 24 | no | si accuccia con le nocche a terra e balza su battendo i pugni sopra la testa (`hitFrame: 7`) |
| `heavyDown` | 18 | 24 | no | si carica indietro e si butta in avanti basso, le due braccia a terra (`hitFrame: 6`) |
| `heavyAir` | 17 | 24 | no | martello a due pugni in aria (`hitFrame: 5`) |
| `recovery` | 6 | 24 | no | il salto di recupero: sale avvitandosi con le braccia in alto (`hitFrame: 0`) |

Mancano solo `special` e `supreme`, che per ora usano il ripiego di `ANIMATION_FALLBACK` in `characters.ts`: arrivano con il passo 5 di #257.

### Due controlli automatici

- `animazioni_bonobot.py` si ferma se, nel fotogramma `hitFrame` di un attacco, nessuna punta di mano o piede sta dentro la zona del colpo (`ATTACKS` in `constants.ts`, letta da `godot/data/game.json`). Per il recupero vale anche il busto, perché colpisce con tutto il corpo.
- `rendi_sprite.py` avvisa se un fotogramma tocca il bordo, cioè se il disegno viene tagliato.

## Come è fatto

- **Scheletro:** quello di `rig/` (#195): 35 ossa, 30 pezzi nello stile di [docs/stile-grafico.md](../../../../docs/stile-grafico.md), più le IK di braccia e gambe. È spiegato in [docs/scheletro.md](../../../../docs/scheletro.md).
- **Animazioni:** sono scritte in `tools/rig/animazioni_bonobot.py`, come chiavi delle ossa a ogni fotogramma, in `rig/animazioni.json`.
  - Fermo, schiaffo e martello vengono dalla prova dello scheletro in Godot (#198).
  - Le altre sono quelle dello spritesheet di prima (Blender, 19 ossa), portate sulle ossa nuove.
  - Atterraggio e provocazione sono nuove.
- **Disegno dei fotogrammi:** `tools/rig/rendi_sprite.py` mette i pezzi sulle ossa, con l'inchiostro, l'ordine e il fumo (in gioco sarà un effetto), e salva i PNG con una palette di 256 colori.
- **Rifare gli sprite**, dopo aver cambiato le animazioni o i pezzi (per esempio con i disegni veri da Krita):

  ```bash
  python3 tools/rig/animazioni_bonobot.py
  python3 tools/rig/rendi_sprite.py public/assets/characters/bonobot/rig public/assets/characters/bonobot/rig/animazioni.json public/assets/characters/bonobot
  npm run export:godot
  ```

  Se cambia il numero di fotogrammi di un attacco, va rivisto il suo `hitFrame` in `characters.ts`.
- I pezzi sono ancora **provvisori**, disegnati col codice: quando arrivano quelli veri si sostituiscono i PNG in `rig/pezzi/` e si rifanno gli sprite. Le animazioni restano.
- La hitbox di gioco resta quella di `FIGHTER` in `constants.ts` (44×88).
