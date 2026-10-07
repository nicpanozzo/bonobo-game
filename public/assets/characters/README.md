# Personaggi: come si preparano gli sprite

Ogni lottatore ha una cartella `public/assets/characters/<id>/` e un blocco in `src/shared/characters.ts`. Lo stile da seguire (linea, colori, misure rispetto alla hitbox, disegno a 2x) è in [docs/stile-grafico.md](../../../docs/stile-grafico.md).

Regole che valgono per tutti i PNG:

- fotogrammi **tutti della stessa misura**, sfondo trasparente;
- il personaggio **guarda a destra** (per l'altra direzione il gioco specchia il fotogramma);
- **piedi sul bordo basso**, al centro del fotogramma: lì il gioco mette la posizione del lottatore;
- lo sprite è solo grafica: la hitbox resta quella di `FIGHTER` in `constants.ts` (44×88 px di mondo);
- si disegna a **2x** e nel blocco si scrive `scale: 0.5`;
- file sotto i 5 MB, e una riga in `public/assets/CREDITS.md` con autore, fonte e licenza.

## Formato cartella: un PNG per stato (consigliato)

Nella cartella c'è un PNG per stato, con il nome dello stato: `idle.png`, `walk.png`, `light.png`... In ogni PNG i fotogrammi sono **in fila da sinistra**, su una riga sola. Non serve dire quanti sono: `npm run export:godot` li conta dalla larghezza del PNG, che dev'essere un multiplo della larghezza del fotogramma.

```
public/assets/characters/mario/
  idle.png    6 fotogrammi da 256×240 → 1536×240
  walk.png    8 fotogrammi            → 2048×240
  ...
```

```ts
mario: {
  id: "mario",
  name: "Mario",
  sprite: {
    dir: "assets/characters/mario",
    frameWidth: 256, // pixel del PNG, uguali in tutti gli stati
    frameHeight: 240,
    scale: 0.5, // disegnato a 2x
    animations: {
      idle: { fps: 12, loop: true },
      walk: { fps: 24, loop: true },
      jump: { fps: 24, loop: false },
      fall: { fps: 24, loop: true },
      light: { fps: 24, loop: false },
      heavy: { fps: 24, loop: false },
      hit: { fps: 24, loop: false },
    },
  },
},
```

- `fps`: fotogrammi al secondo. 24 per i movimenti, 12 va bene per le animazioni lente in ciclo.
- `loop`: `true` ricomincia (fermo, corsa, caduta), `false` si ferma sull'ultimo fotogramma (salto, colpi).
- `hitFrame` (facoltativo, solo negli attacchi): il fotogramma, contando da 0, in cui la mano o l'arma arriva sul bersaglio. Il gioco lo fa cadere nell'istante in cui la hitbox si accende (`startupMs` di `ATTACKS`) e fa finire l'animazione con `cooldownMs`. Così il colpo è sempre a tempo, anche quando cambiano i numeri o quando una variante (`lightUp`...) usa il disegno di `light`. Senza `hitFrame` l'animazione va a `fps`.
- `filter` (facoltativo, accanto a `scale`): `"linear"` (di base) per i disegni illustrati, che il gioco rimpicciolisce con le mipmap senza sfarfallare; `"nearest"` per la pixel art, che resta a quadretti netti.
- Se un PNG manca, la larghezza o l'altezza non tornano o `hitFrame` è fuori dai fotogrammi, `npm run export:godot` si ferma e dice quale file e perché. Un PNG nella cartella che il blocco non nomina viene segnalato e non si usa.

## Formato a foglio unico: una riga per animazione

È il formato di Egiainuso e, per ora, di Bonobot: un PNG solo, con una riga per animazione. Nel blocco si scrivono `path`, `columns` (fotogrammi per riga) e, per ogni animazione, `row` e `frames` oltre a `fps` e `loop`. Esempio completo: [bonobot/README.md](bonobot/README.md). Funziona ancora, ma per i personaggi nuovi conviene la cartella: si aggiunge uno stato senza rifare il foglio.

## Gli stati

Obbligatori (`ANIMATION_NAMES` in `characters.ts`):

| Stato | Quando |
|---|---|
| `idle` | fermo a terra |
| `walk` | corsa a terra |
| `jump` | in salita dopo il salto |
| `fall` | in discesa |
| `light` | attacco leggero (deve colpire nei fotogrammi di `startupMs` e `activeMs` di `ATTACKS.light`) |
| `heavy` | attacco pesante (lo stesso, con `ATTACKS.heavy`) |
| `hit` | colpito, durante lo stordimento |

Facoltativi (`OPTIONAL_ANIMATION_NAMES`). Chi non li ha usa quello della colonna "Al suo posto" (`ANIMATION_FALLBACK`):

| Stato | Quando | Al suo posto |
|---|---|---|
| `doubleJump` | il salto in aria | `jump` |
| `tumble` | lanciato forte da un colpo, mentre vola | `hit` |
| `ledge` | appeso al bordo del palco | `jump` |
| `climb` | risale dal bordo | `jump` |
| `land` | atterraggio | `idle` |
| `lightUp`, `lightDown`, `lightAir` | varianti dell'attacco leggero | `light` |
| `heavyUp`, `heavyDown`, `heavyAir` | varianti dell'attacco pesante | `heavy` |
| `recovery` | il salto di recupero | `jump` |
| `taunt` | provocazione | `idle` |
| `shield` | con lo scudo alzato, dentro la bolla | `idle` |
| `grab` | parte la presa, e poi si tiene l'altro (#109) | `light` |
| `throw` | uno dei quattro lanci dalla presa | `grab` |
| `grabbed` | tenuto da qualcuno con la presa | `hit` |
| `special` | posto per le mosse speciali (E10): il gioco non lo usa ancora | `heavy` |

Il ripiego si decide una volta sola: `npm run export:godot` scrive in `godot/data/game.json` la tabella completa, con tutti gli stati. Le animazioni di passaggio (`doubleJump`, `tumble`, `land`, `taunt`) si vedono solo se sono disegnate: col ripiego interromperebbero la corsa o il salto.

## Provare un personaggio

```bash
npm run export:godot                      # copia i PNG in godot/data e controlla le misure
godot --headless --path godot --import    # dopo aver cambiato un PNG, se no Godot usa la copia vecchia
npm run dev                               # il server
godot --path godot -- --room=prova --name=A --char=<id>
```

Muoviti, salta, attacca e fatti colpire: ogni stato deve avere la sua animazione.
