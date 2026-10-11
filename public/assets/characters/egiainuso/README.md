# Egiainuso

L'omino col cappellino e lo zaino del foglio delle pose di @Marcomunista ([#178](https://github.com/nicpanozzo/bonobo-game/issues/178)). Il nome era della creatura blu sulla barchetta, che ora si chiama Capt. OrsoBlu (`../orsoblu/`).

## Sprite: formato a cartella (E7)

- **Una posa per stato**, ritagliata dal foglio. La corsa alterna due pose (`Walk` e `Run`). Non ci sono animazioni vere, come per la versione provvisoria di Elvedeo.
- Fotogrammi da **318×238 px** con i piedi a 194 (`footY`) e `scale: 0.5`: nel gioco l'omino è alto poco più della hitbox (44×88).
- **Eccezione alla style guide:** è un disegno a tratto nero su fondo bianco, non illustrato a 2 toni. Per leggersi sui fondali scuri ha un **contorno chiaro**, e la faccia è riempita di bianco.
- `portrait.png`: testa e cappellino, per lobby e HUD.

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
| `supreme` | Final Smash |
| `hit` | non c'è: il fermo piegato all'indietro |

Gli altri stati (doppio salto, lanciato, bordo, provocazione...) usano il ripiego di `ANIMATION_FALLBACK`. Le pose *Pummel*, *Throw (back)*, *Back Air* e *Down Air* per ora non hanno uno stato.

## Rifarlo

```bash
python3 tools/sprite/egiainuso_dal_foglio.py <foglio.png> public/assets/characters/egiainuso
npm run export:godot
```

Il foglio originale non è nella repo: è nella #178. Se cambia la misura dei fotogrammi, lo script la stampa: va ricopiata in `characters.ts`.

## Da chiedere a Marco

- Il foglio l'hai fatto tu o con un generatore di immagini? Con che licenza lo dai al gioco?
- Che statistiche (velocità, salto, peso) e che mosse speciali vuoi per Egiainuso?
- Ci sono animazioni vere in arrivo, con più fotogrammi per mossa?
