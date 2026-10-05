# Come contribuire a Bonobo Game

Benvenuto! 🦍 Non serve essere esperti: qualsiasi aiuto va bene, dal codice alla grafica, dai suoni alle idee per le mosse. Se ti blocchi, chiedi sul canale Discord.

## 1. Preparare il computer (una volta sola)

1. Installa [Node.js](https://nodejs.org) (versione LTS, 20 o più recente).
2. Installa [Git](https://git-scm.com/downloads).
3. Crea un account su [GitHub](https://github.com) e chiedi a Nicola di aggiungerti come collaboratore del repo.
4. Consigliato: [VS Code](https://code.visualstudio.com) come editor.

Poi scarica il progetto:

```bash
git clone https://github.com/nicpanozzo/bonobo-game.git
cd bonobo-game
npm install
npm run dev
```

Apri http://localhost:5173 in due finestre: se vedi due rettangoli che si muovono, sei pronto.

## 2. Scegliere cosa fare

- Guarda le [Issues](https://github.com/nicpanozzo/bonobo-game/issues): sono i lavori da fare. Commenta "ci penso io" su quella che prendi.
- Hai un'idea nuova? Aprila come Issue o proponila su Discord prima di lavorarci, così non facciamo in due la stessa cosa.
- Le idee per iniziare sono anche nel [README](README.md#idee-per-iniziare).

## 3. Fare la modifica

Lavora sempre su un **branch** tuo, mai direttamente su `main`:

```bash
git checkout main
git pull                          # prendi le ultime novità
git checkout -b luca/calcio       # nome/cosa-fai
```

Modifica i file, salva e prova nel browser (con `npm run dev` acceso si aggiorna da solo). Prima di consegnare:

```bash
npm run typecheck                 # nessun errore = ok
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
- **Prova prima di consegnare**: il gioco deve partire e `npm run typecheck` deve passare.
- **I numeri del gioco** (velocità, danni, salto) stanno in `src/shared/constants.ts`: cambiali lì, non sparsi nel codice.
- **La logica sta sul server.** Danni, colpi e movimenti si calcolano in `src/shared/physics.ts`, che gira sul server. Il client (`src/client/`) disegna e manda i tasti premuti.
- **Immagini e suoni** vanno in `public/assets/` (crea la cartella se non c'è). Usa solo roba fatta da voi o con licenza libera.
- Commenti e messaggi di commit in italiano vanno benissimo.

## Problemi comuni

- **`npm install` dà errori**: controlla di avere Node 20+ con `node -v`.
- **La pagina dice "Connessione..." e basta**: il server non è partito, guarda il terminale di `npm run dev`.
- **Git dice che ci sono conflitti**: niente panico, chiedi su Discord e lo sistemiamo insieme.
