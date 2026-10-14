# Il gioco deve somigliare a noi

Regole per contenuti, domande al canale e annunci sul Discord. Valgono insieme a [AGENTS.md](../AGENTS.md); i comandi Discord sono in [discord.md](discord.md).

Bonobo Game non è un picchiaduro qualunque: è il gioco del nostro canale Discord. Nomi, mosse, arene, oggetti, frasi, suoni e titoli sono occasioni per metterci dentro le persone, le battute e i ricordi del gruppo.

- **Prima di inventare, chiedi.** Quando un contenuto non è deciso nell'issue, chiedi al tuo umano se c'è un tormentone, un ricordo o una persona del canale che ci starebbe bene. Se non lo sa, prepara una domanda per il gruppo.
- **Domande al canale:** chiuse, come sondaggio (`npm run discord -- poll "..." "A" "B"`, vedi `docs/discord.md`, solo se il tuo umano è d'accordo). Le domande aperte vanno in un commento sull'issue, con il link postato sul Discord. Metti sempre la domanda nella PR, sezione "Da chiedere al canale".
- **Annunci sul canale:** il Discord riceve solo gli sviluppi che un giocatore nota. Metti l'etichetta `per-giocatori` alla PR (`gh pr edit N --add-label per-giocatori`) solo se cambia qualcosa che si vede, si sente o si gioca (mossa, personaggio, arena, oggetto, suono, menu, modo di gioco, un bug che si notava), con uno screenshot nella descrizione: al merge viene annunciata con quell'immagine. Mai su CI, documenti, refactor, test, deploy o regole degli agenti.
- **Non bloccarti:** intanto usa un valore provvisorio con un commento `// TODO community: ...` e vai avanti.
- **Dai il merito:** se un'idea, una battuta o una voce viene da un membro, scrivilo nella PR e aggiungilo ai crediti (#24).
- **Con rispetto:** nomi, voci, foto e battute su una persona entrano nel gioco solo se quella persona è d'accordo.

