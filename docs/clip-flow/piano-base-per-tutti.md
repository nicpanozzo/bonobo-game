# Flow: prima una base per tutti, poi si raffina

Proposta per Nicola, 3/11/2026. Si appoggia al metodo di Riccardo (`docs/clip-flow/`, PR #540 unita, script di taglio in #541) e lo riordina: **prima il pacchetto base di ogni personaggio, poi le ondate complete** di #539.

## Il principio

Il guadagno più grande con meno crediti: ogni personaggio passa dal disegno a scheletro (o pixel art) a un disegno vero animato, anche se con poche animazioni. Le altre animazioni arrivano dopo, a giri, partendo da quelle che si vedono in più situazioni.

Funziona perché il gioco ha già i ripieghi (`ANIMATION_FALLBACK` in `characters.ts`): chi non ha `lightUp` usa `light`, chi non ha `doubleJump` usa `jump`, chi non ha `tumble` usa `hit`, e così via. Con le **7 animazioni obbligatorie** (fermo, cammina, salto, caduta, leggero, pesante, colpito) un personaggio copre già tutto il gioco. Quando arriva il pacchetto base si tolgono le vecchie pose a scheletro, come hai fatto con Egiainuso in #542, così non si mescolano due stili.

## Il pacchetto base (per personaggio)

| Passo | Cosa | Crediti |
|---|---|---|
| 0 | Immagine di partenza con Nano Banana, dal disegno di oggi o dai riferimenti di Marco | 0 (le immagini sono gratis) |
| B1 | Clip **Movimento**: `idle`, `walk`, `jumpSquat+jump+fall+land` | 10 (Lite) |
| B2 | Clip **Colpi**: `light`, `heavy`, `hit` | 10 (Lite) |

**20 crediti per personaggio.** Con i 50 giornalieri: **2 personaggi al giorno più 1 clip di riparazione.**
Lite basta per il pacchetto base (personaggio coerente, una mossa su tre a volte va rifatta: la clip di riparazione serve a questo). Fast resta per le mosse difficili.

## L'ordine

| Giorno | Personaggi | Perché |
|---|---|---|
| 1 | **Giovanni fRana**, **Lendmar** | proposte nuove di Marco (#528, #536): i suoi fogli personaggio sono già il riferimento |
| 2 | **Capt. OrsoBlu**, **Marcomunista** | OrsoBlu ha già l'immagine nuova (fatta oggi); Marcomunista oggi ha solo pose ferme |
| 3 | **Lampione**, **Dr. Micelium** | scheletro |
| 4 | **Electronmaster**, **Nonna Gina** | scheletro |
| 5 | **Maestro Opus**, **Bonobot** | scheletro (Bonobot era fuori dal piano di Riccardo finché non c'era un disegno nuovo: questo è il disegno nuovo) |

Bradipo Giallo, Elvedeo ed Egiainuso hanno già le animazioni da Flow: restano come sono fino al giro 2.
Oggi ho già fatto 4 clip di OrsoBlu (ancora, teleferica, marcia e salto, remo e scudo): entrano nel suo giro 2.

## Giro 2: le animazioni che servono in più situazioni

Una clip per personaggio, scelta in base a com'è fatto. Le candidate, dalla più utile:
1. **Corsa** (`dash`): si vede ogni volta che qualcuno corre, cioè sempre.
2. **Speciale firma** (`specialNeutral`): la mossa per cui il personaggio si riconosce.
3. **Provocazione** (`taunt`): poco costosa, tanta personalità.
4. **Scudo e presa** (`shield`, `grab`): situazioni frequenti nei combattimenti veri.

Esempi: Nonna Gina corsa + mattarello + "mangia!", Lampione corsa + tuffo, Opus corsa + crome. Dopo il giro 2 si riprendono le ondate complete di Riccardo (#539), una per personaggio.

## Ogni giorno, in automatico

Una routine ogni mattina alle 9:30 (i crediti giornalieri si azzerano alle 9:00 ora italiana): apre Flow nel tuo Chrome, genera le clip del giorno fino a 50 crediti, controlla la richiesta di conferma prima di ogni generazione, scrive nel foglio di produzione cosa ha fatto e ti manda un riepilogo. Serve Chrome aperto con l'estensione collegata; se non c'è, salta il giorno e te lo dice. I 1.000 crediti mensili non li tocca mai.

## Cosa cambia nella repo

Una PR piccola su `tools/flow/prompt_flow.py`: un set nuovo `base` (B1, B2) e i personaggi nuovi in `CHARS`, con la loro descrizione fissa. Poi si rigenerano `docs/clip-flow/prompt/` e `produzione.md`, e nel README di `docs/clip-flow` una riga sull'ordine nuovo. Il taglio resta lo script di Riccardo (#541).

## Da decidere

- **Giovanni fRana:** nei riferimenti di Marco ci sono almeno tre aspetti diversi (spilungone con gli occhiali di oggi, "barbuto di mare" con la camicia hawaiana, ragazzo con la camicia rossa). Ne serve uno, e Riccardo deve essere d'accordo, visto che è lui.
- **Lendmar:** il riferimento di Marco (#536) va bene come base?
