# Foglio di produzione

Una riga per clip e per immagine. Lo aggiorna chi lavora, nella PR del suo passo: **Stato** è uno tra `da fare`, `generata`, `consegnata`, `tagliata`, `nel gioco`, `scartata` (per le immagini: `da fare` o `fatta`). Il resto delle istruzioni è nel [README](README.md).

Creato da `tools/flow/prompt_flow.py`, che non lo riscrive più: da qui si aggiorna a mano.

## Immagini di partenza (passo 1)

| File | Stato | Note |
|---|---|---|
| `partenze/bradipo_spada.png` | da fare | |
| `partenze/bradipo_pistola.png` | da fare | |
| `partenze/bradipo_lancia.png` | da fare | |
| `partenze/bradipo_martello.png` | da fare | |
| `partenze/elvedeo_spada.png` | da fare | |
| `partenze/elvedeo_pistola.png` | da fare | |
| `partenze/elvedeo_lancia.png` | da fare | |
| `partenze/elvedeo_martello.png` | da fare | |
| `partenze/marcomunista_spada.png` | da fare | |
| `partenze/marcomunista_pistola.png` | da fare | |
| `partenze/marcomunista_lancia.png` | da fare | |
| `partenze/marcomunista_martello.png` | da fare | |
| `partenze/egiainuso_spada.png` | da fare | |
| `partenze/egiainuso_pistola.png` | da fare | |
| `partenze/egiainuso_lancia.png` | da fare | |
| `partenze/egiainuso_martello.png` | da fare | |

## Ondata 1: Bradipo Giallo

| Codice | Clip | Stato | Tentativi | Modello | Crediti | Commento con l'mp4 | Note |
|---|---|---|---|---|---|---|---|
| BR-01 | Fermo | tagliata | 2 | | | in chat il 3/11 (prova) | tentativo 1 tenuto; taglio a mano di turn e skid in `flow_tagli.json`; stati in `bradipo/in-attesa/` |
| BR-02 | Salti | da fare | | | | | |
| BR-03 | Attacchi in corsa | da fare | | | | | |
| BR-04 | Aerei A | tagliata | 1 | | | in chat il 4/11 (passo 0) | tenuta (Riccardo, 4/11): arco bianco e polvere tolti con `--pulisci`; l'aereo avanti è più su e giù che in avanti |
| BR-05 | Aerei B | da fare | | | | | |
| BR-06 | Recupero | da fare | | | | | |
| BR-07 | Presa | da fare | | | | | |
| BR-08 | Lanci A | da fare | | | | | |
| BR-09 | Lanci B | da fare | | | | | |
| BR-10 | Guardia | da fare | | | | | |
| BR-11 | Difesa | da fare | | | | | |
| BR-12 | A terra A | da fare | | | | | |
| BR-13 | A terra B | da fare | | | | | |
| BR-14 | Bordo | da fare | | | | | |
| BR-A1 | Spada: movimento | da fare | | | | | |
| BR-A2 | Spada: attacchi | da fare | | | | | |
| BR-A3 | Pistola: movimento | da fare | | | | | |
| BR-A4 | Pistola: attacchi | da fare | | | | | |
| BR-A5 | Lancia: movimento | da fare | | | | | |
| BR-A6 | Lancia: attacchi | da fare | | | | | |
| BR-A7 | Lancia: lancio | da fare | | | | | |
| BR-A8 | Martello | da fare | | | | | |

## Ondata 2: Elvedeo

| Codice | Clip | Stato | Tentativi | Modello | Crediti | Commento con l'mp4 | Note |
|---|---|---|---|---|---|---|---|
| EL-01 | Fermo | da fare | | | | | |
| EL-02 | Salti | da fare | | | | | |
| EL-03 | Attacchi in corsa | da fare | | | | | |
| EL-04 | Aerei A | da fare | | | | | |
| EL-05 | Aerei B | da fare | | | | | |
| EL-06 | Recupero | da fare | | | | | |
| EL-07 | Presa | da fare | | | | | |
| EL-08 | Lanci A | da fare | | | | | |
| EL-09 | Lanci B | da fare | | | | | |
| EL-10 | Guardia | da fare | | | | | |
| EL-11 | Difesa | da fare | | | | | |
| EL-12 | A terra A | da fare | | | | | |
| EL-13 | A terra B | da fare | | | | | |
| EL-14 | Bordo | da fare | | | | | |
| EL-A1 | Spada: movimento | da fare | | | | | |
| EL-A2 | Spada: attacchi | da fare | | | | | |
| EL-A3 | Pistola: movimento | da fare | | | | | |
| EL-A4 | Pistola: attacchi | da fare | | | | | |
| EL-A5 | Lancia: movimento | da fare | | | | | |
| EL-A6 | Lancia: attacchi | da fare | | | | | |
| EL-A7 | Lancia: lancio | da fare | | | | | |
| EL-A8 | Martello | da fare | | | | | |

