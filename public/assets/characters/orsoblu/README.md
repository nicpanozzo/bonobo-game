# Capt. OrsoBlu

Proposto da @MauroGrecchi in #37 (si chiamava Egiainuso, rinominato con #178). Dal 3/11/2026 è la versione 2 scelta con Nicola: un vecchio capitano di mare burbero e pignolo, un orso blu con la barchetta rovesciata in spalla, il berretto, il cappotto giallo e il fischietto. La meccanica principale sarà l'ancora usata come una ragnatela per appendersi, dondolare e arrampicarsi.

## Da dove vengono i disegni

Dalle prime 4 clip fatte su Google Flow (Veo 3.1 Lite), tagliate con `tools/sprite/dal_video.py`:

| Clip | Stati |
|---|---|
| OB-03 | `idle`, `walk`, `taunt`, `jumpSquat`, `jump`, `fall`, `land`, `hit` |
| OB-07 | `heavy`, `heavyUp`, `shield` |
| OB-01 | `recovery`, `anchorHang` (appeso all'ancora) e `anchorClimb` (arrampicata sulla catena, #547) |
| OB-02 | `specialSide`, `doubleJump`, `specialNeutral`, `light` |

I fotogrammi presi a mano sono in `tools/sprite/flow_tagli.json`. I video non sono nella repo: se servono, chiedili a Nicola.

**È incompleto apposta:** si mette nel gioco quel che c'è. Finché non arriva il pacchetto base (`docs/clip-flow/base.md`), alcuni stati sono provvisori:
- `light` è la spinta della speciale neutra;
- `heavy` è la barca alzata;
- `hit` è l'atterraggio pesante;
- `fall` è un pezzo della salita del salto, perché nella clip la testa esce dall'inquadratura.

Fotogrammi da 360×300 a 2x, piedi a 280, guarda a destra.
