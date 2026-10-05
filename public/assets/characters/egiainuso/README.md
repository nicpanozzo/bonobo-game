# Egiainuso

Creatura blu su una barchetta, con un remo. Proposto da @MauroGrecchi in #37.

## Spritesheet: `egiainuso.png`

- Fotogrammi da **64×96 px** (pixel art disegnata a 32×48 e ingrandita ×2), sfondo trasparente.
- Griglia di 6 colonne × 7 righe, una riga per animazione, fotogrammi da sinistra.
- Guarda **a destra**: per andare a sinistra si specchia lo sprite.
- I piedi (il fondo della barca) sono sulla riga in basso del fotogramma: l'origine è `(0.5, 1)`, come `y` in `PlayerState`.

| Riga | Animazione | Fotogrammi | Note |
|---|---|---|---|
| 0 | fermo | 4 | dondola sull'acqua, l'ultimo strizza gli occhi |
| 1 | camminata | 6 | rema |
| 2 | salto | 2 | la barca si stacca dall'acqua |
| 3 | caduta | 2 | |
| 4 | attacco leggero | 3 | pugno in avanti |
| 5 | attacco pesante | 4 | colpo di remo |
| 6 | colpito | 2 | il primo è bianco (lampo) |

La hitbox di gioco resta quella di `FIGHTER` in `constants.ts`: lo sprite è solo grafica.