## Ondata 3: Marcomunista

| Codice | Clip | Stato | Tentativi | Modello | Crediti | Commento con l'mp4 | Note |
|---|---|---|---|---|---|---|---|
| MA-01 | Fermo | da fare | | | | | |
| MA-02 | Corsa | da fare | | | | | |
| MA-03 | Salto | da fare | | | | | |
| MA-04 | Leggeri A | da fare | | | | | |
| MA-05 | Leggeri B | da fare | | | | | |
| MA-06 | Attacchi in corsa | da fare | | | | | |
| MA-07 | Pesanti A | da fare | | | | | |
| MA-08 | Pesanti B | da fare | | | | | |
| MA-09 | Aerei A | da fare | | | | | |
| MA-10 | Aerei B | da fare | | | | | |
| MA-11 | Aerei C | da fare | | | | | |
| MA-12 | Speciali A | da fare | | | | | |
| MA-13 | Speciali B | da fare | | | | | |
| MA-14 | Suprema | da fare | | | | | |
| MA-15 | Presa | da fare | | | | | |
| MA-16 | Lanci | da fare | | | | | |
| MA-17 | Colpito | da fare | | | | | |
| MA-18 | Difesa | da fare | | | | | |
| MA-19 | A terra A | da fare | | | | | |
| MA-20 | A terra B | da fare | | | | | |
| MA-21 | Bordo | da fare | | | | | |
| MA-A1 | Spada: movimento | da fare | | | | | |
| MA-A2 | Spada: attacchi | da fare | | | | | |
| MA-A3 | Pistola: movimento | da fare | | | | | |
| MA-A4 | Pistola: attacchi | da fare | | | | | |
| MA-A5 | Lancia: movimento | da fare | | | | | |
| MA-A6 | Lancia: attacchi | da fare | | | | | |
| MA-A7 | Lancia: lancio | da fare | | | | | |
| MA-A8 | Martello | da fare | | | | | |

## Ondata 4: Egiainuso

| Codice | Clip | Stato | Tentativi | Modello | Crediti | Commento con l'mp4 | Note |
|---|---|---|---|---|---|---|---|
| EG-01 | Fermo | da fare | | | | | |
| EG-02 | Corsa | da fare | | | | | |
| EG-03 | Salto | da fare | | | | | |
| EG-04 | Leggeri A | da fare | | | | | |
| EG-05 | Leggeri B | da fare | | | | | |
| EG-06 | Attacchi in corsa | da fare | | | | | |
| EG-07 | Pesanti A | da fare | | | | | |
| EG-08 | Pesanti B | da fare | | | | | |
| EG-09 | Aerei A | da fare | | | | | |
| EG-10 | Aerei B | da fare | | | | | |
| EG-11 | Aerei C | da fare | | | | | |
| EG-12 | Speciali A | da fare | | | | | |
| EG-13 | Speciali B | da fare | | | | | |
| EG-14 | Suprema | da fare | | | | | |
| EG-15 | Presa | da fare | | | | | |
| EG-16 | Lanci | da fare | | | | | |
| EG-17 | Colpito | da fare | | | | | |
| EG-18 | Difesa | da fare | | | | | |
| EG-19 | A terra A | da fare | | | | | |
| EG-20 | A terra B | da fare | | | | | |
| EG-21 | Bordo | da fare | | | | | |
| EG-A1 | Spada: movimento | da fare | | | | | |
| EG-A2 | Spada: attacchi | da fare | | | | | |
| EG-A3 | Pistola: movimento | da fare | | | | | |
| EG-A4 | Pistola: attacchi | da fare | | | | | |
| EG-A5 | Lancia: movimento | da fare | | | | | |
| EG-A6 | Lancia: attacchi | da fare | | | | | |
| EG-A7 | Lancia: lancio | da fare | | | | | |
| EG-A8 | Martello | da fare | | | | | |

## Pacchetto base

Prompt in [`base.md`](base.md). Immagine = `riferimenti/personaggi/<id>.png`.

