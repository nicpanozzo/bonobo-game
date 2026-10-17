# Marcomunista

Marco col cappello da pescatore, la felpa gialla e la canna in bocca, dal suo foglio delle pose ([#352](https://github.com/nicpanozzo/bonobo-game/issues/352)). Ha preso il posto del disegno provvisorio fatto col codice.

## Sprite: formato a cartella (E7)

- **Una posa per stato**, ritagliata dal foglio, come Egiainuso. La corsa alterna due pose (`Walk` e `Run`).
- Fotogrammi da **304×196 px** con i piedi a 182 (`footY`) e `scale: 0.5`: nel gioco Marco è alto come la hitbox (44×88).
- Disegno a colori col tratto nero; per leggersi sui fondali scuri ha un **contorno chiaro**. La Final Smash (la statua dorata col bagliore) è più grande del fotogramma del lottatore e ai bordi è tagliata come nel foglio.
- `portrait.png`: testa e cappello, per lobby e HUD.

| Stato | Posa del foglio |
|---|---|
| `idle` | Idle |
| `walk` | Walk, Run |
| `dash` | Dash |
| `jump`, `fall` | Jump, Fall |
| `land` | Crouch |
| `light`, `lightUp`, `lightDown`, `lightAir` | Side Tilt, Up Tilt, Down Tilt, Neutral Air |
| `heavy`, `heavyUp`, `heavyDown`, `heavyAir` | Side Smash, Up Smash, Down Smash, Forward Air |
| `recovery` | Up Air |
| `shield`, `grab`, `throw` | Shield, Grab, Throw (forward) |
| `specialNeutral`, `specialDown` | Pummel, Shield |
| `supreme` | Final Smash |
| `hit` | non c'è: il fermo piegato all'indietro |

Gli altri stati usano il ripiego di `ANIMATION_FALLBACK` (la speciale laterale mostra Side Smash). *Throw (back)*, *Back Air* e *Down Air* per ora non hanno uno stato.

## Rifarlo

```bash
python3 tools/sprite/foglio_a_colori.py <foglio.png> public/assets/characters/marcomunista
npm run export:godot
```

Il foglio originale non è nella repo: è nella #352. Se cambia la misura dei fotogrammi, lo script la stampa: va ricopiata in `characters.ts`.
