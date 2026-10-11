# Personaggi: come si preparano gli sprite

Ogni lottatore ha una cartella `public/assets/characters/<id>/` e un blocco in `src/shared/characters.ts`. Lo stile da seguire (linea, colori, misure rispetto alla hitbox, disegno a 2x) è in [docs/stile-grafico.md](../../../docs/stile-grafico.md).

Regole che valgono per tutti i PNG:

- fotogrammi **tutti della stessa misura**, sfondo trasparente;
- il personaggio **guarda a destra** (per l'altra direzione il gioco specchia il fotogramma);
- **piedi sul bordo basso**, al centro del fotogramma: lì il gioco mette la posizione del lottatore;
- lo sprite è solo grafica: la hitbox resta quella di `FIGHTER` in `constants.ts` (44×88 px di mondo);
- si disegna a **2x** e nel blocco si scrive `scale: 0.5`;
- file sotto i 5 MB, e una riga in `public/assets/CREDITS.md` con autore, fonte e licenza.

`npm test` controlla tutte queste regole (`src/shared/assets.test.ts`) e, se qualcosa non va, dice quale file e perché.

## Passo per passo

### 1. Prendi il modello

In [`_modello/`](_modello/) ci sono due PNG da usare come livello di guida, sotto il disegno:

- `modello.png`: un fotogramma con la sagoma della hitbox, i piedi, la direzione e le zone dei colpi leggero e pesante;
- `colpi.png`: le otto varianti d'attacco, ognuna con la sua zona e i millisecondi in cui è accesa.

Il fotogramma del modello è 400×320 px (200×160 di mondo) e contiene tutte le zone dei colpi. Puoi tenerlo così o sceglierne un altro, purché sia **uguale per tutti gli stati** e con i piedi al centro del bordo basso. Il corpo sta dentro la sagoma grigia; braccia, armi e capelli possono uscire.

### 2. Disegna

**Con Krita** (gratis, per i disegni illustrati):

1. *File → Nuovo*: larghezza = fotogramma × numero di fotogrammi (es. 6 fotogrammi da 400 = 2400), altezza = fotogramma (320). Nella scheda *Contenuto* metti lo sfondo **trasparente** (opacità 0).
2. *Livello → Importa/Esporta → Importa livello* con `modello.png`, una volta per fotogramma, spostandolo di 400 px ogni volta (o con la griglia: *Impostazioni → Configura Krita → Griglia e guide*, spaziatura = larghezza del fotogramma). Metti il livello del modello al 30-50% di opacità e bloccalo.
3. Disegna ogni fotogramma nella sua casella, su livelli tuoi sopra il modello.

**Con Aseprite** (per la pixel art e per le animazioni fotogramma per fotogramma):

1. *File → New*: la misura di **un** fotogramma (400×320), *Color Mode: RGBA*, *Background: Transparent*.
2. Un livello col modello (*File → Open* `modello.png`, copia e incolla), opacità bassa, bloccato.
3. Un fotogramma della timeline per ogni fotogramma dell'animazione; se vuoi, un *tag* per stato (`idle`, `walk`...).

### 3. Esporta

- **Nascondi il modello** e ogni livello di sfondo: lo sfondo del PNG dev'essere trasparente.
- **Krita**: *File → Esporta* in PNG, con l'opzione del **canale alfa (trasparenza)** spuntata e senza interlacciamento. Il nome è quello dello stato: `idle.png`, `light.png`...
- **Aseprite**: *File → Export Sprite Sheet*, *Sheet Type: Horizontal Strip*, *Layers: Visible layers*, nessun bordo né spaziatura, *Output File* `idle.png`. Con i tag, nelle versioni recenti c'è *Split Tags*: un PNG per tag, chiamato come il tag (`{tag}.png`).
- Se il PNG supera qualche MB, salvalo a 256 colori (Krita: l'opzione *PNG indicizzato, se possibile* nella stessa finestra; Aseprite: *Sprite → Color Mode → Indexed*): i disegni a tinte piatte restano uguali e pesano molto meno.
- Metti i PNG in `public/assets/characters/<id>/` e aggiungi la riga in `public/assets/CREDITS.md` (basta una per la cartella: `` `characters/<id>/*.png` ``).

### 4. Scrivi il blocco

Il blocco in `src/shared/characters.ts` è descritto qui sotto in [Formato cartella](#formato-cartella-un-png-per-stato-consigliato): `dir`, `frameWidth`, `frameHeight`, `scale: 0.5` e, per ogni stato, `fps`, `loop` e (negli attacchi) `hitFrame`.

### 5. Controlla e prova

```bash
npm test               # misure, nomi, trasparenza, peso e crediti di ogni file
npm run export:godot   # copia i PNG in godot/data
```

I messaggi di `npm test` dicono cosa correggere, per esempio:

```
assets/characters/mario/walk.png: larga 2000 px, non è un multiplo del fotogramma (frameWidth 400): ...
assets/characters/mario/idle.png: l'angolo in alto a sinistra (fotogramma 2) non è trasparente, togli il livello di sfondo
assets/characters/mario/corsa.png: "corsa" non è uno stato; i nomi validi sono in SPRITE_STATES (characters.ts) ...
characters/mario/idle.png: nessuna riga in public/assets/CREDITS.md (autore, fonte, licenza) ...
```

Poi provalo in Godot (comandi in [Provare un personaggio](#provare-un-personaggio)). Dal titolo, **Allenamento** ha un pannello con **Mostra hitbox** e il rallentatore: lì vedi se la mano arriva dentro la zona del colpo nell'istante giusto.

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
- `footY` (facoltativo, accanto a `scale`): a quanti pixel dall'alto del fotogramma stanno i piedi. Di base è il bordo basso; serve se qualche stato scende sotto i piedi, come Bonobot appeso al bordo con il corpo sotto lo spigolo.
- `filter` (facoltativo, accanto a `scale`): `"linear"` (di base) per i disegni illustrati, che il gioco rimpicciolisce con le mipmap senza sfarfallare; `"nearest"` per la pixel art, che resta a quadretti netti.
- Se un PNG manca, la larghezza o l'altezza non tornano o `hitFrame` è fuori dai fotogrammi, `npm run export:godot` si ferma e dice quale file e perché. Un PNG nella cartella che il blocco non nomina viene segnalato e non si usa.

## Formato a foglio unico: una riga per animazione

È il formato di Capt. OrsoBlu: un PNG solo, con una riga per animazione. Nel blocco si scrivono `path`, `columns` (fotogrammi per riga) e, per ogni animazione, `row` e `frames` oltre a `fps` e `loop`. Esempio completo: [orsoblu/README.md](orsoblu/README.md). Bonobot è nel formato a cartella: [bonobot/README.md](bonobot/README.md). Funziona ancora, ma per i personaggi nuovi conviene la cartella: si aggiunge uno stato senza rifare il foglio.

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
