# Marcomunista

Marco col cappello da pescatore, la felpa gialla, gli occhiali e la barba. Pelato: sotto il cappello niente capelli.

## Sprite: formato a cartella (E7)

- **Animato dalla GIF di arti marziali** fornita da Nicola il 2026-10-19 (480×270, 160 fotogrammi da 60 ms): tai chi, giravolta con l'anello verde, calcio con l'esplosione. Scontornata, specchiata per guardare a destra e ritoccata: dove la GIF mostra la nuca coi capelli (di schiena e girato) è diventata pelle. L'energia verde resta: fa da scia dei colpi.
- Fotogrammi da **400×240 px** con i piedi a 222 (`footY`) e `scale: 0.5`: alto come le pose del foglio, quindi come la hitbox.
- **Contorno chiaro** di 2 px attorno al corpo (non all'energia), come le pose del foglio, per leggersi sui fondali scuri.
- PNG a 256 colori: la GIF è retinata e a colori pieni pesava il triplo.
- `portrait.png`: testa e cappello del fermo, per lobby e HUD.

| Stato | Fotogrammi della GIF | Colpo (`hitFrame`) |
|---|---|---|
| `idle` | 0-4, avanti e indietro (respiro) | |
| `jump`, `fall` | 83-87, 106-108 | |
| `doubleJump`, `tumble` | la giravolta con l'anello, 88-102 | |
| `land` | 79-81, accovacciato | |
| `light`, `grab` | colpo di palmo, 133-135 | 2 |
| `heavy` | calcio con l'esplosione, 119-134 | 5 |
| `lightUp` | 49-54, braccio in alto | 3 |
| `heavyUp`, `recovery` | braccia al cielo con l'energia, 108-113 | 4, 0 |
| `lightDown` | 72-76, giù | 2 |
| `heavyDown` | giù di peso, energia a terra dai due lati, 113-119 | 3 |
| `lightAir`, `heavyAir` | 84-87; l'anello, 89-97 | 1, 3 |
| `specialNeutral`, `throw` | spinta in avanti, 33-42 | 5, 0 |
| `specialDown` | Rolling: para, mano alla bocca, 43-50 | 1 |
| `supreme` | …COSA?: l'anello, la nuvola (torna indietro), il fumo, 138-159 | 12 |
| `taunt` | tai chi con l'energia, 52-70 | |
| `shield` | 26-32, mani basse con l'energia | |
| `hit` | 46-47 senza energia, piegato all'indietro | |
| `walk`, `dash` | **non ci sono nella GIF**: le pose del foglio ([#352](https://github.com/nicpanozzo/bonobo-game/issues/352)), allargate al fotogramma nuovo | |

## Rifarlo

```bash
pip install "rembg[cpu]"   # solo per lo scontorno, non serve al gioco
python3 tools/sprite/marcomunista_dalla_gif.py <marco-arti-marziali.gif> <cartella di lavoro>
npm run export:godot
```

La GIF non è nella repo (chiedila a Nicola). Quali fotogrammi vanno in quale stato e dove togliere i capelli lo dice lo script (`PLAN` e `NAPE`). Se cambiano i fotogrammi d'impatto, vanno ricopiati in `characters.ts`.
