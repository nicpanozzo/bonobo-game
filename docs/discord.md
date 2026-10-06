# Il repo parla col Discord

Il gioco posta nel canale Discord del gruppo tramite un **webhook**: un indirizzo segreto che permette di scrivere in un canale, senza bot da tenere acceso.

Cosa fa:

- **Quando una PR viene unita** a `main`, una GitHub Action la annuncia nel canale con titolo, autore, link e il primo screenshot della descrizione.
- **Ogni venerdì sera** posta "La settimana dei Bonobi": cosa è entrato nel gioco e le issue facili ancora libere, per chi vuole iniziare. Si può lanciare a mano da **Actions → Discord settimanale → Run workflow**.
- **A fine partita** il server di gioco posta il risultato: chi ha vinto e, per ognuno, KO, danni inflitti e cadute. Serve la stessa variabile `DISCORD_WEBHOOK_URL` nell'ambiente del server (su Render o sul Mac che ospita la serata). Le partite con meno di due persone, per esempio da soli contro un bot, non vengono postate.
- **Chiunque (anche il tuo agente)** può postare un progresso con screenshot o lanciare un sondaggio con `npm run discord`.

## Da fare una volta sola (Nicola o un admin del server)

1. Su Discord, apri le impostazioni del canale dove vuoi i messaggi (es. `#bonobo-game`): **Modifica canale → Integrazioni → Webhook → Nuovo webhook**.
2. Dagli un nome (es. "Bonobo Game") e un'immagine, poi **Copia URL webhook**.
3. Su GitHub, nel repo: **Settings → Secrets and variables → Actions → New repository secret**, nome `DISCORD_WEBHOOK_URL`, valore l'URL copiato.

Da qui in poi ogni PR unita compare nel canale.

> L'URL del webhook è una password: chi ce l'ha può scrivere nel canale. Non metterlo mai nel codice, nelle issue o nelle PR. Se finisce in giro, cancellalo da Discord e creane uno nuovo.

## Usarlo dal tuo computer (o dal tuo agente)

Chiedi l'URL a Nicola in privato e mettilo in una variabile d'ambiente, solo per il tuo terminale:

```bash
export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."   # macOS / Linux
$env:DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."     # Windows PowerShell
```

Poi:

```bash
# Un progresso con screenshot (file locale o link a un'immagine)
npm run discord -- post "Il calcio funziona! 🦶" --image calcio.png

# Un sondaggio nativo di Discord (da 2 a 10 risposte, dura 24 ore se non dici --hours)
npm run discord -- poll "Quale arena facciamo prima?" "Giungla" "Vulcano" "Tetto della scuola" --hours 48

# Più risposte selezionabili
npm run discord -- poll "Quali mosse volete?" "Calcio" "Lancio" "Schivata" --multi

# Leggere i voti (l'id lo stampa il comando poll)
npm run discord -- results 1234567890
```

Senza `DISCORD_WEBHOOK_URL` lo script non posta niente e non dà errore.

## Per gli agenti

- Posta solo quando il tuo umano te lo chiede, o per mostrare un risultato già finito (una PR pronta da provare). Niente messaggi per ogni commit.
- Per le domande al gruppo preferisci un **sondaggio** con risposte chiuse: il webhook può leggere i voti con `results`, ma **non** può leggere le risposte scritte nel canale. Per una domanda aperta, posta la domanda e chiedi di rispondere nell'issue su GitHub.
- Nella descrizione della PR metti uno screenshot (`![descrizione](link)`): la GitHub Action lo usa nell'annuncio.

## Idee per coinvolgere il gruppo

Le rubriche fisse con esempi pronti da postare sono in [format-discord.md](format-discord.md).

- **Le decisioni di design ai voti**: quando una PR sceglie un valore (danno del calcio, velocità, nome di una mossa), lancia un sondaggio e scrivi il risultato nella PR.
- **Prima e dopo**: uno screenshot o una GIF quando una cosa si vede nel gioco vale più di dieci messaggi.
- I processi già pensati nella roadmap usano lo stesso canale: serata di playtest (#22), mini-jam con voto (#23), crediti e patch notes (#24).

## Limiti

- Il webhook **scrive** e rilegge i propri sondaggi, ma non legge gli altri messaggi del canale né sa chi ha votato cosa. Per quello serve un bot Discord vero, da tenere acceso sul server: si può aggiungere più avanti se serve.
- I risultati delle partite (chi vince, classifica) sono un compito a parte, l'issue #18, che userà lo stesso `DISCORD_WEBHOOK_URL`.
