# Come contribuire a Bonobo Game

Benvenuto! 🦍 Non serve essere esperti: qualsiasi aiuto va bene, dal codice alla grafica, dai suoni alle idee per le mosse. Se ti blocchi, chiedi sul canale Discord.

## 1. Preparare il computer (una volta sola)

1. Installa [Node.js](https://nodejs.org) (versione 22).
2. Installa [Git](https://git-scm.com/downloads).
3. Installa [Godot 4.5](https://godotengine.org/download) (la versione standard, non .NET): è il programma con cui è fatto il gioco.
4. Crea un account su [GitHub](https://github.com) e chiedi a Nicola di aggiungerti come collaboratore del repo.
5. Consigliato: [VS Code](https://code.visualstudio.com) come editor.

Poi scarica il progetto:

```bash
git clone https://github.com/nicpanozzo/bonobo-game.git
cd bonobo-game
npm install
npm run dev
```

Lascia `npm run dev` acceso (è il server di gioco). Apri Godot, **Importa** `godot/project.godot` e premi Play (F5) due volte, o una volta con due istanze (menu Debug): se nella stessa stanza vedi due lottatori che si muovono, sei pronto.

> Il gioco ufficiale è quello in `godot/`. La cartella `src/client/` è il vecchio client web: non ci si aggiungono più funzioni.

## 2. Scegliere cosa fare

- Guarda le [Issues](https://github.com/nicpanozzo/bonobo-game/issues): sono i lavori da fare. Commenta "ci penso io" su quella che prendi.
- Hai un'idea nuova? Aprila come Issue o proponila su Discord prima di lavorarci, così non facciamo in due la stessa cosa.
- Le idee per iniziare sono anche nel [README](README.md#idee-per-iniziare).

## Mettici il canale

Il gioco è bello se ci riconosciamo dentro. Quando aggiungi un personaggio, un'arena, un oggetto o una frase, chiediti: c'è una battuta, un ricordo o una persona del canale che ci starebbe? Se non lo sai, chiedilo sul Discord, meglio con un sondaggio (vedi [docs/discord.md](docs/discord.md)). Scrivi nella PR da chi viene l'idea, così finisce nei crediti. E se il gioco prende in giro qualcuno, chiedigli prima se gli va bene.

## 3. Fare la modifica

Lavora sempre su un **branch** tuo, mai direttamente su `main`:

```bash
git checkout main
git pull                          # prendi le ultime novità
git checkout -b luca/calcio       # nome/cosa-fai
```

Modifica i file, salva e prova in Godot (F5) con `npm run dev` acceso. Prima di consegnare:

```bash
npm run typecheck                 # nessun errore = ok
npm test                          # la logica del gioco funziona ancora
npm run export:godot              # solo se hai cambiato src/shared o public/assets
```

## 4. Consegnare con una Pull Request

```bash
git add .
git commit -m "Aggiunge il calcio con il tasto K"
git push -u origin luca/calcio
```

GitHub ti mostra un link per aprire la **Pull Request** (PR): aprila, scrivi cosa hai fatto e come provarlo. Un altro del gruppo la guarda, magari chiede qualche ritocco, e poi la unisce a `main`.

## Regole del gruppo

- **Una PR, una cosa.** Meglio tre PR piccole che una gigante.
- **Niente push diretti su `main`.**
- **Prova prima di consegnare**: il gioco deve partire in Godot e `npm run typecheck` deve passare.
- **I numeri del gioco** (velocità, danni, salto) stanno in `src/shared/constants.ts`: cambiali lì, non sparsi nel codice.
- **La logica sta sul server.** Danni, colpi e movimenti si calcolano in `src/shared/physics/`, che gira sul server. Il gioco Godot (`godot/`) disegna, suona e manda i tasti premuti.
- **Immagini e suoni** vanno in `public/assets/`; `npm run export:godot` li porta in Godot. Usa solo roba fatta da voi o con licenza libera.
- Commenti e messaggi di commit in italiano vanno benissimo.

## Problemi comuni

- **`npm install` dà errori**: controlla di avere Node 22 con `node -v`.
- **Il gioco dice "Mi collego..." e basta**: il server non è partito, guarda il terminale di `npm run dev` (o controlla l'indirizzo del server nella lobby).
- **Git dice che ci sono conflitti**: niente panico, chiedi su Discord e lo sistemiamo insieme.

## Lavorare con un agente AI

Se usi un agente (Claude Code, Codex, Cursor, Copilot, Gemini, ...), le regole per lui sono in [AGENTS.md](AGENTS.md) e le legge da solo. Ogni agente trova il suo file, che rimanda sempre ad AGENTS.md:

| Agente | File che legge |
|---|---|
| Codex, Cursor, Copilot, Jules, Aider, ... | `AGENTS.md` |
| Claude Code | `CLAUDE.md` (importa `AGENTS.md`) |
| Gemini CLI | `GEMINI.md` (importa `AGENTS.md`) |
| GitHub Copilot | `.github/copilot-instructions.md` |
| Cursor | `.cursor/rules/agents.mdc` |

Come usarlo bene:

0. **Il comando da ricordare è `/compito`.** È una skill che sta nella repo (`.claude/skills/compito/SKILL.md`): porta il tuo agente dall'inizio alla fine, cioè riprendere la PR che avevi aperto, scegliere un'issue libera, prenderla, aprire la bozza, lavorare, provare e consegnare. Con Claude Code basta scrivere `/compito` (o `/compito 12` per un'issue precisa); si carica da sola appena cloni la repo. Con altri agenti scrivi *"Segui .claude/skills/compito/SKILL.md"*.

1. **Non sai cosa fare?** Di' al tuo agente *"Leggi AGENTS.md e trova un compito libero per me"*: guarda la [roadmap](https://github.com/nicpanozzo/bonobo-game/issues?q=label%3Aroadmap), sceglie un'issue con l'etichetta `pronto` in una corsia libera e te la propone.
1. **Parti da un'issue** e assegnatela, poi di' al tuo agente qualcosa come *"Lavora sull'issue #12 seguendo AGENTS.md"*. Crea il branch, apre subito una PR in bozza con il piano e pusha spesso: git è il modo in cui gli agenti si parlano, quindi prima si dichiarano le intenzioni e poi si lavora.
2. **Provalo tu** prima di togliere la bozza: l'agente può sbagliare, soprattutto sul multiplayer.
3. **Le preferenze personali** (modello, permessi, note tue) tienile nei file locali del tuo agente, per esempio `CLAUDE.local.md` o `~/.claude/CLAUDE.md`, non nella repo.
4. **Se il tuo agente sbaglia sempre la stessa cosa**, aggiungi una riga ad AGENTS.md in una PR dedicata. Teniamolo corto (sotto le ~150 righe): più è lungo, meno gli agenti lo seguono.
