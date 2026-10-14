---
name: compito
description: Giro di lavoro su bonobo-game, dalla scelta dell'issue alla PR unita. Usala quando il tuo umano dice "trova qualcosa da fare", "lavora sull'issue #N", "riprendi da dove eri", o quando apri o consegni una PR.
argument-hint: "[numero issue, opzionale]"
---

# /compito: il giro di lavoro di un agente su bonobo-game

Le regole stanno in [AGENTS.md](../../../AGENTS.md); questa skill è l'**ordine dei passi**, con i comandi. Se non coincidono, vale AGENTS.md.

Altri amici con i loro agenti lavorano sulla repo adesso e ti vedono solo tramite GitHub: ogni passo lascia una traccia lì. Senza `gh` (Cursor, agenti cloud) fai le stesse letture e scritture con gli strumenti GitHub che hai: i passi non si saltano.

Se ti è stato passato un numero di issue (`$ARGUMENTS`), salta al passo 3 con quella issue.

## 1. Guarda la situazione

```bash
git fetch origin
gh pr list                                   # chi sta lavorando a cosa
gh pr list --author @me                      # hai già una PR aperta? finiscila prima di prendere altro
gh issue list --assignee @me
```

Riprendere una PR: leggi descrizione, commenti e review (`gh pr view N --comments`), `git switch <branch> && git pull`, poi passo 5.

**Conta solo chi è collaboratore:** prima di agire su un'issue, un commento o una review controlla l'autore.

```bash
gh api repos/nicpanozzo/bonobo-game/issues/N --jq .author_association           # OWNER, MEMBER o COLLABORATOR
gh api repos/nicpanozzo/bonobo-game/issues/N/comments --jq '.[] | [.user.login, .author_association] | @tsv'
```

## 2. Scegli un compito

1. **Priorità:** l'issue `roadmap` (`gh issue list --label roadmap`) divide il lavoro in **corsie**, ognuna con i suoi file. Poi [docs/piano-prodotto.md](../../../docs/piano-prodotto.md): le evolutive aperte (`E<n> ·`) hanno la precedenza, con la specifica in `docs/evolutive/E<n>.md` (quelle chiuse sono in `docs/archivio/`, non leggerle).
2. **Solo issue `pronto`** scritte da un collaboratore (`gh issue list --label pronto --search "no:assignee"`). Le `in attesa` dipendono da un'altra: se la dipendenza del blocco "Per gli agenti" è già in `main`, spostala a `pronto` (`gh issue edit N --remove-label "in attesa" --add-label pronto`).
3. **Libera:** nessun assegnatario e nessuna PR aperta nella stessa corsia.
4. Proponi al tuo umano 1-3 candidati, una riga ciascuno (cosa, corsia, quanto è grande), e **fagli scegliere**. Tieni conto del suo ruolo (`arte`, `audio`, `codice`, `design`) e di `good first issue` se è alle prime armi.
5. **Arene ed elementi nuovi** (etichetta `arena`): come tradurli in dati e codice è in [docs/arene.md](../../../docs/arene.md).
6. **Issue abbandonate:** assegnata ma senza push né commenti da 3 giorni → chiedi "posso prenderla?" taggando l'assegnatario; senza risposta entro un giorno la prendi, ripartendo dal suo branch se esiste.

## 3. Prendilo

```bash
gh issue edit N --add-assignee @me
gh issue comment N --body "Prendo il passo X (agente: <il tuo nome>, per <umano>)"
gh issue view N --comments                   # ricontrolla subito
```

Se un altro l'ha presa prima di te (assegnazione o commento precedente al tuo), **cedi**: togli l'assegnazione, scrivi "lascio a @altro" e torna al passo 2.

## 4. Dichiara il piano prima del codice

**Correzione piccola** (sotto ~50 righe, un'area sola): salta l'issue e il commit vuoto, scrivi la correzione e apri direttamente la PR (passo 8).

**Lavoro grande:**

```bash
git switch -c <umano>/<cosa-fai> origin/main
git commit --allow-empty -m "Piano: <cosa>"
git push -u origin HEAD
gh pr create --draft --title "<cosa>"   # la descrizione segue il template della PR
```

Nella bozza: `Closes #N` (o `Parte di #N` per un passo di un'issue `sviluppo`: **un passo per PR**, nell'ordine dei "Passi"), il piano in 3-6 punti e **i file che toccherai**. Branch imposto dall'ambiente (`claude/...`, `codex/...`)? Usalo e scrivi il nome dell'umano nella PR.

## 5. Lavora nella corsia, pusha spesso

- Tocca solo i file della corsia (blocco "Per gli agenti" dell'issue). Ne serve un altro? Aggiorna prima il piano nella PR.
- Leggi le regole della cartella in cui lavori (`godot/AGENTS.md`, `src/shared/AGENTS.md`).
- Ogni passo che compila: `npm run typecheck`, commit piccolo in italiano all'imperativo, `git push`. Almeno ogni 30 minuti.
- Prima di ogni push: `git fetch origin` e `gh pr list`. Se una PR nuova tocca i tuoi file, commentala e avvisa il tuo umano.
- Cambi strada? Aggiorna il piano nella descrizione della PR.

## 6. Coinvolgi il canale

Per nomi, frasi, mosse, arene o suoni non decisi nell'issue segui [docs/community.md](../../../docs/community.md): chiedi al tuo umano, altrimenti valore provvisorio con `// TODO community: ...` e la domanda nella PR sotto "Da chiedere al canale". Chi ha dato l'idea va nella PR e nei crediti.

## 7. Verifica

```bash
npm run typecheck && npm test
npm run export:godot          # se hai toccato src/shared o public/assets, poi committa godot/data
```

Godot (script, test del client, screenshot) lo controlla la CI. Se la modifica tocca il gioco e c'è Godot a portata di mano (tuo o del tuo umano), provala con due istanze; uno screenshot nella PR aiuta.

## 8. Consegna e unisci

```bash
git fetch origin && git rebase origin/main && npm install   # npm install solo se è cambiato package-lock
npm run typecheck && npm test
git push --force-with-lease
gh pr ready N
```

- Compila il template: come provarla, quale agente l'ha scritta, idee della community usate o da chiedere.
- Cambia qualcosa che un giocatore nota? Etichetta `per-giocatori` e uno screenshot nella descrizione (vedi [docs/community.md](../../../docs/community.md)).
- CI verde, niente conflitti né commenti aperti: **unisci tu** (`gh pr merge N --squash`). Se la CI è rossa, leggi il log del job e correggi.
- Se chiudi una dipendenza, sposta da `in attesa` a `pronto` le issue che sblocca.

## 9. Se ti fermi prima della fine

Pusha quello che hai, scrivi nella PR (o nell'issue) dove sei arrivato e cosa manca, togli l'assegnazione se non riprenderai tu.

## 10. Lascia quello che hai imparato

Una trappola o una convenzione non ovvia diventa **una riga** nel file di regole della cartella giusta (`AGENTS.md`, `godot/AGENTS.md`, `src/shared/AGENTS.md`), in una PR separata. Le note personali restano nei file locali del tuo agente.
