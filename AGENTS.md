# AGENTS.md

Istruzioni per gli agenti AI (Claude Code, Codex, Cursor, Copilot, Gemini, ...) che lavorano su **bonobo-game**, un picchiaduro multiplayer online.
**Il gioco ufficiale è il client Godot in `godot/`** (decisione di Nicola, 6 ottobre 2026): ogni lavoro e ogni decisione nuova si fa in funzione di Godot. Il server Node resta l'arbitro e la logica resta in `src/shared/`; il vecchio client web in `src/client/` è congelato.
Questo file è l'unica fonte di verità per gli agenti: `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md` e `.cursor/rules/` rimandano qui.
Per il gioco leggi il [README](README.md), per il giro di lavoro degli umani [CONTRIBUTING.md](CONTRIBUTING.md).
**Obiettivo attuale: un prodotto professionale, in fase precoce** (Nicola, 6 ottobre 2026). Il piano è in [docs/piano-prodotto.md](docs/piano-prodotto.md): 15 evolutive `E1`...`E15` in due ondate, ognuna un'issue con la specifica in `docs/evolutive/`. Provare dev'essere facilissimo e il deploy snello: niente processi pesanti.
Il giro di lavoro passo per passo, con i comandi, è in [.claude/skills/compito/SKILL.md](.claude/skills/compito/SKILL.md): Claude Code lo carica da solo (`/compito`), **ogni altro agente lo legge all'inizio di un compito**.

Siamo un gruppo di amici e ognuno usa il proprio agente, spesso nello stesso momento sulla stessa repo. Gran parte delle regole qui sotto serve a non pestarsi i piedi.

## Git è il modo in cui gli agenti si parlano

Gli agenti non si vedono tra loro: vedono solo quello che è su GitHub. Quindi:

1. **Prima dichiara, poi lavora.** Prima di scrivere codice, crea (o prendi) l'issue e apri una **PR in bozza** con il piano: cosa farai e quali file toccherai. Il primo push è il piano, non il codice.
2. **Pusha presto e spesso.** Ogni passo che compila va pushato subito sul tuo branch, almeno ogni 30 minuti di lavoro. Lavoro non pushato è invisibile agli altri e genera conflitti.
3. **Leggi prima di toccare.** All'inizio e prima di ogni push fai `git fetch origin` e guarda `gh pr list`: se un'altra PR aperta tocca i tuoi stessi file, coordinati (commenta la sua PR o avvisa il tuo umano).
4. **Aggiorna il piano** nella descrizione della PR se cambi strada, così chi legge sa a che punto sei.
5. **Riprendi prima di iniziare.** A inizio sessione guarda se hai già una PR aperta (`gh pr list --author @me`): finiscila, leggendo commenti e review, prima di prendere altro.

Senza `gh` (Cursor, agenti cloud, ...) fai le stesse letture e scritture con gli strumenti GitHub che hai: i passi non si saltano.

## Scegliere un compito

