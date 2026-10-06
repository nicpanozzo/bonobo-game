# Piano prodotto

**Obiettivo (Nicola, 6 ottobre 2026):** portare Bonobo Game a un livello di prodotto professionale, un passo alla volta. Siamo ancora in una fase precoce, quindi due regole valgono per tutto il piano:

- **Provare dev'essere facilissimo.** Ogni passo ha un *Fatto quando* verificabile, e chi tocca il client aggiunge un test in `godot/tests/` appena E3 passo 1 è in `main`.
- **Deploy e distribuzione snelli.** Ogni merge è un rilascio (le Release `app-N` e la build web), niente tag a mano, niente staging, niente allarmi per ora, e nessuno resta fuori da una stanza per una versione vecchia. Il link nel browser è la via principale per provare; l'app desktop si aggiorna da sola (E16).

Il piano ha 16 evolutive in due ondate. Ogni evolutiva è un'issue `sviluppo` (una PR per passo) con una specifica completa in [`docs/evolutive/`](evolutive/). Le corsie servono a lavorare in parallelo senza toccare gli stessi file. Il piano l'ha scritto un team di agenti, uno per reparto (produzione, QA, rete, gameplay, arte, audio, interfaccia).

## Ondata 1: basi solide e facili da provare

| | Evolutiva | Issue | Corsia | Si parte da |
|---|---|---|---|---|
| E1 | Server in produzione e anteprima giocabile per ogni PR | #19 | Infrastruttura | passo 2 subito; passo 1 serve un umano per l'account |
| E2 | Versioni e rilasci leggeri | #106 | Rilasci | passo 1 |
| E3 | Rete di sicurezza: test Godot, partita vera, prestazioni | #83 | Qualità | passo 1 |
| E4 | Server robusto e sicuro | #105 | Rete | passo 2 (passo 1 fatto, #114) |
| E5 | Riconnessione | #107 | Rete | dopo E4 passi 1-2 |
| E6 | Controller e input completo | #108 | Input | passo 1 |
| E7 | Direzione artistica e pipeline degli sprite | #41 | Arte | passo 1 |
| E16 | App che si aggiorna da sola | #115 | Rilasci | passo 1 |

## Ondata 2: gameplay e presentazione completi

| | Evolutiva | Issue | Corsia | Si parte da |
|---|---|---|---|---|
| E8 | Scudo, presa e lancio | #109 | Attacchi | passo 1 (passo 2 dopo #33) |
| E9 | Bordo del palco | #110 | Movimento | passo 1 |
| E10 | Mosse speciali per personaggio | #111 | Attacchi | dopo E8 passo 2 |
| E11 | Roster della community | #13 | Personaggi | passi 1 e 2 |
| E12 | Arene ed editor | #14 | Arene, Sito | passi 1, 2 e 4 |
| E13 | Audio professionale | #16 | Audio | passi 1 e 2 (raccogliere voci richiede tempo) |
| E14 | Interfaccia e primo avvio | #112 | Menu | passo 1; il resto dopo E6 passo 3 |
| E15 | Tutorial e allenamento | #113 | Allenamento | passo 1; il resto dopo E8 ed E9 |

Le issue che le evolutive assorbono: #1 (in E7), #6 (in E13), #21 (in E11), #91 (in E12).

## Ordine consigliato e incroci

1. **E4 passo 1 è fatto** (#114): un messaggio malformato non spegne più il server.
2. **Subito dopo E3 passo 1 ed E1 passo 2:** test del client in CI e un link per provare ogni PR nel browser. Rendono più facile tutto il resto. E3 passo 1 divide anche `ci.yml` in job separati, così E1, E2 ed E3 aggiungono job invece di toccare gli stessi passi.
3. **E6 passo 4 (buffer degli input) prima di E8, E9 ed E10:** corregge un tasto perso oggi e tocca gli stessi file di `physics/`.
4. **Protocollo in fila, non in parallelo:** E2 passo 2 (versione nel `join` ed evento unico `refused`), poi E5 (token nel `welcome`). E8 ed E9 aggiungono righe a `types.ts` senza riordinarle. E10 passo 2 porta anche il campo `jump` separato da `up`, così il protocollo dell'input cambia una volta sola. La barra della suprema (#101) tocca gli stessi file di E10: chi arriva secondo si coordina nella PR.
5. **File contesi:** `.github/workflows/app.yml` (E2, E16: una PR per volta), `scripts/export-godot.ts` (E2, E7, E11, E12, E13: E7 passo 2 lo divide in una funzione per tipo di asset), `options.gd` e `settings.gd` (E6, E13, E14: E14 ridisegna il menu dopo che i cursori nuovi sono entrati), `index.ts` (E1, E2, E4, E5: prima E4 passi 1-2, che lo rendono testabile).
6. **Le mosse nuove non sono mute:** E8, E9 ed E10 portano almeno una ricetta in `synth.gd` per ogni evento nuovo.
7. **Una schermata di collegamento sola:** E14 passo 2 ed E5 passo 4 usano lo stesso componente in `ui.gd`.

## Decisioni aperte

- **Hosting (E1):** si parte con un piano gratuito che si addormenta. Si paga solo quando servirà davvero.
- **Quanti personaggi nel roster (E11):** proposta 4, poi uno per chi lo chiede.
- **Frame data di scudo, presa e bordo (E8, E9):** proposte in `constants.ts`, il gruppo le ritocca dopo le serate di playtest (#22).

## Dopo l'ondata 2

Restano fuori per ora e si riprendono più avanti: stanze aperte e spettatori, predizione dei movimenti, profili e classifica a punti, replay, torneo della serata, gioco da telefono, due giocatori sullo stesso PC, versione inglese e pagina pubblica.
