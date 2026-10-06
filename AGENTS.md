# AGENTS.md

Istruzioni per gli agenti AI (Claude Code, Codex, Cursor, Copilot, Gemini, ...) che lavorano su **bonobo-game**, un picchiaduro multiplayer online nel browser.
Questo file è l'unica fonte di verità per gli agenti: `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md` e `.cursor/rules/` rimandano qui.
Per il gioco leggi il [README](README.md), per il giro di lavoro degli umani [CONTRIBUTING.md](CONTRIBUTING.md).
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

1. **Leggi la roadmap**, l'issue con l'etichetta `roadmap` (`gh issue list --label roadmap`). La sua tabella divide il lavoro in **corsie**: ogni corsia ha i suoi file, così più agenti lavorano insieme senza conflitti.
2. **Scegli un'issue `pronto`** (`gh issue list --label pronto`). Le issue `in attesa` dipendono da un'altra non ancora mergiata: non iniziarle. Se la dipendenza scritta nel loro blocco "Per gli agenti" è già in `main`, sposta l'issue a `pronto` (`gh issue edit N --remove-label "in attesa" --add-label pronto`). Preferisci `good first issue` se il tuo umano è alle prime armi, e le etichette del suo ruolo (`arte`, `audio`, `codice`, `design`).
3. **Controlla che sia libera**: nessun assegnatario e nessuna PR aperta nella stessa corsia (`gh pr list`). Se la corsia è occupata, scegline un'altra.
4. **Prendila**: `gh issue edit N --add-assignee @me`, un commento sull'issue tipo "prendo il passo 2", poi branch e PR in bozza come in "Workflow Git". Subito dopo rileggi l'issue: se un altro l'ha presa prima di te (assegnazione o commento precedente al tuo), vince chi è arrivato prima; togli l'assegnazione e scegline un'altra.
5. **Le issue `sviluppo` sono grandi**: fai **un passo per PR**, nell'ordine dei "Passi". Nella PR scrivi `Parte di #N`, non `Closes #N`, finché non è l'ultimo passo.
6. **Resta nei file della tua corsia** (blocco "Per gli agenti" nell'issue). Se serve toccarne un altro, scrivilo nella PR in bozza prima di farlo.
7. **Se ti fermi**, togli l'assegnazione e lascia un commento su dove sei arrivato, così un altro agente può riprendere.
8. **Issue abbandonate:** se un'issue è assegnata ma da 3 giorni non c'è nessun push né commento, chiedi nell'issue "posso prenderla?" taggando l'assegnatario. Senza risposta entro un giorno puoi prenderla, ripartendo dal suo branch se esiste.

Le decisioni di design non scritte nell'issue (valori, tasti, nomi) le scegli tu come dice "Coordinazione tra agenti": un valore ragionevole in `constants.ts` e una riga nella PR.

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
npm run dev          # server di gioco (:3000) + client Vite (:5173) insieme
npm run typecheck    # tsc --noEmit: deve passare prima di ogni push
npm test             # test della logica pura in src/shared (*.test.ts): devono passare prima di ogni push
npm run build        # build del client in dist/: deve passare prima di ogni push
npm start            # versione di produzione sulla porta 3000
```

Per provare il multiplayer apri `http://localhost:5173` (lobby) o `http://localhost:5173/?room=test&name=A` (entra subito) in due finestre. Se aggiungi o cambi logica in `src/shared/`, aggiungi un test accanto al file (`nome.test.ts`, runner di Node). La CI (`.github/workflows/ci.yml`) lancia typecheck, test e build su ogni PR.

## Struttura

```
src/shared/        codice comune a server e client
  constants.ts       TUTTI i numeri del gioco (velocità, salto, danni, hitbox, tick rate, audio)
  types.ts           PROTOCOLLO Socket.IO, PlayerState, GameSnapshot e GameEvent (hit, ko, jump...)
  physics/           logica pura, niente rete né grafica: fighter, movement, attacks, stage, index (stepWorld)
  characters.ts      personaggi    stages.ts  arene    stageGenerator.ts  arene casuali da un seme
  rules.ts           regole della partita (MatchRules), chi vince    items.ts  oggetti (#17)
src/server/        Express + Socket.IO. index.ts gestisce le stanze, Room.ts fa girare la partita (ganci per bot e Discord)
src/client/        Phaser + menu in HTML
  LobbyScene.ts      lobby: nome, stanza, lottatore, arena, regole
  GameScene.ts       regista della partita: passa snapshot ed eventi ai moduli di render/
  render/            stage, fighters, hud, results, effects, camera, audio: uno per corsia
  audio/             motore Web Audio, effetti sintetizzati (sfx.ts) e musica
  input.ts settings.ts OptionsPanel.ts PauseMenu.ts   tasti, preferenze salvate, opzioni, menu Esc
public/assets/     immagini e suoni, crediti in CREDITS.md
```

## Architettura: regole che non si rompono

- **Il server è l'arbitro.** Il client manda solo `InputState` (tasti premuti) e disegna gli snapshot che riceve. Posizioni, colpi, danni e KO si calcolano in `src/shared/physics/`, eseguito dal server. Non aggiungere mai un evento in cui il client dice "ho colpito" o "sono qui".
- **`physics/` resta puro e deterministico**: niente import da `socket.io`, `phaser`, `express` o dal DOM, niente `Math.random` né orologi, così potrà girare anche nel browser per la predizione.
- **Effetti, suoni, telecamera e Discord ascoltano gli eventi** (`GameEvent` nello snapshot, prodotti dalla fisica): non leggono né cambiano lo stato della fisica. Un nuovo tipo di evento è un cambio di protocollo.
- **I numeri vanno in `constants.ts`**, con un nome e un commento sull'unità (pixel/s, ms). Niente valori magici sparsi nel codice.
- **Il protocollo è un contratto condiviso.** `types.ts` (eventi Socket.IO e forma di `PlayerState`/`GameSnapshot`) si cambia solo in una PR che lo dichiara nel titolo (es. `Protocollo: aggiunge l'evento chat`) e che aggiorna server e client insieme.

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
9. **Merge:** lo fa un umano diverso dall'autore, dopo averla provata (squash merge). L'agente non approva e non mergia mai le proprie PR. Quando togli la bozza chiedi la review a un altro del gruppo (`gh pr edit N --add-reviewer <login>`) o di' al tuo umano di chiederla sul Discord.

## Coordinazione tra agenti

- **Resta nel perimetro del compito.** Niente refactor "già che ci sono", riformattazioni di file che non tocchi, rinomine di massa o cambi di configurazione (`tsconfig.json`, `vite.config.ts`): creano conflitti nelle PR degli altri. Se vedi qualcosa da sistemare, apri un'issue.
- **File caldi:** `constants.ts`, `types.ts` e `GameScene.ts` li toccano quasi tutti. Aggiungi righe, non riordinare quelle esistenti.
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

## Asset

- Solo asset fatti da noi o con licenza libera (CC0, CC-BY, ...). Annota fonte, autore e licenza in `public/assets/CREDITS.md`.
- File singoli oltre i 5 MB solo dopo averne parlato con il gruppo.

## Mai

- Committare segreti, token, `.env`, `node_modules/` o `dist/`.
- Pushare su `main`, fare force-push su branch altrui, mergiare la propria PR.
- Disattivare controlli (`// @ts-ignore`, `strict: false`) per far passare il typecheck.
- Spostare logica di gioco nel client.
- Modificare il README se il compito non lo richiede.

## Prima di dire "fatto"

1. `npm run typecheck`, `npm test` e `npm run build` passano, e il controllo CI della PR è verde.
2. Hai avviato `npm run dev` e provato con due finestre, se la modifica tocca il gioco.
3. La PR usa il template e dice quale agente ha scritto il codice e come l'hai provata.
