# Arene ed elementi: come se ne fanno di nuove

Un'arena è **solo dati**: un blocco in `STAGES` dentro `src/shared/stages.ts`. La fisica (sul server) e il client Godot leggono gli stessi dati, quindi un'arena nuova non ha codice suo.
Un **elemento** (ascensore, trappola, trampolino...) è invece un comportamento: si scrive una volta in codice e poi ogni arena lo usa con i suoi numeri.

## Il giro, dalla richiesta al gioco

1. **Chiunque del canale apre un'issue** dal modulo giusto (GitHub → Issues → New issue), o la fa aprire all'[editor delle arene](https://nicpanozzo.github.io/bonobo-game/editor/) con "Proponi":
   - **Arena nuova**: nome, il posto o la battuta dietro, la forma a parole o con un disegno, gli elementi da usare.
   - **Elemento nuovo**: cosa fa a chi lo tocca, come cambia nel tempo, cosa si deve poter regolare.
2. **Chi la legge** (una persona o un agente) completa i dettagli mancanti con domande nell'issue e la sposta a `pronto`.
3. **Un agente la prende** come ogni altra issue (`AGENTS.md`, "Scegliere un compito"):
   - arena: una PR che aggiunge il blocco in `stages.ts`, rilancia `npm run export:godot` e mette **uno screenshot** del client Godot;
   - elemento: una PR (titolo `Protocollo:` se cambia cosa viaggia in rete) con logica, test e disegno.
4. La PR si unisce con la CI verde: la serata dopo l'arena è nel gioco.

Le arene non dipendono l'una dall'altra, quindi più agenti ne possono fare insieme senza conflitti: ognuno aggiunge il suo blocco.

### Perché così

- **Issue con un modulo** (l'idea di Nicola) perché gli agenti vedono solo GitHub: la richiesta resta scritta, discussa e collegata alla PR che la realizza. Il modulo fa le domande giuste a chi non programma.
- **Arene come dati** perché sono facili da controllare (i test in `stages.test.ts` verificano che ogni piattaforma sia raggiungibile e che le partenze siano sul palco) e un agente le scrive in pochi minuti.
- **L'editor sul sito** ([nicpanozzo.github.io/bonobo-game/editor](https://nicpanozzo.github.io/bonobo-game/editor/), codice in `site/editor/`, #91): si parte da un'arena del gioco, si trascinano blocchi, piattaforme, ascensori e trappole e si vede subito come viene. Le piattaforme irraggiungibili sono rosse (stesso controllo dei test, `src/shared/stageCheck.ts`) e le partenze si mettono da sole. "Proponi" apre l'issue "Arena nuova" con i dati già scritti; "Copia" dà il blocco da incollare in `stages.ts`. Una descrizione a parole o un disegno su carta vanno bene lo stesso: i numeri li sceglie l'agente.

## Il formato di un'arena

Lo schermo è largo 1280 e alto 720 pixel, con `y` che cresce verso il basso. Le `y` di blocchi e piattaforme sono **la superficie su cui si cammina**. Un lottatore è largo 44 e alto 88; un salto sale circa 160 pixel, con il doppio salto circa 300.

```ts
fabbrica: {
  id: "fabbrica",                 // minuscolo, senza spazi: è anche il nome nell'indirizzo
  name: "La Fabbrica",            // come appare nella lobby
  solids: [                       // blocchi pieni: ci si cammina sopra, non si attraversano
    { x: 140, y: 560, width: 300, height: 90 },
  ],
  platforms: [                    // sottili: si attraversano dal basso, si scende con giù
    { x: 540, y: 290, width: 200 },
  ],
  movers: [ /* piattaforme mobili, sotto */ ],
  hazards: [ /* trappole, sotto */ ],
  blastZone: { left: -250, right: 1530, top: -350, bottom: 920 }, // chi esce perde una vita
  spawns: [{ x: 300, y: 560 }, { x: 980, y: 560 } /* ... 8 in tutto, a coppie simmetriche */],
  respawn: { x: 640, y: 160 },    // dove si ricompare
  colors: { sky: 0x22201f, solid: 0x4a4f57, solidEdge: 0xf1c40f, platform: 0xc0c6cc },
}
```

Nelle partenze, `team` (facoltativo) dice quale squadra parte lì nelle modalità a squadre (#433): per esempio la squadra 1 a sinistra e la 2 a destra, con `{ x: 200, y: 560, team: 1 }` e `{ x: 1600, y: 560, team: 2 }`. Con più di due squadre su un'arena a due, la 3 parte dove la 1 e la 4 dove la 2. Ogni compagno prende un posto diverso della propria squadra. Senza `team` (o in FFA) la partenza è quella di sempre, per indice.

### Arene più grandi dello schermo e zoom (`width`, `camera`)

Un'arena può essere più larga dello schermo con `width`, per esempio 1920 per un'arena da 1,5 schermi. Tutti i pezzi devono stare tra 0 e `width`. La telecamera inquadra tutti i lottatori vivi: si avvicina quando sono vicini e si allontana quando si sparpagliano, senza mai mostrare più delle zone di espulsione.

Quanto può allontanarsi lo decide `camera.minZoom`; senza, vale `CAMERA.minZoom` (0,7), che basta per le arene larghe uno schermo. Con `camera.maxZoom` si cambia quanto si avvicina.
Con `camera.floorY` (#400) la telecamera tiene sempre inquadrata quella y del mondo, come Smash che non perde di vista il palco: chi sale sulla piattaforma più alta vede ancora il pavimento sotto di sé, e lo sfondo non si stacca.

Un'arena larga 1920 ha bisogno di circa 0,6 per mostrarsi intera, con i lottatori ai due capi. Sotto `CAMERA.stageMinZoomFloor` (0,45) i lottatori diventano troppo piccoli, e `npm test` lo segnala. Allarga anche le zone di espulsione, così la telecamera ha spazio.

```ts
width: 1920,
camera: { minZoom: 0.6 },
blastZone: { left: -300, right: 2220, top: -420, bottom: 1000 },
```

**Arene alte** (#433): con `height` (per esempio 1800) l'arena è più alta dello schermo (720). Tutti i pezzi devono stare tra 0 e `height`, la telecamera inquadra anche in verticale e gli strati dello sfondo si centrano a metà altezza. Senza `height` vale 720 e nulla cambia. Allarga `blastZone.bottom` oltre `height`, e per vedere un'arena alta quasi intera abbassa `camera.minZoom` (non sotto 0,45).

**Telecamera e testo per fase** (#433): se l'arena ha `phases` (il campo è descritto nel suo passo), la telecamera della fase attiva (`camera.minZoom`, `maxZoom`, `floorY`) sostituisce campo per campo quella dell'arena, e la sua `blastZone` limita la vista. Al cambio di fase zoom e pavimento si spostano piano in `CAMERA.phaseBlendMs` (1 s), senza salti. Il `name` della fase appena cominciata compare grande sullo schermo per `EFFECTS.phaseBannerMs` (2,5 s); `warnMs` prima dell'inizio compare in arancio il suo `announce`. È tutto del client, dal tempo dell'arena (`stageMs`): la logica sta in `godot/scripts/stage_phases.gd`.

I percorsi della Corsa sono larghi anche loro, ma lì la telecamera segue il proprio lottatore: la differenza è il traguardo (`goal`).

### Arene nascoste (`hidden`)

Con `hidden: true` un'arena resta in `stages.ts`, con i suoi disegni, e il server la avvia ancora se la si chiede per id, ma la lobby non la mostra e non può essere l'arena predefinita (lo controllano i test). Serve per tenere una versione vecchia per le emergenze, come `padova-palazzo` (#408). **Per rimetterla in gioco basta togliere la riga `hidden`** e rilanciare `npm run export:godot`.

### Piattaforme ad arco (`arch`): un ponte curvo

Una piattaforma sottile con `arch` ha la superficie curva, come un ponte: alle estremità è alta `y`, al centro sale di `arch` pixel. Chi ci cammina segue la curva, e anche gli oggetti ci si appoggiano sopra; per il resto è una piattaforma sottile come le altre (si attraversa dal basso, si scende con giù). Alle estremità ha la stessa `y` dei blocchi vicini, così ci si arriva camminando. La curva deve restare dolce: `arch` al massimo un ottavo della larghezza, e `npm test` lo controlla.

```ts
{ x: 720, y: 520, width: 480, arch: 25 } // il ponte di Prato della Valle (#230), tra due piazze a y 520
```

### Piattaforme inclinate (`y2`): le scale

Una piattaforma sottile con `y2` è una rampa: va dritta da `y` (estremità sinistra) a `y2` (estremità destra), e si cammina in salita e in discesa senza saltare. Si disegna come una scala di gradini; i piedi stanno sulla rampa, che tocca lo spigolo di ogni gradino.

- La pendenza arriva al massimo a 1:1, come una scala vera; `arch` e `y2` non vanno insieme. `npm test` controlla tutte e due le cose.
- Da un blocco pieno si sale sulla rampa camminando, se parte poco più su dei piedi. Per passare in cima da una rampa a un blocco pieno, la rampa deve arrivare 2 px sopra il blocco, a 22 px dal suo bordo (mezzo lottatore): altrimenti il blocco ti spinge di lato.
- Tenendo giù su una piattaforma sottile si scende attraverso. Una rampa o un arco **chiaramente più in basso** ti prende mentre cadi: è così che da un ponte si scende su una scala sotto (com'era Padova prima del #288). Con le sole piattaforme dritte non cambia niente.

```ts
{ x: 742, y: 518, width: 180, y2: 690 } // una scala dalla piazza (520) al fondo di un canale (690)
```

## Gli elementi che esistono

### Piattaforma mobile (`movers`): ascensore, navetta

Una piattaforma sottile che passa per una lista di punti. Chi ci sta sopra viene trasportato; si scende con giù.

| Campo | Cosa fa |
|---|---|
| `width` | larghezza in pixel |
| `path` | punti `{ x, y }` (bordo sinistro, superficie), almeno 2 |
| `periodMs` | durata di un giro completo, soste comprese |
| `loop` | `true`: dall'ultimo punto torna dritto al primo; altrimenti va avanti e indietro |
| `pauseMs` | sosta a ogni punto (l'ascensore al piano) |
| `offsetMs` | sfasamento, per far partire due piattaforme in momenti diversi |

```ts
{ width: 140, path: [{ x: 570, y: 540 }, { x: 570, y: 260 }], periodMs: 7000, pauseMs: 1200 } // ascensore
```

**Ruota** (#378, la fontana di Padova): `waterWheel(cx, cy, r, n, width, periodMs)` in `stages.ts` dà `n` piattaforme sullo stesso cerchio, sfasate in parti uguali, che girano restando in piano come le cabine di una ruota panoramica. È un `path` chiuso di 36 lati con `loop: true`: non serve altra fisica.

```ts
movers: waterWheel(960, 330, 130, 3, 120, 18000), // tre tazze, un giro in 18 s
```

Una piattaforma mobile con `kind: "barca"` si disegna come una barca (#264): la superficie su cui si sta è sempre la `y` del percorso. Con le piattaforme mobili il predittore del proprio lottatore si spegne solo vicino al loro percorso.

### Arena musicale (`song`): piattaforme che vanno a tempo di un MIDI (#423)

**Guida completa: [arena-musicale.md](arena-musicale.md)** (come funziona, bottoni sonori, come cambiare brano).

Le tracce di un brano diventano piattaforme mobili: si muovono o compaiono con le note, e Godot suona il brano allineato al tempo dell'arena. Il primo esempio è **Sala Prove** (`musica` in `stages.ts`), con un brano nostro di 32 secondi.

Una piattaforma mobile può avere, al posto del solo `path`:

| Campo | Cosa fa |
|---|---|
| `keys` | posizioni a tempo `[ms nel giro, x, y]`, in ordine; tra due chiavi va dritta |
| `on` | finestre `[da ms, a ms)` del giro in cui c'è; fuori non c'è e chi ci sta sopra cade |
| `tint` | il colore della traccia (solo disegno, con `kind: "nota"`) |

Con `pads` l'arena ha anche **bottoni sonori**: si premono saltandoci sopra o colpendoli, suonano e per qualche secondo accendono o spostano le piattaforme di un `group`, poi restano scarichi per un po'.

Non si scrivono a mano: `songMovers(brano, ruoli)` in `src/shared/musicStage.ts` le calcola dalle note. Ruoli: `lift` (ascensore che sale con le note più alte), `slide` (navetta che va a destra con le note più alte), `keys` (tasti che si accendono con le note, come un piano roll). Per un brano nuovo vedi [src/shared/music/README.md](../src/shared/music/README.md).

### Trappola (`hazards`): spuntoni, fuoco, laser

Un rettangolo che, quando è acceso, aggiunge percentuale e lancia via chi lo tocca (come un colpo). Il KO va a chi ti ci ha spinto. Dopo una trappola si è al sicuro per `HAZARD.cooldownMs` (in `constants.ts`).

| Campo | Cosa fa |
|---|---|
| `x`, `y`, `width`, `height` | il rettangolo che fa male |
| `kind` | come si disegna: `"spuntoni"`, `"fuoco"`, `"acqua"` (con la pioggia se c'è `flood`), altrimenti un rettangolo rosso |
| `damage` | percentuale aggiunta |
| `knockback`, `knockbackGrowth` | lancio di base (pixel/s) e quanto cresce per ogni punto di percentuale |
| `angleDeg` | direzione: 90 dritto in alto, meno di 90 in diagonale lontano dal centro della trappola |
| `periodMs`, `activeMs`, `offsetMs` | se c'è `periodMs`, si accende per `activeMs` a ogni giro |
| `warnMs` | solo con `periodMs` (#433): negli ultimi `warnMs` prima di ogni finestra accesa **non fa male** (la fisica è quella di sempre) ma Godot disegna un avviso: il rettangolo che lampeggia; per `kind: "fulmine"` una linea tratteggiata dal cielo e il bersaglio che brilla, e quando è acceso una saetta a zig-zag con un lampo. Acqua alta e trappole che viaggiano hanno il loro `warnMs` |

```ts
{ kind: "fuoco", x: 440, y: 610, width: 400, height: 30, damage: 8, knockback: 600, knockbackGrowth: 4, angleDeg: 80, periodMs: 4000, activeMs: 1500 }
```

### Acqua alta (`flood` in una trappola): il canale che sale con la pioggia

Una trappola con `flood` ha la superficie che sale e scende a ciclo: il rettangolo scritto nell'arena è l'acqua bassa, `highY` è la superficie con l'acqua alta, il fondo (`y + height`) resta fermo. Chi tocca l'acqua viene colpito come da ogni trappola, quindi conviene un lancio verso l'alto che lo tira fuori (`angleDeg` vicino a 90). Le piattaforme sommerse restano: chi ci sta sopra è in acqua.

Ogni giro, alla fine di `periodMs`: **calma**, poi **avviso** (piove ma l'acqua è ancora bassa), **salita**, **alta**, **discesa**.

| Campo di `flood` | Cosa fa |
|---|---|
| `highY` | superficie con l'acqua alta (più in alto di `y`, quindi un numero più piccolo) |
| `periodMs` | durata di un giro completo |
| `warnMs` | avviso prima della salita: la pioggia |
| `riseMs`, `holdMs` | durata della salita e di quanto resta alta |
| `fallMs` | durata della discesa (uguale a `riseMs` se manca) |
| `offsetMs` | sfasamento del giro |

```ts
{ kind: "acqua", x: 440, y: 660, width: 400, height: 30, damage: 6, knockback: 550, knockbackGrowth: 3, angleDeg: 85,
  flood: { highY: 550, periodMs: 40000, warnMs: 4000, riseMs: 3000, holdMs: 6000, fallMs: 3000 } } // un canale che sale con la pioggia
```

### Trappola che viaggia (`travel` in una trappola): il ciclista arrabbiato

Una trappola con `travel` passa lungo un percorso a ogni giro. Prima c'è la **calma**, poi l'**avviso** (il campanello, e "DRIN DRIN!" sul lato da cui arriva), poi il **passaggio**. Fa male solo mentre passa, e lancia **nella direzione in cui va** (`angleDeg` misurato da quella direzione verso l'alto). `x` e `y` della trappola sono ignorati, perché la posizione la dà il percorso; `width` e `height` sono il rettangolo che fa male.

| Campo di `travel` | Cosa fa |
|---|---|
| `path` | punti `{ x, y }` dove passa l'angolo in alto a sinistra del rettangolo, almeno 2. Possono stare fuori dallo schermo, così entra ed esce dalla scena |
| `periodMs` | durata di un giro |
| `warnMs` | avviso prima che entri |
| `crossMs` | durata del passaggio da un capo all'altro |
| `alternate` | `true`: un giro all'andata e il successivo al ritorno |
| `offsetMs` | sfasamento del giro, per non farla coincidere con altri elementi |

Il tipo `"ciclista"` si disegna come il signore arrabbiato in bici, con la catena che gira.

#### Un'animazione disegnata per una trappola (`art.hazardSprites`)

Al posto del disegno fatto col codice, una trappola può avere un'animazione: un foglio di fotogrammi uno accanto all'altro, **rivolti a destra** (il gioco li specchia quando la trappola va a sinistra), nella cartella dell'arena. Solo grafica: la fisica usa sempre il rettangolo della trappola.

| Campo | Cosa fa |
|---|---|
| `hazard` | indice della trappola in `hazards` |
| `file`, `frames`, `fps` | il foglio, quanti fotogrammi e quanti al secondo (sul tempo dell'arena) |
| `scale` | pixel di mondo per pixel dell'immagine (1 se manca) |
| `footX`, `footY` | il punto del fotogramma (in pixel) che va sul centro del lato basso del rettangolo |
| `shout` | facoltativo, `{ text, x, y }`: un fumetto a punte che esce da quel punto del fotogramma (la bocca) mentre la trappola passa |

```ts
hazardSprites: [{ hazard: 1, file: "ciclista.png", frames: 8, fps: 16, scale: 0.58, footX: 150, footY: 312, shout: { text: "CANCAROOOO!", x: 200, y: 110 } }]
```

Cancaro Man di Padova lo disegna `tools/arene/ciclista.py`: un disegno vero lo sostituisce tenendo le stesse misure (8 fotogrammi da 300×320).

Le piattaforme mobili hanno lo stesso meccanismo con `art.moverSprites` (#273): `{ mover, file, frames, fps, scale, footX, footY }`, dove `mover` è l'indice in `movers` e `footX`, `footY` va sul centro della superficie. L'animazione si gira nel verso in cui va la piattaforma, e da ferma verso il centro dell'arena. Con `stem: { sheet, baseY, width }` sotto la piattaforma si disegna anche il gambo che la regge, un foglio di `life.sheets` stirato da `baseY` fino a lei (#378); con `hub: { x, y }` il gambo sale unico fino al mozzo e da lì un raggio va a ogni piattaforma, come i tre spruzzi della fontana di Padova. Le barche che Padova aveva prima del #288 erano fatte così; il generatore è nella storia di git (`tools/arene/barca.py`).

```ts
{ kind: "ciclista", x: 0, y: 0, width: 80, height: 95, damage: 10, knockback: 600, knockbackGrowth: 5, angleDeg: 35,
  travel: { path: [{ x: -160, y: 425 }, { x: 2080, y: 425 }], periodMs: 20000, warnMs: 1000, crossMs: 2800, alternate: true } }
```

### Canale: acqua bassa innocua, getti e oggetti (`lowSafe`, `jets`, `itemSpots`)

Servono a dare un motivo per andare in una zona rischiosa (#253). A Padova la fontana al centro della piazza è un getto con `idle` (#288).

- **`flood.lowSafe: true`** (nell'acqua alta): l'acqua bassa non fa male, solo quella che sale, resta alta e scende.
- **Riparo dal ciclista:** la trappola che viaggia colpisce solo chi ha i piedi all'altezza del suo percorso, entro `HAZARD.travelFeetPx`. Chi sta più in basso, per esempio sotto il ponte, è al riparo.
- **`jets`**, getti d'acqua a tempo: `{ x, y, width, height, speed, periodMs, warnMs, activeMs, offsetMs?, idle? }`.
  - Con **`dir: "left" | "right"`** (#433) il getto diventa una **raffica di vento**: stessa zona (`x..x+width`, `y-height..y`) e stesso ciclo avviso/acceso, ma spinge di lato. In aria la velocità orizzontale accelera verso `speed` pixel/s (`WIND.accelPxPerS2`), a terra la spinta è solo una frazione (`WIND.groundFactor`). Nessun danno e il recupero non torna. Senza `dir` il getto sale, come sempre. Con l'avviso cominciano a volare foglie, poi righe di vento.
  - Con `idle` (solo grafica, #288) è una fontana: a riposo uno zampillo alto `idle` pixel, con l'avviso cresce e gorgoglia, poi parte il getto alto, che ricade a ventaglio.
  - La colonna parte da `y` e sale per `height`.
  - Dopo la calma ci sono le **bolle** (`warnMs`), poi il **getto** (`activeMs`): chi è nella colonna viene spinto in alto a `speed` pixel/s, senza danno, e può di nuovo usare il recupero.
- **`itemSpots`**, zone dove gli oggetti cadono più spesso: `{ x, y, width, weight }`. Si sceglie a caso tra i pezzi larghi almeno 80 px (peso 1) e le zone (il loro peso). Senza zone, gli oggetti cadono come prima, con lo stesso seme.

```ts
jets: [{ x: 930, y: 690, width: 60, height: 300, speed: 1300, periodMs: 9000, warnMs: 1200, activeMs: 1500 }],
itemSpots: [{ x: 740, y: 690, width: 440, weight: 3 }],
```

### Pezzi a tempo (`on`): blocchi, piattaforme, trappole e getti che arrivano e se ne vanno (#433)

Ogni blocco pieno, piattaforma sottile, trappola e getto può avere `on: [[da, a], ...]`: finestre `[da, a)` del **tempo dell'arena** in ms, dall'inizio della partita (non a giro, a differenza di `on` delle piattaforme mobili). Fuori dalle finestre il pezzo non c'è: non ci si sta sopra, non si sbatte, non fa male e non spinge. Chi ci stava sopra cade, chi era appeso al suo spigolo si stacca. Senza `on` il pezzo c'è sempre.

- Godot lo disegna sfumando: compare negli ultimi 300 ms prima della finestra (un avviso) e sparisce negli ultimi 300 ms della finestra, quando ci si sta ancora sopra.
- Il controllo delle arene guarda le piattaforme all'inizio di ogni fase e a ogni bordo di finestra: in ogni momento ognuna deve essere raggiungibile dai pezzi che ci sono.
- Alla rivincita un'arena con pezzi a tempo o fasi riparte da 0 ms.

```ts
solids: [MAIN, { x: 900, y: 400, width: 200, height: 40, on: [[0, 60000]] }], // il tetto c'è solo nel primo minuto
```

### Fasi (`phases`): l'arena cambia durante la partita (#433)

`phases: [{ id, name, startMs, announce?, warnMs?, blastZone?, respawn?, camera? }, ...]`, in ordine di `startMs`, la prima da 0. La fase attiva è l'ultima già cominciata. Insieme ai pezzi a tempo si fa un'arena che cambia, come la Bologna di #433.

- **`blastZone`** e **`respawn`** della fase prendono il posto di quelli dell'arena finché dura (KO, ritorno in gioco, oggetti, proiettili, compagni).
- **`name`**, **`announce`** (la scritta all'arrivo), **`warnMs`** (quanto prima avvisare) e **`camera`** (come `camera` dell'arena) sono solo per il client.
- `id` è il nome stabile per il codice e i test.

```ts
phases: [
  { id: "piazza", name: "Piazza Maggiore", startMs: 0 },
  { id: "torri", name: "Le Due Torri", startMs: 60000, announce: "Si sale!", warnMs: 3000,
    blastZone: { left: -300, right: 1580, top: -900, bottom: 920 }, respawn: { x: 640, y: -200 } },
],
```

L'esempio completo è **Bologna** (`bologna` in `stages.ts`, #433): arena a squadre di 2200×2400 con quattro fasi (piazza, torri, crollo della Garisenda, zuffa sull'Asinelli) fatta di pezzi a tempo, trappole che viaggiano, raffiche e polvere che sale; i tempi sono in `BOLOGNA` (`constants.ts`) e `blinkWindows` scrive le finestre dei merli che lampeggiano.

#### La torre che crolla (`art.collapse`, #433)

Solo grafica, tutta da `stageMs`, senza niente in rete: tra i pezzi che spariscono (`on`) e la rampa che appare, Godot disegna una sagoma di torre di mattoni che ruota attorno al suo piede verso destra, con polvere alla base e all'impatto, mattoni che volano e scossa di telecamera. Prima, nell'avviso, compaiono le crepe e la sagoma trema appena.

```ts
art: { layers: [], collapse: { atMs: BOLOGNA.collapseMs, durationMs: BOLOGNA.collapseFallMs, pivot: { x: 830, y: 1940 }, height: 780, width: 260, toDeg: 62, warnMs: 6000 } }
```

| Campo | Cosa fa |
|---|---|
| `atMs`, `durationMs` | quando comincia la caduta e quanto dura (parte piano e finisce veloce); a `atMs + durationMs` appare la rampa vera |
| `pivot` | il piede attorno a cui ruota: l'angolo in basso a destra della torre |
| `width`, `height` | la sagoma: larga alla base, più stretta in cima |
| `toDeg` | di quanto ruota alla fine (positivo = verso destra, 90 = distesa); la cima deve arrivare dove si appoggia la rampa |
| `warnMs` | l'avviso prima di `atMs` (6000 se manca) |

### Musica (`music`)

Facoltativa: senza, in partita si sente la musica di sempre. È un preset per il sintetizzatore del gioco (`audio.gd`), più un brano registrato facoltativo.

| Campo | Cosa fa |
|---|---|
| `bpm` | velocità, tra `AUDIO.musicBpmMin` e `AUDIO.musicBpmMax` (in `constants.ts`) |
| `chords` | da 1 a 8 accordi per nome, uno per battuta: `"C"`, `"F#"`, `"Bb"`, con `m` se minore (`"Am"`) |
| `lead` | timbro della melodia: `"square"`, `"triangle"`, `"sawtooth"` o `"sine"` |
| `track` | facoltativo: un brano registrato, `public/assets/music/<track>.ogg`, che in partita suona al posto del sintetizzatore e ricomincia da capo quando finisce. Il preset resta come ripiego se il file non si carica |

```ts
music: { bpm: 108, chords: ["C", "Am", "F", "G"], lead: "triangle" } // Le Isole
music: { bpm: 116, chords: ["F", "Am", "Bb", "C"], lead: "triangle", track: "massima-tackenza" } // Padova, col brano registrato
```

Il brano registrato segue le regole di [voci.md](voci.md) (Ogg Vorbis 44,1 kHz stereo, circa -16 LUFS, `npm run audio:check`), con due differenze: pesa più di 500 KB (Padova, 2:55, ne pesa 1,9 MB; tutto l'audio del gioco resta sotto i 5 MB), e va tagliato in modo che la fine si attacchi bene all'inizio, perché il giro riparte dal primo campione.

### Sfondo a strati (`art`)

Facoltativo: senza, l'arena si disegna con i colori di `colors`. I PNG vanno in `public/assets/stages/<id>/` e arrivano a Godot con `npm run export:godot`, che si ferma se ne manca uno. Le regole di stile (fondale più spento dei lottatori, bordo calpestabile chiaro) sono nella sezione 7 di [stile-grafico.md](stile-grafico.md).

| Campo | Cosa fa |
|---|---|
| `layers` | gli strati dietro al palco, dal più lontano: `{ file, parallax }` |
| `parallax` | da 0 (fermo con la telecamera, lontanissimo) a 1 (si muove con il palco) |
| `verticalParallax` | quanto vale la parallasse in verticale, per strati e sfondo vivo (#400): 1 se manca, 0 = in verticale tutto resta attaccato al palco. Con gli strati che hanno il terreno disegnato (strade, prati) conviene 0: altrimenti quando la telecamera sale si aprono vuoti tra uno strato e l'altro |
| `foreground` | facoltativo, uno strato davanti ai lottatori: quasi tutto trasparente |
| `preview` | immagine 16:9 dell'arena per la lobby; la lobby ci disegna sopra i pezzi del palco |
| `previewFull` | `true` se l'anteprima mostra già il palco (per esempio fotografata dal gioco): la lobby non ci disegna sopra i pezzi (#284) |
| `scale` | pixel di mondo per pixel dell'immagine (1 se manca) |
| `dir` | cartella in `public/assets/stages/` se diversa dall'id dell'arena: le arene casuali usano tutte `generica` |

Gli strati sono centrati sul centro dell'arena. Con la telecamera più lontana (`CAMERA.minZoom`) si vedono circa 1830×1030 pixel di mondo: uno strato di 1920×1080 copre tutto se è lontano; gli strati vicini sfumano ai lati nel colore `sky`. In tutto al massimo 4 MB per arena (lo controlla `npm test`).

```ts
art: { layers: [{ file: "sfondo-0.png", parallax: 0.15 }, { file: "sfondo-1.png", parallax: 0.45 }, { file: "sfondo-2.png", parallax: 0.75 }], preview: "anteprima.png" } // Il Palco
```

### Materiali, ringhiere e decorazioni (`art.skins`, `art.props`)

Facoltativi, solo grafica: senza, blocchi e piattaforme si disegnano a tinta unita con `colors`. I PNG stanno nella cartella dell'arena come gli strati, e `npm run export:godot` si ferma se ne manca uno. Contano nei 4 MB per arena.

| Campo di `art` | Cosa fa |
|---|---|
| `skins` | materiali per nome: `{ file, edge?, depth?, rails? }` |
| `solidSkin`, `platformSkin` | il materiale di base di blocchi e piattaforme sottili |
| `pieces` | eccezioni per indice: `{ solids: [...], platforms: [...] }`; `null` = tinta unita |
| `props` | decorazioni ferme: `{ file, x, y, scale?, flip?, front?, opacity? }`, con i piedi (centro del lato basso) in `x, y` |

- **Materiale (`skins`):**
  - `file` si ripete: nei blocchi in orizzontale e in verticale; nelle piattaforme lungo la superficie, anche ad arco e inclinate, con lo spessore `depth` (12 se manca);
  - nelle scale, ogni gradino è un blocco del materiale;
  - `edge` è la striscia del bordo calpestabile, ripetuta sopra: deve restare **chiara** (style guide, sezione 7).
- **Ringhiere (`rails`):** `{ file, height, offsetY?, front?, opacity? }`, ripetute lungo la superficie della piattaforma.
  - Quella dietro sta in piedi sul piano.
  - Quella davanti (`front: true`) si tiene bassa e trasparente (`opacity` circa 0,45) per non coprire chi ci passa.
- **Decorazioni (`props`):** stanno dietro al palco, così una lastra retta da una statua le sta sopra, oppure davanti ai lottatori con `front: true`. `scale` vale per la singola immagine: per un disegno a 2x si mette 0,5.
- **Grandezza:** `art.scale` vale per strati e materiali: pixel di mondo per pixel dell'immagine.
- **Disegnare col codice (#280):** `tools/arene/disegno.py` ha la tela di Padova. Si disegna in pixel di mondo, il file esce a 2x (`art.scale: 0.5`) ed è disegnato a 4x e poi ridotto, per avere i bordi lisci.
  - Ci sono l'inchiostro, le ombre a 2 toni, i blocchi di pietra e le velature.
  - Con `wrap` la tela fa una piastrella che si ripete senza giunte.
  - `tools/arene/padova.py` è l'esempio da copiare per una nuova arena.
- **Disegni più ricchi (#288):** `tools/arene/pittura.py` è il motore pittorico. Le forme nascono da maschere unite e lisciate, quindi contorni organici e niente cerchi o rettangoli in vista. Ombre e luci morbide si calcolano dalla sagoma spostata verso la luce. Poi l'inchiostro attorno e la grana a pennello. `tools/arene/vita.py` lo usa per lo sfondo vivo.

```ts
art: {
  layers: [/* ... */],
  skins: {
    pietra: { file: "pietra.png", edge: "bordo.png" },
    ponte: { file: "ponte.png", depth: 20, rails: [
      { file: "balaustra.png", height: 36, offsetY: 2 },
      { file: "balaustra.png", height: 28, offsetY: 12, front: true, opacity: 0.45 },
    ] },
  },
  solidSkin: "pietra",
  pieces: { platforms: ["ponte"] },
  props: [{ file: "statua-ponte.png", x: 690, y: 522, scale: 0.5 }],
}
```

### Sfondo vivo (`art.life`)

Facoltativo, solo grafica: elementi animati che fanno sembrare il posto abitato. Il client Godot li calcola dal tempo dell'arena e dalle posizioni dei lottatori (`godot/scripts/stage_life.gd`): non passa niente in rete. Ogni elemento ha una `parallax`, come gli strati, e si disegna dietro agli strati più vicini di lui: il tram passa dietro gli alberi del prato, i passanti camminano sul vialetto.

| Campo di `life` | Cosa fa |
|---|---|
| `birds: { y, parallax, everyMs }` | uno stormo a V attraversa il cielo all'altezza `y`, ogni `everyMs`, un giro da sinistra e uno da destra |
| `pigeons: [{ x, y }]` | piccioni posati (sulle statue, sui cornicioni): scappano quando un lottatore arriva vicino o passa il ciclista, e tornano dopo 7 s |
| `walkers: { y, parallax, count, umbrellas? }` | `count` passanti sulla linea `y`, di tanti tipi (#278): chi passeggia, chi porta il cane, chi corre, il passeggino, l'anziano col bastone, lo studente con la corona d'alloro, chi torna dal mercato. Con `umbrellas` quando piove (acqua alta) quasi tutti aprono l'ombrello, gli altri si coprono col giornale |
| `vehicles: { y, parallax, everyMs, kind }` | un tram o un bus (`kind`) che passa in 12 s, ogni `everyMs` (più di 12000) |
| `traffic: { y, parallax, everyMs, kinds }` | il traffico (#278): ogni `everyMs` (almeno 1000) parte un veicolo di uno dei `kinds` (`auto`, `vespa`, `furgone`, `bici`, `bus`; un tipo ripetuto passa più spesso), nei due versi su due corsie, ognuno alla sua velocità, su una strada con il marciapiede. Di sera fari e luci di dietro. Mettilo dove si vede: più giù il palco lo copre |
| `flyers: { y, parallax, count }` | `count` uccelli vicini da `y` in giù (#278): rondini che sfrecciano di giorno, pipistrelli di notte (servono `daycycle`) |
| `planes: { y, everyMs }` | un aereo lontanissimo che attraversa il cielo in 40 s ogni `everyMs` (più di 40000): la scia di giorno, le luci che lampeggiano di notte |
| `bar: { x, y, parallax, tables, spacing }` | i tavolini di un bar (#278), da `x` verso destra ogni `spacing`: due persone per tavolino che bevono lo spritz e ogni tanto brindano, gli ombrelloni, il cameriere col vassoio e di sera le lucine |
| `daycycle.lightLayers: [{ file, parallax }]`, `daycycle.lightProps: [{ file, x, y, scale? }]` | luci della notte precise (#288): immagini con solo i vetri accesi, grandi e messe come lo strato (stessa `parallax`) o come la decorazione che illuminano. Si accendono al tramonto, senza la luce ambiente. Padova le genera insieme ai disegni (`*-luci.png`). I lampioni (`lamps`) si disegnano subito dopo il loro strato: alone, cono di luce e pozza a terra |
| Luce del sole e della luna (#288) | nelle arene con `daycycle`, ombre a terra di lottatori e decorazioni, lunghe al tramonto, dalla parte opposta all'astro, e una luce calda (fredda di notte) dal suo lato (`godot/scripts/sun_light.gd`) |
| `sheets: { nome: { file, frames, scale? } }` | fogli di fotogrammi dipinti (#288) al posto delle forme semplici: `nuvole` (una nuvola per fotogramma, colorata dalla luce del momento), `gabbiano` (lo stormo), `rondine` e `pipistrello` (gli uccelli vicini), `piccione` (2 fotogrammi fermo, 4 in volo); `passanti` (una riga per tipo, `rows`), `ombrelli`; `bar-tavolo`, `bar-seduti` (pose: sul tavolo, a metà, alla bocca, brindisi), `cameriere`; `auto` e `furgone` (un modello per fotogramma), `vespa`, `bici`, `bus`, `tram`; `zampillo` e `getto` per la fontana (un getto con `idle`). A 2x, rivolti a destra. Padova li dipinge con `tools/arene/vita.py`, sul motore pittorico `tools/arene/pittura.py`: sagome lisciate, ombre e luci morbide, grana a pennello |
| `rain: { periodMs, rainMs, offsetMs? }` | pioggia solo grafica (#288): ogni `periodMs` piove per `rainMs`, senza trappole; i passanti aprono l'ombrello |
| `outerWater: { y, highY?, flood? }` | acqua intorno all'arena, da `y` in giù, disegnata davanti a chi cade, con lo splash. Con `flood` (indice di una trappola con l'acqua alta) sale fino a `highY` insieme a lei. Le rive possono scendere fino all'acqua: l'arena non sembra sospesa nel vuoto |
| `daycycle: { cycleMs, startAt?, lamps? }` | giorno e notte: un giro intero in `cycleMs` dall'inizio della partita, partendo da `startAt` (0 mezzogiorno, 0,25 tramonto, 0,5 mezzanotte, 0,75 alba). Di notte si vedono le stelle; i lampioni `{ x, y, parallax }` si accendono al tramonto e si spengono all'alba, le finestre `windows: [{ x, y, width, height }]` si accendono una alla volta. Con `sky: true` il cielo è vivo (#267): gradiente con i colori del momento (alba rosa, giorno azzurro, tramonto arancio e viola, notte blu), sole e luna che tramontano dietro gli strati, stelle e nuvole che scorrono; lo strato più lontano allora va disegnato con il cielo trasparente, solo le sagome. La luce del momento moltiplica strati, decorazioni, acqua e sfondo vivo, il palco solo un po' |

Colori spenti, lontani da quelli dei giocatori (style guide, sezione 7). Quello che sta fuori dall'inquadratura non si disegna, ma ogni elemento costa qualche centinaio di µs per frame: dopo averne aggiunti, controlla con `npm run bench:godot`.

## Come funzionano dentro (per chi aggiunge un elemento)

- Ascensori e trappole dipendono solo dal **tempo dell'arena** (`ctx.timeMs`, che `stepWorld` fa avanzare). Il server lo manda nello snapshot (`stageMs`) e Godot rifà gli stessi calcoli (`mover_position` e `hazard_active` in `world_view.gd`): niente posizioni in rete, e il movimento è fluido perché si interpola il tempo.
- Un elemento nuovo segue lo stesso schema: dati opzionali in `StageSpec`, logica pura in `src/shared/physics/elements.ts` con test in `elements.test.ts`, disegno in `_draw_elements` di `world_view.gd`, anteprima in `stage_preview.gd`.
- Pezzi a tempo e fasi (#433): ogni tick `stepWorld` mette in `ctx.stage` la vista di `stageAt` (`physics/timed.ts`), con solo i blocchi e le piattaforme che ci sono e le zone della fase. Così chi legge `ctx.stage.solids` o `blastZone` non cambia. Trappole, getti e piattaforme mobili restano tutti, perché eventi e disegni li chiamano per indice: chi li usa salta quelli spenti con `pieceOn`. La predizione e il disegno rifanno lo stesso conto con `piece_on` (`predict/movement.gd`) dal `stageMs` dello snapshot. Un'arena che non cambia resta lo stesso oggetto.
- Se l'elemento dipende da cosa fanno i giocatori (un pavimento che crolla quando ci stai sopra) il client non lo può ricalcolare dal tempo: il suo stato va nello snapshot, ed è un cambio di protocollo.
