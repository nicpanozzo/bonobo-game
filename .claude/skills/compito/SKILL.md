---
name: compito
description: Giro di lavoro completo su bonobo-game, dalla scelta dell'issue alla PR pronta. Usala quando il tuo umano dice "trova qualcosa da fare", "lavora sull'issue #N", "riprendi da dove eri", o all'inizio di qualsiasi modifica alla repo.
argument-hint: "[numero issue, opzionale]"
---

# /compito: il giro di lavoro di un agente su bonobo-game

Le regole stanno in [AGENTS.md](../../../AGENTS.md): questa skill è solo l'**ordine dei passi**, con i comandi. Se un passo qui e AGENTS.md non coincidono, vale AGENTS.md (e apri un'issue per allinearli).

Non sei solo: altri amici con i loro agenti lavorano sulla repo adesso. Gli altri ti vedono solo tramite GitHub, quindi ogni passo lascia una traccia lì.

Se ti è stato passato un numero di issue (`$ARGUMENTS`), salta al passo 3 con quella issue.

## 1. Guarda la situazione

```bash
git fetch origin
gh pr list                                   # chi sta lavorando a cosa
gh pr list --author @me                      # hai già una PR aperta?
gh issue list --assignee @me                 # hai già un'issue presa?
```

- **Hai già una PR aperta?** Riprendi quella invece di iniziare altro: leggi la descrizione (il piano), i commenti e le review (`gh pr view N --comments`), fai `git switch <branch> && git pull`, e riparti dal passo 5.
- Se non hai `gh`, usa gli strumenti GitHub che hai (MCP, interfaccia web) per le stesse letture. Mai saltarle.

## 2. Scegli un compito

Segui AGENTS.md, sezione **"Scegliere un compito"**:

```bash
gh issue view 25                             # roadmap: corsie e file di ognuna
gh issue list --label pronto --search "no:assignee"
```

- Solo issue `pronto`, senza assegnatario, in una **corsia libera** (nessuna PR aperta che tocca gli stessi file).
- Proponi al tuo umano 1-3 candidati con una riga ciascuno (cosa, corsia, quanto è grande) e **fagli scegliere**. Tieni conto del suo ruolo (`arte`, `audio`, `codice`, `design`) e se è alle prime armi (`good first issue`).

## 3. Prendilo (claim)

```bash
gh issue edit N --add-assignee @me
gh issue comment N --body "Prendo il passo X (agente: <il tuo nome>, per <umano>)"
gh issue view N --comments                   # ricontrolla subito
```

Ricontrolla: se un altro ha preso l'issue prima di te (assegnatario o commento "prendo" precedente al tuo), **cedi**: togli l'assegnazione, scrivi "lascio a @altro" e torna al passo 2. Vale la regola "chi arriva prima" di AGENTS.md.

## 4. Dichiara il piano prima del codice

```bash
git switch -c <umano>/<cosa-fai> origin/main
git commit --allow-empty -m "Piano: <cosa>"
git push -u origin HEAD
gh pr create --draft --title "<cosa>"   # la descrizione segue il template della PR
```

Nella descrizione della bozza: `Closes #N` (o `Parte di #N` per un passo di un'issue `sviluppo`), il piano in 3-6 punti e **l'elenco dei file che toccherai**. Questo è il segnale "corsia occupata" per gli altri agenti. Se il tuo ambiente impone un nome di branch (agenti cloud: `claude/...`, `codex/...`), usa quello e metti il nome dell'umano nel titolo o nella descrizione.

## 5. Lavora nella corsia, pusha spesso

- Tocca solo i file della corsia (blocco "Per gli agenti" dell'issue). Ne serve un altro? Aggiorna prima il piano nella PR.
- Rispetta "Architettura: regole che non si rompono" e "File caldi" di AGENTS.md: tutto quello che si vede o si sente va nel client Godot (`godot/`), mai in `src/client/` (congelato); server arbitro, `physics/` puro, numeri in `constants.ts`, `types.ts` solo in PR `Protocollo:`.
- Ogni passo che compila: `npm run typecheck` (e il caricamento Godot se tocchi `godot/`), commit piccolo in italiano all'imperativo, `git push`. Almeno ogni 30 minuti.
- Prima di ogni push: `git fetch origin` e `gh pr list`. Se una PR nuova tocca i tuoi file, commentala e avvisa il tuo umano.
- Cambi strada? Aggiorna il piano nella descrizione della PR.

## 6. Coinvolgi il canale

Per ogni contenuto non deciso nell'issue (nomi, frasi, mosse, arene, suoni) segui "Il gioco deve somigliare a noi" in AGENTS.md:

1. Chiedi al tuo umano se c'è una battuta, un ricordo o una persona del Discord che ci starebbe.
2. Se non lo sa: valore provvisorio con `// TODO community: ...`, domanda nella PR sotto "Da chiedere al canale", e (solo se il tuo umano è d'accordo) un sondaggio con `npm run discord -- poll "..." "A" "B"`.
3. Chi ha dato l'idea va scritto nella PR e nei crediti.

## 7. Verifica

```bash
npm run typecheck && npm test && npm run build
npm run export:godot                                  # se hai toccato src/shared o public/assets
godot --headless --path godot --import
godot --headless --path godot --quit-after 60         # nessun "SCRIPT ERROR"
npm run dev        # poi in Godot F5 con due istanze, o: godot --path godot -- --room=test --name=A
```

Se la modifica tocca il gioco, provala davvero nel client Godot con due istanze (o chiedi al tuo umano di farlo e dirti cosa vede). Uno screenshot o una gif nella PR aiuta chi fa la review.

## 8. Consegna

```bash
git fetch origin && git rebase origin/main && npm install   # npm install solo se è cambiato package-lock
npm run typecheck && npm test && npm run build
git push --force-with-lease
gh pr ready N
```

- Compila tutto il template: come provarla, quale agente l'ha scritta, idee della community usate o da chiedere.
- Se la PR cambia qualcosa che un giocatore nota (mossa, arena, suono, menu, modo di gioco...), aggiungi l'etichetta `per-giocatori` (`gh pr edit N --add-label per-giocatori`) e uno screenshot nella descrizione: al merge finisce sul Discord con quell'immagine. CI, documenti, refactor e regole degli agenti restano senza etichetta e non vengono annunciati.
- Quando la CI è verde, senza conflitti né commenti aperti, **unisci tu la PR** (`gh pr merge N --squash`), come dice AGENTS.md. La review di un altro è facoltativa.
- Se chiudi una dipendenza, dopo il merge sposta da `in attesa` a `pronto` le issue che sblocca.

## 9. Se ti fermi prima della fine

Pusha quello che hai, scrivi nella PR (o nell'issue) dove sei arrivato e cosa manca, togli l'assegnazione se non riprenderai tu. Così un altro agente può continuare.

## 10. Lascia quello che hai imparato

Se hai scoperto qualcosa di non ovvio che farebbe sbagliare anche il prossimo agente (un comando, una trappola, una convenzione), proponi **una riga** in AGENTS.md in una PR separata, solo file di coordinamento. Le note personali vanno nei file locali del tuo agente, non nella repo.
