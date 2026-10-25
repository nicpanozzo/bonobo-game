# Oggetti e potenziamenti

Idee per gli oggetti che cadono dall'alto (come le Poké Ball di Smash Brawl), ispirate ai giochi
preferiti del gruppo, **The Binding of Isaac** e **League of Legends**, con un filo verde che li lega:
l'erba. Richiesta di Nicola, 13 ottobre 2026.

Come funzionano già gli oggetti (#17, #231): ogni tanto uno cade dal cielo su un pezzo dell'arena,
si raccoglie con J o K e si lancia con J o K (su = in alto, giù = posalo). Quelli "da consumare" (il
fiore) danno subito un potenziamento. Logica in `src/shared/physics/items.ts`, catalogo in
`src/shared/items.ts`, numeri in `constants.ts`, disegno e suoni in `godot/scripts/`.

Tutti i nomi sono provvisori: `// TODO community` finché il canale non li sceglie.

## Quanto spesso cadono

Ogni oggetto ha una **classe di frequenza** proporzionata a quanto cambia la partita (Nicola, 24 ottobre
2026): più è forte, più è raro. Il campo `rarity` in `src/shared/items.ts` è obbligatorio, i pesi sono in
`ITEM_RARITY` (`constants.ts`).

| Classe | Peso | Per cosa | Oggetti |
| --- | --- | --- | --- |
| comune | 8 | piccolo vantaggio, da lanciare | Banana |
| normale | 4 | vantaggio a tempo o con un rischio | Fungo di Teemo, Bong |
| raro | 2 | cambia uno scontro | Fiore, Chiama Bassanese |
| rarissimo | 1 | cambia la partita per diversi secondi | Tetris, Pac-Man |
| mai | 0 | non cade dal cielo | Funghetto piantato, Funghetti (messi da parte, #419) |

## Già nel gioco

| Oggetto | Cosa fa |
| --- | --- |
| Banana | Si lancia, colpisce chi tocca. |
| Fiore (#231) | Si consuma: 8 s intoccabili, colpi ×1,3, passo lento. |
| **Bong** (#303) | Tre fasi, sotto. |
| **Fungo di Teemo** (#419, idea di Riccardo) | Sotto. Ha preso il posto dei Funghetti nel cielo. |
| Funghetti di Teemo (#317), **messi da parte** | Non cadono più (#419): il codice resta, per riaverli basta `rarity: "normale"` in `items.ts`. Col sacchetto in mano J pianta un funghetto quasi invisibile ai piedi, J + direzione lo lancia e si pianta dove cade, K molla il sacchetto. Chi li calpesta ha i comandi invertiti per 3 s. |
| **Tetris** (#427, idea di Nicola) | Ci si assenta per 9 s in un cabinato, fermi e intoccabili: i tasti guidano pezzi che cadono dall'alto (destra/sinistra spostano, su/salto/J ruotano, giù accelera, K li fa cadere di colpo). Il pezzo compare sopra l'avversario più vicino, con l'ombra di dove si poserà, e attraversa le piattaforme sottili. Colpisce chi tocca (12%, 18% se fatto cadere con K); posato, diventa blocchi solidi per 10 s. Sei blocchi in fila alla stessa altezza fanno una **riga**: esplode e lancia in alto chi ci sta sopra (16%). Tra un pezzo e il prossimo passano 0,8 s. Logica in `physics/arcade.ts`. |
| **Pac-Man** (#427, idea di Nicola) | Per 8 s si è Pac-Man: niente gravità, si va sempre dritti nella direzione dell'ultima freccia premuta, attraverso muri e pavimenti, e chi esce da un lato dell'arena rientra dall'altro. Intoccabili; chi si tocca viene mangiato (14% e lancio, poi 1,2 s di respiro). Gli altri diventano fantasmini e compaiono le palline: ognuna mangiata fa andare un po' più veloce (+1,2%, le grandi valgono 5, fino a 1,8 volte) finché si resta Pac-Man. |
| **Chiama Bassanese** (idea di Nicola) | Un telefono che squilla: chi lo raccoglie chiama il Bassanese, che entra dal lato dell'arena più lontano e la attraversa tutta, di superficie in superficie, col telefono all'orecchio. Su ogni superficie si guarda in giro con un "?" e borbotta ("Dove l'ho messo...?"): cerca qualcosa, ma non si sa cosa. Chi tocca vola via (11%), tranne chi l'ha chiamato e i compagni; arrivato in fondo se ne va. Il giro dura al massimo 15 s: nelle arene grandi cammina più svelto, in quelle piene (Bologna) visita 10 superfici sparse. Logica in `physics/bassanese.ts`, disegno in `bassanese_view.gd`. |

## Il Fungo di Teemo (idea di Riccardo, #419)

Un fungo solo, grande, disegnato come la Trappola velenosa di Teemo in League of Legends: cappello
bulboso quasi a palla, verde oliva puntinato e più scuro sotto, macchie grandi e irregolari magenta, gambo
corto marrone-grigio. Numeri in `FUNGO` (`constants.ts`), oggetto `fungoTeemo` in `items.ts`.

1. **Lancio a pallonetto.** Si raccoglie con J o K e si lancia con K come gli altri (su = in alto, giù =
   posalo ai piedi), ma è pesante: parte più lento e più alto della banana e ricade prima. In volo
   colpisce come la banana (4%), poi cade dritto e si piazza lo stesso.
2. **Si piazza dove atterra** e in 1 s si arma: affonda un po' e **sfuma fino a sparire agli avversari**
   (del tutto dopo 1,8 s). Chi l'ha lanciato (e la sua squadra) lo vede trasparente. Resta 25 s.
3. **Rimbalzo.** Se cade su un fungo già piazzato rimbalza e si posa più avanti, nella direzione del lancio.
4. **Scoppio.** Un avversario che lo tocca lo fa scoppiare in una nube che prende **tutti gli avversari
   vicini**: 8% subito, poi **veleno** per 6 s (+1% ogni mezzo secondo, 12% in tutto) e **rallentati**
   finché dura, come in LoL. Il veleno prende il posto di bong e viaggio; col fiore si è intoccabili.
5. **Grafica.** Il cappello si gonfia e scoppia, la nube verde-viola si allarga a cupola, ribolle e si
   dissolve dal basso; le spore viola schizzano fuori. Chi è avvelenato ha una tinta verde che pulsa a
   ogni scatto, bolle sopra la testa e una nuvoletta che lo segue; nell'HUD una barra verde-viola.

La chiave `fungoTeemo` sta, in ordine alfabetico, dove stava `funghetti`: con lo stesso peso la sequenza
degli oggetti che cadono resta quella di prima, e non cambia i test che contano sul caso (i bot).

## Il Bong (idea di Nicola)

Cade come gli altri, si raccoglie con J o K e si tiene in mano.

1. **Carica.** Tieni premuto **J**: l'acqua gorgoglia e la barra sopra il bong si riempie (1,2 s).
   Se lasci prima, la carica va persa. Se ti colpiscono, il bong ti cade di mano.
2. **Fatto.** Lascia J a bong carico: il bong è finito e tu sei *fatto*. Sei più leggero (la gravità
   ti tira meno, salti più in alto e cadi piano) e vedi la realtà distorta: lo schermo ondeggia e
   cambia colore, sempre di più man mano che passa il tempo. Gli altri ti vedono fumare.
3. **Nuvola.** Premi J o K: soffi una nuvola di fumo a corto raggio davanti a te che colpisce tutti
   quelli dentro. Più aspetti, più fa male (da 12% a 28%) e più lancia lontano.
4. **Troppo fatto.** Se non soffi entro 7 s, crolli: tramortito per 2,5 s, fermo e colpibile come
   quando ti rompono lo scudo.

Con **K** il bong si lancia come la banana (giù + K lo posa), se preferisci tirarlo in testa a qualcuno.

## Prossimi oggetti

Ordinati per quanto valgono rispetto a quanto costano da fare.

| Oggetto | Da dove viene | Cosa fa |
| --- | --- | --- |
| **Funghetti di Teemo** | LoL, Teemo | Raccolti, piazzi 3 funghetti quasi invisibili agli altri. Chi ci passa sopra resta in una nube: piccolo danno nel tempo e **comandi invertiti** per 3 s (il viaggio). |
| **Divano** | LoL, Clessidra di Zhonya | Ti spiaggi sul divano (couch-lock): 2,5 s fermo e intoccabile, poi ti rialzi. Salva da una combo o da un KO sicuro. |
| **Brownie spaziale** | Isaac, le pillole | Lo mangi e non succede niente... per 4 s. Poi sale: un effetto a caso tra buoni e cattivi (più veloce, più forte, gigante, piccolo, comandi invertiti, sonno). Come le pillole di Isaac, l'effetto si scopre solo dopo. |
| **Clipper** | LoL, Incendio (Ignite) | Arma da tenere: J fa una fiammata corta che dà fuoco. Chi brucia prende danno a scatti per 4 s. |
| **Fame chimica** | Isaac, il cibo | Un pacco di patatine o un kebab: −25% di danno subito, ma per 10 s sei più pesante e lento. |
| **Cartina santa** | Isaac, Holy Mantle | Un velo di cartina che annulla del tutto il primo colpo preso. |
| **Collirio** | Isaac, gli occhi rossi | Per 8 s gli attacchi si ricaricano più in fretta (come le lacrime più veloci). |
| **Angelo custode** | LoL, Guardian Angel | Se vai KO entro 20 s, rientri subito dove eri con la stessa percentuale invece di perdere la vita. |

## Oggetti che si compongono

Come gli oggetti di League of Legends, che si costruiscono da componenti, e le trasformazioni di
Isaac (tre oggetti dello stesso gruppo cambiano il personaggio):

- **Componenti:** Cartina, Filtro, Grinder. Cadono come oggetti piccoli e si tengono in tasca (uno
  slot nella scheda del HUD). Con tutti e tre, più un Fiore, ti ritrovi una **Canna**: arma da tenere
  con tre usi, ogni J soffia una nuvola più piccola di quella del bong ma senza il rischio di crollare.
- **Trasformazione "Rasta":** raccogli tre oggetti verdi (Fiore, Bong, Brownie, Canna) nella stessa
  vita e diventi Rasta fino al KO: un salto in più in aria, capelli e colori nuovi.

## Regole per chi aggiunge un oggetto

- La logica è sul server (`physics/items.ts`), deterministica: niente `Math.random`, si usa il
  generatore con seme di `ItemWorld`.
- Numeri in `constants.ts` (un blocco per oggetto, come `BONG`), forma e colore in `items.ts`.
- Ogni oggetto nuovo sceglie la sua classe di frequenza (`rarity`) in base al suo impatto: vedi sopra.
- Un evento nuovo o un campo nuovo dello snapshot è un cambio di protocollo: titolo `Protocollo: ...`.
- Il predittore del client (E17) torna allo stato del server quando c'è un potenziamento: un effetto
  che cambia il movimento va bene, ma va scritto in `predictor.gd` se cambia anche senza potenziamento.