| Codice | Clip | Stato | Tentativi | Modello | Crediti | Commento con l'mp4 | Note |
|---|---|---|---|---|---|---|---|
| GF-IMG | Giovanni fRana: immagine di partenza | da fare | | Nano Banana | 0 | | |
| GF-B1 | Giovanni fRana: Movimento | da fare | | Veo 3.1 Lite | | | |
| GF-B2 | Giovanni fRana: Colpi | da fare | | Veo 3.1 Lite | | | |
| LE-IMG | Lendmar: immagine di partenza | fatta | 1 | Nano Banana | 0 | | dal foglio di Marco in #536, col fez |
| LE-B1 | Lendmar: Movimento | nel gioco | 1 | Veo 3.1 Lite | 10 | | progetto Flow "nov 04 - 17:56"; in alto il video taglia la testa: salto e caduta accorciati in flow_tagli.json |
| LE-B2 | Lendmar: Colpi | nel gioco | 1 | Veo 3.1 Lite | 10 | | Veo ha fatto un pugno solo invece di due colpi: leggero e pesante sono lo stesso pugno; poi cade a terra (non usato) |
| OB-IMG | Capt. OrsoBlu: immagine di partenza | fatta | | Nano Banana | 0 | | |
| OB-B1 | Capt. OrsoBlu: Movimento | nel gioco | 2 | Veo 3.1 Lite | 10 | | progetto Flow "nov 03 - 23:37"; il primo tentativo è fallito ("fornitori di contenuti di terze parti", rimborsato). Presi idle, walk, jumpSquat e land; jump e fall restano di OB-03 perché in cima al salto la testa esce dal bordo |
| OB-B3 | Capt. OrsoBlu: colpi in alto e in basso | nel gioco | 1 | Veo 3.1 Lite | 10 | | lightUp, lightDown, heavyDown; tolti a mano i fotogrammi col braccio fermo, che allungavano i colpi |
| OB-B4 | Capt. OrsoBlu: colpi in aria | nel gioco | 3 | Veo 3.1 Lite | 10 | | due tentativi falliti ("fornitori di contenuti di terze parti", rimborsati); lightAir e heavyAir, PR #570 |
| OB-B2 | Capt. OrsoBlu: Colpi | nel gioco | 1 | Veo 3.1 Lite | 10 | | progetto Flow "nov 03 - 23:37"; il pesante è un pugno lungo tenuto teso (non la spallata del prompt), tagliato in flow_tagli.json |
| MA-IMG | Marcomunista: immagine di partenza | fatta | | Nano Banana | 0 | | |
| MA-B1 | Marcomunista: Movimento | da fare | | Veo 3.1 Lite | | | |
| MA-B2 | Marcomunista: Colpi | da fare | | Veo 3.1 Lite | | | |
| LA-IMG | Lampione: immagine di partenza | da fare | | Nano Banana | 0 | | |
| LA-B1 | Lampione: Movimento | da fare | | Veo 3.1 Lite | | | |
| LA-B2 | Lampione: Colpi | da fare | | Veo 3.1 Lite | | | |
| DM-IMG | Dr. Micelium: immagine di partenza | da fare | | Nano Banana | 0 | | |
| DM-B1 | Dr. Micelium: Movimento | da fare | | Veo 3.1 Lite | | | |
| DM-B2 | Dr. Micelium: Colpi | da fare | | Veo 3.1 Lite | | | |
| EM-IMG | Electronmaster: immagine di partenza | da fare | | Nano Banana | 0 | | |
| EM-B1 | Electronmaster: Movimento | da fare | | Veo 3.1 Lite | | | |
| EM-B2 | Electronmaster: Colpi | da fare | | Veo 3.1 Lite | | | |
| NG-IMG | Nonna Gina: immagine di partenza | da fare | | Nano Banana | 0 | | |
| NG-B1 | Nonna Gina: Movimento | da fare | | Veo 3.1 Lite | | | |
| NG-B2 | Nonna Gina: Colpi | da fare | | Veo 3.1 Lite | | | |
| OP-IMG | Maestro Opus: immagine di partenza | da fare | | Nano Banana | 0 | | |
| OP-B1 | Maestro Opus: Movimento | da fare | | Veo 3.1 Lite | | | |
| OP-B2 | Maestro Opus: Colpi | da fare | | Veo 3.1 Lite | | | |
| BB-IMG | Bonobot: immagine di partenza | da fare | | Nano Banana | 0 | | |
| BB-B1 | Bonobot: Movimento | da fare | | Veo 3.1 Lite | | | |
| BB-B2 | Bonobot: Colpi | da fare | | Veo 3.1 Lite | | | |

## Qualità