Se il tuo umano ti dice "trova qualcosa da fare" (o ti dà un'issue), segui questi passi:

1. **Leggi la roadmap**, l'issue con l'etichetta `roadmap` (`gh issue list --label roadmap`). La sua tabella divide il lavoro in **corsie**: ogni corsia ha i suoi file, così più agenti lavorano insieme senza conflitti. Poi leggi [docs/piano-prodotto.md](docs/piano-prodotto.md): le evolutive (titoli che iniziano con `E1 ·`, `E2 ·`...) hanno la precedenza, nell'ordine consigliato lì, e la loro specifica completa è in `docs/evolutive/E<n>.md`.
2. **Scegli un'issue `pronto`** (`gh issue list --label pronto`). Le issue `in attesa` dipendono da un'altra non ancora mergiata: non iniziarle. Se la dipendenza scritta nel loro blocco "Per gli agenti" è già in `main`, sposta l'issue a `pronto` (`gh issue edit N --remove-label "in attesa" --add-label pronto`). Preferisci `good first issue` se il tuo umano è alle prime armi, e le etichette del suo ruolo (`arte`, `audio`, `codice`, `design`).
3. **Controlla che sia libera**: nessun assegnatario e nessuna PR aperta nella stessa corsia (`gh pr list`). Se la corsia è occupata, scegline un'altra.
4. **Prendila**: `gh issue edit N --add-assignee @me`, un commento sull'issue tipo "prendo il passo 2", poi branch e PR in bozza come in "Workflow Git". Subito dopo rileggi l'issue: se un altro l'ha presa prima di te (assegnazione o commento precedente al tuo), vince chi è arrivato prima; togli l'assegnazione e scegline un'altra.
5. **Le issue `sviluppo` sono grandi**: fai **un passo per PR**, nell'ordine dei "Passi". Nella PR scrivi `Parte di #N`, non `Closes #N`, finché non è l'ultimo passo.
6. **Resta nei file della tua corsia** (blocco "Per gli agenti" nell'issue). Se serve toccarne un altro, scrivilo nella PR in bozza prima di farlo.
7. **Se ti fermi**, togli l'assegnazione e lascia un commento su dove sei arrivato, così un altro agente può riprendere.
8. **Issue abbandonate:** se un'issue è assegnata ma da 3 giorni non c'è nessun push né commento, chiedi nell'issue "posso prenderla?" taggando l'assegnatario. Senza risposta entro un giorno puoi prenderla, ripartendo dal suo branch se esiste.

Le decisioni di design non scritte nell'issue (valori, tasti, nomi) le scegli tu come dice "Coordinazione tra agenti": un valore ragionevole in `constants.ts` e una riga nella PR.

**Arene ed elementi nuovi** arrivano dai moduli "Arena nuova" ed "Elemento nuovo" (etichetta `arena`): come tradurli in dati e codice è in [docs/arene.md](docs/arene.md).

## Il gioco deve somigliare a noi

Bonobo Game non è un picchiaduro qualunque: è il gioco del nostro canale Discord. Nomi, mosse, arene, oggetti, frasi, suoni e titoli sono occasioni per metterci dentro le persone, le battute e i ricordi del gruppo.

- **Prima di inventare, chiedi.** Quando un contenuto non è deciso nell'issue, chiedi al tuo umano se c'è un tormentone, un ricordo o una persona del canale che ci starebbe bene. Se non lo sa, prepara una domanda per il gruppo.
- **Domande al canale:** chiuse, come sondaggio (`npm run discord -- poll "..." "A" "B"`, vedi `docs/discord.md`, solo se il tuo umano è d'accordo). Le domande aperte vanno in un commento sull'issue, con il link postato sul Discord. Metti sempre la domanda nella PR, sezione "Da chiedere al canale".
- **Non bloccarti:** intanto usa un valore provvisorio con un commento `// TODO community: ...` e vai avanti.
- **Dai il merito:** se un'idea, una battuta o una voce viene da un membro, scrivilo nella PR e aggiungilo ai crediti (#24).
- **Con rispetto:** nomi, voci, foto e battute su una persona entrano nel gioco solo se quella persona è d'accordo.

## Comandi

```bash
npm install          # Node 22 consigliato (i test usano i pattern di node --test)
npm run dev          # server di gioco (:3000), più il vecchio client web (:5173) che serve solo a confronto
npm run typecheck    # tsc --noEmit: deve passare prima di ogni push
npm test             # test della logica pura in src/shared (*.test.ts): devono passare prima di ogni push
npm run build        # build del vecchio client in dist/: deve passare prima di ogni push
npm run export:godot # rigenera godot/data (game.json e sprite) da src/shared e public/assets
npm start            # versione di produzione sulla porta 3000

godot --headless --path godot --import            # Godot 4.5.1: carica il progetto
godot --headless --path godot --quit-after 60     # nessun "SCRIPT ERROR" = gli script si caricano
```

Per provare il multiplayer, con `npm run dev` acceso apri `godot/project.godot` in Godot 4.5 e premi F5 in due istanze (menu Debug, più istanze), oppure da terminale `godot --path godot -- --room=test --name=A` due volte. Se aggiungi o cambi logica in `src/shared/`, aggiungi un test accanto al file (`nome.test.ts`, runner di Node) e rilancia `npm run export:godot`. La CI (`.github/workflows/ci.yml`) lancia typecheck, test, build, il controllo di `godot/data` e il caricamento degli script Godot su ogni PR.

## Struttura

```
godot/             IL GIOCO UFFICIALE: client Godot 4.5 (GDScript), manda i tasti e disegna gli snapshot
  scripts/main.gd    collegamento, tasti → InputState, telecamera, apre lobby e menu
  scripts/world_view.gd   arena, lottatori e sprite, scintille, scossa    hud.gd  schede, tempo, fine partita
  scripts/lobby.gd   lobby (stage_preview.gd anteprime)    audio.gd + synth.gd  effetti e musica sintetizzati
  scripts/options.gd settings.gd pause_menu.gd ui.gd   opzioni, preferenze e tasti salvati, menu Esc, tema
  scripts/socket_io.gd snapshot_buffer.gd   Socket.IO su WebSocket, interpolazione
  data/              GENERATO da npm run export:godot: non si modifica a mano
src/shared/        codice comune a server e client
  constants.ts       TUTTI i numeri del gioco (velocità, salto, danni, hitbox, tick rate, audio)
  types.ts           PROTOCOLLO Socket.IO, PlayerState, GameSnapshot e GameEvent (hit, ko, jump...)
  physics/           logica pura, niente rete né grafica: fighter, movement, attacks, stage, index (stepWorld)
  characters.ts      personaggi    stages.ts  arene    stageGenerator.ts  arene casuali da un seme
  rules.ts           regole della partita (MatchRules), chi vince    items.ts  oggetti (#17)
src/server/        Express + Socket.IO. index.ts gestisce le stanze, Room.ts fa girare la partita (ganci per bot e Discord)
src/client/        vecchio client Phaser: CONGELATO, solo correzioni, niente funzioni nuove
public/assets/     immagini e suoni (arrivano in Godot con npm run export:godot), crediti in CREDITS.md
```

## Architettura: regole che non si rompono

- **Godot è l'unico client ufficiale.** Tutto quello che si vede o si sente (grafica, effetti, suoni, menu, telecamera) si fa in `godot/`. In `src/client/` solo correzioni.
- **Il server è l'arbitro.** Il client manda solo `InputState` (tasti premuti) e disegna gli snapshot che riceve. Posizioni, colpi, danni e KO si calcolano in `src/shared/physics/`, eseguito dal server. Non aggiungere mai un evento in cui il client dice "ho colpito" o "sono qui".
- **`physics/` resta puro e deterministico**: niente import da `socket.io`, `phaser`, `express` o dal DOM, niente `Math.random` né orologi, così un giorno potrà girare anche nel client per la predizione.
- **Effetti, suoni, telecamera e Discord ascoltano gli eventi** (`GameEvent` nello snapshot, prodotti dalla fisica): non leggono né cambiano lo stato della fisica. Un nuovo tipo di evento è un cambio di protocollo.
- **I numeri vanno in `constants.ts`**, con un nome e un commento sull'unità (pixel/s, ms). Niente valori magici sparsi nel codice.
- **Il protocollo è un contratto condiviso.** `types.ts` (eventi Socket.IO e forma di `PlayerState`/`GameSnapshot`) si cambia solo in una PR che lo dichiara nel titolo (es. `Protocollo: aggiunge l'evento chat`) e che aggiorna server e client Godot insieme.

## Workflow Git (obbligatorio)

1. **Mai committare o pushare su `main`.** `main` deve essere sempre giocabile.
2. **Un compito = un'issue = un branch = una PR.** Se l'issue non c'è, chiedi al tuo umano di crearla o creala tu con `gh issue create`.
3. **Branch:** `<nome-umano>/<cosa-fai>` in minuscolo, es. `luca/calcio`, `marta/fix-salto-doppio`. Se il tuo ambiente impone un nome (agenti cloud: `claude/...`, `codex/...`), usa quello e scrivi il nome dell'umano nella PR.
4. **Prima di scrivere codice:**
   - `git fetch origin && git switch -c <branch> origin/main`
   - `gh pr list` e `gh issue list`: se qualcun altro sta già lavorando sugli stessi file o sulla stessa funzione, fermati e avvisa il tuo umano invece di duplicare il lavoro.
5. **Apri subito una PR in bozza, prima del codice:** un commit vuoto con il piano (`git commit --allow-empty -m "Piano: <cosa>"`), push, poi `gh pr create --draft` con `Closes #N`, il piano e i file che toccherai. La bozza è il segnale "ci sto lavorando io" per gli altri agenti.
6. **Commit** piccoli, con messaggi brevi all'imperativo, in italiano: `Aggiunge il calcio con il tasto K`, `Corregge il doppio salto`.
7. **Resta aggiornato:** prima di togliere la bozza fai `git fetch origin && git rebase origin/main`. Sul tuo branch puoi usare `git push --force-with-lease`; non riscrivere mai la storia di branch altrui.
8. **PR piccole:** idealmente meno di ~400 righe cambiate. Una funzione grande si spezza in più PR che lasciano `main` funzionante.
9. **Merge:** chi apre la PR la unisce da solo (squash merge) appena la CI è verde e la PR non è più in bozza, senza aspettare la review di un altro (decisione di Nicola, 6 ottobre 2026). Prima di unire controlla che non ci siano conflitti con `main` né commenti di review ancora aperti. Se vuoi un parere, chiedilo pure (`gh pr edit N --add-reviewer <login>` o sul Discord), ma non è obbligatorio.

## Coordinazione tra agenti

- **Resta nel perimetro del compito.** Niente refactor "già che ci sono", riformattazioni di file che non tocchi, rinomine di massa o cambi di configurazione (`tsconfig.json`, `vite.config.ts`): creano conflitti nelle PR degli altri. Se vedi qualcosa da sistemare, apri un'issue.
- **File caldi:** `constants.ts`, `types.ts`, `godot/scripts/main.gd` e `world_view.gd` li toccano quasi tutti. Aggiungi righe, non riordinare quelle esistenti.
- **Dipendenze:** aggiungi un pacchetto npm solo se serve davvero e spiega perché nella PR. `package-lock.json` si cambia solo con `npm install`, mai a mano; in caso di conflitto rigeneralo con `npm install` dopo il rebase.
- **File di coordinamento** (`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `CONTRIBUTING.md`, `.github/`, `.cursor/`, `.claude/`): si cambiano in una PR dedicata, mai insieme a codice di gioco.
- **Decisioni di game design** (danni, velocità, nuove mosse, comandi): se il compito non le specifica, scegli un valore ragionevole, mettilo in `constants.ts` e scrivilo nella PR perché il gruppo possa discuterlo.
- **Se sei bloccato o il compito è ambiguo**, chiedi al tuo umano o commenta l'issue invece di indovinare.
- **Condividi quello che impari.** Una trappola o una convenzione che farebbe sbagliare anche il prossimo agente diventa una riga in questo file, in una PR dedicata. Le note personali restano nei file locali del tuo agente.

## Stile del codice

- TypeScript `strict`, moduli ES. Niente `any` se non con un commento che spiega perché.
- Nomi di variabili, funzioni e tipi in inglese; commenti in italiano, brevi, che spiegano il *perché*.
- Segui lo stile del file che stai modificando.
- Usa i tipi in `types.ts` per gli eventi Socket.IO (`Server<ClientToServer, ServerToClient>`), mai stringhe non tipizzate.
- GDScript: tab, nomi in inglese in `snake_case`, tipi espliciti. Con `:=` su un valore letto da un `Dictionary` Godot dà "Cannot infer the type": scrivi il tipo (`var x: float = d.x`).
- Un `Control` già aggiunto alla scena si allarga a tutto lo schermo con `set_anchors_and_offsets_preset(...)`: `set_anchors_preset` da solo lo lascia grande zero.

## Asset

- Solo asset fatti da noi o con licenza libera (CC0, CC-BY, ...). Annota fonte, autore e licenza in `public/assets/CREDITS.md`.
- File singoli oltre i 5 MB solo dopo averne parlato con il gruppo.

## Mai

- Committare segreti, token, `.env`, `node_modules/` o `dist/`.
- Pushare su `main`, fare force-push su branch altrui, unire una PR con la CI rossa o ancora in bozza.
- Disattivare controlli (`// @ts-ignore`, `strict: false`) per far passare il typecheck.
- Spostare logica di gioco nel client.
- Modificare il README se il compito non lo richiede.

## Prima di dire "fatto"

1. `npm run typecheck`, `npm test` e `npm run build` passano, e il controllo CI della PR è verde.
2. Il *Fatto quando* del passo che hai fatto (scritto nell'issue) è verificato, e nella PR dici come.
3. Gli script Godot si caricano senza `SCRIPT ERROR` e, se la modifica tocca il gioco, l'hai provata nel client Godot con due istanze.
4. La PR usa il template e dice quale agente ha scritto il codice e come l'hai provata.
