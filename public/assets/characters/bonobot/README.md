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

Gli altri stati (varianti dei colpi, scudo, scatto, suprema...) usano il ripiego di `ANIMATION_FALLBACK` in `characters.ts`.

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
