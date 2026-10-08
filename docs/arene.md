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

### Trappola (`hazards`): spuntoni, fuoco, laser

Un rettangolo che, quando è acceso, aggiunge percentuale e lancia via chi lo tocca (come un colpo). Il KO va a chi ti ci ha spinto. Dopo una trappola si è al sicuro per `HAZARD.cooldownMs` (in `constants.ts`).

| Campo | Cosa fa |
|---|---|
| `x`, `y`, `width`, `height` | il rettangolo che fa male |
| `kind` | come si disegna: `"spuntoni"`, `"fuoco"`, altrimenti un rettangolo rosso |
| `damage` | percentuale aggiunta |
| `knockback`, `knockbackGrowth` | lancio di base (pixel/s) e quanto cresce per ogni punto di percentuale |
| `angleDeg` | direzione: 90 dritto in alto, meno di 90 in diagonale lontano dal centro della trappola |
| `periodMs`, `activeMs`, `offsetMs` | se c'è `periodMs`, si accende per `activeMs` a ogni giro |

```ts
{ kind: "fuoco", x: 440, y: 610, width: 400, height: 30, damage: 8, knockback: 600, knockbackGrowth: 4, angleDeg: 80, periodMs: 4000, activeMs: 1500 }
```

### Musica (`music`)

Facoltativa: senza, in partita si sente la musica di sempre. È un preset per il sintetizzatore del gioco (`audio.gd`), non un file.

| Campo | Cosa fa |
|---|---|
| `bpm` | velocità, tra `AUDIO.musicBpmMin` e `AUDIO.musicBpmMax` (in `constants.ts`) |
| `chords` | da 1 a 8 accordi per nome, uno per battuta: `"C"`, `"F#"`, `"Bb"`, con `m` se minore (`"Am"`) |
| `lead` | timbro della melodia: `"square"`, `"triangle"`, `"sawtooth"` o `"sine"` |

```ts
music: { bpm: 108, chords: ["C", "Am", "F", "G"], lead: "triangle" } // Le Isole
```

## Come funzionano dentro (per chi aggiunge un elemento)

- Ascensori e trappole dipendono solo dal **tempo dell'arena** (`ctx.timeMs`, che `stepWorld` fa avanzare). Il server lo manda nello snapshot (`stageMs`) e Godot rifà gli stessi calcoli (`mover_position` e `hazard_active` in `world_view.gd`): niente posizioni in rete, e il movimento è fluido perché si interpola il tempo.
- Un elemento nuovo segue lo stesso schema: dati opzionali in `StageSpec`, logica pura in `src/shared/physics/elements.ts` con test in `elements.test.ts`, disegno in `_draw_elements` di `world_view.gd`, anteprima in `stage_preview.gd`.
- Se l'elemento dipende da cosa fanno i giocatori (un pavimento che crolla quando ci stai sopra) il client non lo può ricalcolare dal tempo: il suo stato va nello snapshot, ed è un cambio di protocollo.