Cosa è venuto peggio del resto o dove si è scesi a compromessi, una riga per problema. Si aggiunge in ogni PR del flusso (come, nel [README](README.md#qualità-passo-fisso)); una riga risolta resta, con `risolto in #NNN`.

| Clip | Cosa è venuto peggio o il compromesso | Perché si è accettato | Come si rimedia |
|---|---|---|---|
| prova Bonobot (3/11) | Con 3 attacchi di fila resta col braccio teso e non torna nella posa: lo script non trova le pause. Clip scartata. | Era una prova. | Regola: massimo 2 attacchi per clip, con "snaps out and is pulled straight back". Il passo 0 (`BR-04`) dice se basta, se no un attacco per clip (circa 140 clip invece di 102). |
| BR-01 tentativo 2 (#541) | Non si ferma fra la seconda e la terza mossa: provocazione e `turn+skid` sono tagliati dai secondi previsti, non dalle pause. | Il tentativo 1 della stessa clip si divide da solo nelle 3 mosse. | Per l'ondata 1 tenere il tentativo 1; se serve il 2, fissare i fotogrammi in `tools/sprite/flow_tagli.json`. |
| BR-01 (#541) | `turn+skid` sta in una mossa sola e viene diviso a metà: il confine fra girarsi e frenare è approssimato. | Veo non fa una pausa fra due stati così corti. | Guardare il foglio al taglio vero e correggere in `flow_tagli.json`. |
| BR-01 (#541) | Scala calcolata 0,420 dall'`idle.png` del gioco; il taglio a mano di Bradipo usava 0,38. Le strisce nuove potrebbero sembrare un po' più grandi o più piccole di quelle vecchie, se si mescolano. | La scala dal fermo del gioco è la stessa per tutte le clip, quella a mano no. | Confrontare in allenamento al primo taglio dell'ondata 1, prima di mescolare stati vecchi e nuovi. |
| script di taglio (#541) | La polvere attaccata ai piedi non si toglie (quella staccata sì). | Distinguerla dai piedi costa più del rigenerare. | Rigenerare la clip; nel prompt c'è già "no dust". |
| script di taglio (#541) | `hitFrame_proposto` è solo il fotogramma col disegno più lontano dal centro: per alcuni attacchi non è l'impatto. | Va bene come primo valore. | Confermarlo sempre con `zone_dei_colpi.py`. |
| script di taglio (#541) | Despill più forte sui pixel scuri (+2): le mani quasi nere prendevano il riflesso verde, ora i neri possono uscire un filo più spenti. | Meglio un nero spento che un nero verdastro. | Se si nota in gioco, abbassare il valore solo per quel personaggio. |
| piano (#540) | Bradipo nelle clip di Flow non usa il basso: scudo e leggero laterale sono con gli artigli, diversi dalla skin "Bassista". | Così basta un'immagine di partenza sola. | Se il gruppo li vuole col basso, una clip di riparazione con un'immagine di partenza col basso. |
| piano (#540) | La posa di partenza senza arma è il fermo del gioco ingrandito, quindi meno definita di un disegno nuovo. | La prova del 3/11 ha mostrato che a Veo basta. | Se un personaggio esce sfocato o diverso, generare un'immagine di partenza nuova (passo 1 senza arma). |
| piano (#540) | I prompt delle armi arrivano a circa 4.000 caratteri contro i 2.500 provati: Flow potrebbe tagliarli o ignorarne una parte. | Non ancora provati. | La prima clip d'arma lo dice; nel caso si accorciano gli AVOID in `prompt_flow.py`. |
| LE-B1 (base) | In alto il video taglia la testa: salto e caduta sono accorciati in `flow_tagli.json`. | Il resto del movimento è buono. | Rigenerare con più spazio sopra la testa. |
| LE-B2 (base) | Veo ha fatto un pugno solo invece di due colpi: leggero e pesante di Lendmar sono lo stesso pugno. | Meglio un pugno animato che nessuno. | Clip di riparazione col pesante da solo. |
| OB-B1 (base) | `jump` e `fall` restano quelli vecchi di OB-03: in cima al salto la testa esce dal bordo. | Idle, walk, jumpSquat e land sono buoni. | Rigenerare il salto con più spazio sopra. |
| OB-B2 (base) | Il pesante è un pugno lungo tenuto teso, non la spallata del prompt. | Si legge comunque come colpo forte. | Clip di riparazione con la spallata. |
| OB-B3 (base) | Tolti a mano i fotogrammi col braccio fermo, che allungavano i colpi. | Senza, i colpi duravano troppo. | Niente: è il taglio giusto. |
