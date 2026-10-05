# Format per il canale Discord

Rubriche fisse, stile social, per far ridere il gruppo e tirarlo dentro la creazione del gioco. Ogni format ha un giorno, uno schema e un esempio già pronto da incollare (o da mandare con `npm run discord`, vedi [discord.md](discord.md)).

Regola d'oro: **ogni post chiede qualcosa** (un voto, una foto, un nome, una sfida). Un post che non chiede niente è un post che nessuno commenta.

## Il calendario

| Giorno | Format | Cosa chiede al gruppo |
| --- | --- | --- |
| Lunedì | 🗳️ Il Parlamento dei Bonobi | un voto su una scelta vera del gioco |
| Mercoledì | 🐛 Bug della settimana | ridere di un bug e dargli un nome |
| Venerdì | 🦍 La settimana dei Bonobi | (automatico) prendere un'issue |
| Quando capita | ⚡ Prima / Dopo, 🎤 Dichiarazioni, 📜 Patch notes | reazioni, frasi, idee |
| Una volta al mese | 🏆 I Bonobo Awards | votare i premi del mese |

Meglio poche rubriche costanti che tante a caso: se un format non prende reazioni per tre settimane, si cambia.

---

## 🗳️ Il Parlamento dei Bonobi

Un sondaggio su una decisione **vera** del gioco, scritto come una seduta parlamentare. Il risultato si rispetta: va nella PR e in `constants.ts`. È il format più importante, perché fa sentire tutti autori.

**Schema:** titolo pomposo + la questione + 2-4 opzioni (almeno una assurda) + "la seduta si chiude tra X ore".

**Esempio:**

```bash
npm run discord -- poll "🏛️ SEDUTA STRAORDINARIA DEL PARLAMENTO DEI BONOBI. Ordine del giorno: quanto deve fare male il calcio?" "Poco, siamo persone civili (8%)" "Il giusto (12%)" "Tanto (18%)" "Deve mandarti a casa tua, fisicamente" --hours 48
```

Dopo la chiusura, il risultato:

> 🏛️ **Il Parlamento ha deliberato.** Con 7 voti contro 3, il calcio farà il 12%. La mozione "mandarti a casa tua, fisicamente" è stata respinta per motivi tecnici ma resta nei nostri cuori. La legge entra in vigore con la PR del calcio.

**Altre sedute pronte:** come si chiama l'arena della giungla; quale mossa aggiungiamo dopo (calcio / lancio della banana / schivata / urlo); di che colore è il bonobo di Marco; cosa succede quando cadi fuori dallo schermo (si sente un urlo / parte una musica triste / esplodi in banane).

---

## 🐛 Bug della settimana

Il bug più ridicolo della settimana, presentato come un documentario naturalistico. I bug fanno ridere più delle feature, e trasformano un problema in un momento del gruppo.

**Schema:** screenshot o GIF del bug + voce narrante alla Piero Angela + "dategli un nome" + chi lo sistema vince la gloria.

**Esempio:**

> 🐛 **BUG DELLA SETTIMANA**
>
> *Qui vediamo il bonobo nel suo habitat naturale. Dopo un KO, invece di cadere, scivola lentamente verso destra per l'eternità, come un'anima in pena su una pista da bowling. Gli studiosi non sanno ancora dove sia diretto.*
>
> 📸 [screenshot]
>
> Dategli un nome nei commenti, il più votato finisce nel titolo dell'issue. Chi lo sistema riceve il titolo di **Domatore di bug** fino a venerdì.

Nota: il bug dell'esempio è vero, lo sta sistemando Riccardo nella PR #8.

---

## ⚡ Prima / Dopo

Uno screenshot (o GIF) di com'era e di com'è adesso. È il format più facile e funziona sempre, soprattutto quando il "prima" è imbarazzante.

**Schema:** "PRIMA" e "DOPO" con due immagini + una riga di commento + chi l'ha fatto.

**Esempio:**

```bash
npm run discord -- post "⚡ PRIMA: due rettangoli che si spingono. DOPO: due rettangoli che si spingono CON IL DANNO IN PERCENTUALE. Il progresso è inarrestabile. Grazie a @Nicola 🦍" --image prima-dopo.png
```

Quando arriveranno gli sprite veri, il "prima" con i rettangoli diventerà leggenda: tenete gli screenshot vecchi.

---

## 🎤 Dichiarazioni pre-partita

Ogni lottatore ha un membro del gruppo dietro (vedi #13 e #16). Prima di una serata di playtest, ognuno manda la sua frase da trash talk e il canale vota la migliore. Le frasi migliori diventano voice line o taunt nel gioco.

**Schema:** annuncio della sfida + "lasciate qui la vostra dichiarazione" + sondaggio sulla migliore.

**Esempio:**

> 🎤 **CONFERENZA STAMPA PRE-PARTITA**
>
> Giovedì sera si gioca (#22). Lasciate qui sotto la vostra dichiarazione per gli avversari, max 10 parole. La più votata diventa la frase del vostro lottatore quando vince.
>
> Esempio di livello: *"Ti mando così lontano che ti serve il passaporto."*

---

## 📜 Patch notes drammatiche

Le novità di un aggiornamento scritte come se fossero una tragedia greca o un bollettino di guerra. Fa leggere le patch notes anche a chi non le leggerebbe mai (collegato a #24).

**Esempio** (le novità sono inventate):

> 📜 **PATCH NOTES 0.3: "LA CADUTA"**
>
> • Il doppio salto non è più infinito. I bonobi hanno perso il dono del volo. Alcuni non l'hanno presa bene.
> • Il KO ora fa cadere a terra invece di far scivolare. Il bonobo scivolante è stato dichiarato disperso.
> • Aggiunto il danno in percentuale. Più ne prendi, più voli. Come nella vita.
>
> Provatelo e diteci cosa si è rotto 👇

---

## 🏆 I Bonobo Awards

Una volta al mese, premi finti votati dal gruppo. Premiano chi contribuisce, anche con cose che non sono codice.

**Categorie pronte:**

- 🥇 **Bonobo d'oro**: chi ha fatto entrare più cose nel gioco
- 🐛 **Domatore di bug**: chi ha sistemato il bug più assurdo
- 💀 **Kamikaze del mese**: più autodistruzioni nelle serate di playtest
- 🎨 **Picasso della giungla**: miglior contributo grafico o sonoro
- 🤡 **Idea più folle**: la proposta più assurda (anche se non è entrata nel gioco)

**Esempio:**

```bash
npm run discord -- poll "🏆 BONOBO AWARDS di ottobre. Categoria: IDEA PIÙ FOLLE del mese" "L'arena che affonda nella Nutella" "Il bonobo che attacca lanciando altri bonobi" "La mossa finale che chiude il browser all'avversario" --hours 72
```

Il vincitore finisce nei crediti del gioco (#24).

---

## 🦍 La settimana dei Bonobi

È automatico: ogni venerdì sera la GitHub Action posta cosa è entrato nel gioco e le issue facili ancora libere. Si può tenere vivo rispondendo al post con lo screenshot più bello della settimana.

---

## Per gli agenti AI

Se il tuo umano ti chiede di preparare un post:

- scegli il format giusto da qui, mantieni il tono (ironico, mai cattivo verso una persona);
- per le scelte di design preferisci il **Parlamento** (sondaggio) a una domanda aperta: i voti si leggono con `npm run discord -- results <id>`;
- metti sempre uno screenshot quando qualcosa si vede nel gioco;
- non postare senza che il tuo umano l'abbia approvato: il canale è delle persone, non degli agenti.
