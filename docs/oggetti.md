# Oggetti e potenziamenti

Idee per gli oggetti che cadono dall'alto (come le Poké Ball di Smash Brawl), ispirate ai giochi
preferiti del gruppo, **The Binding of Isaac** e **League of Legends**, con un filo verde che li lega:
l'erba. Richiesta di Nicola, 13 ottobre 2026.

Come funzionano già gli oggetti (#17, #231): ogni tanto uno cade dal cielo su un pezzo dell'arena,
si raccoglie con J o K e si lancia con J o K (su = in alto, giù = posalo). Quelli "da consumare" (il
fiore) danno subito un potenziamento. Logica in `src/shared/physics/items.ts`, catalogo in
`src/shared/items.ts`, numeri in `constants.ts`, disegno e suoni in `godot/scripts/`.

Tutti i nomi sono provvisori: `// TODO community` finché il canale non li sceglie.

## Già nel gioco

| Oggetto | Cosa fa |
| --- | --- |
| Banana | Si lancia, colpisce chi tocca. |
| Fiore (#231) | Si consuma: 8 s intoccabili, colpi ×1,3, passo lento. |
| **Bong** (#303) | Tre fasi, sotto. |
| Funghetti di Teemo (#317) | Giù + J pianta funghetti quasi invisibili: chi li calpesta ha i comandi invertiti per 3 s. |
| **Birra** (idea di Nicola) | Cappello da tirolese per 8 s: colpi ×1,4, un po' più veloci, ma si barcolla avanti e indietro. |
| **Tetris** (#427, idea di Nicola) | Ci si assenta per 9 s in un cabinato, fermi e intoccabili: i tasti guidano pezzi che cadono dall'alto (destra/sinistra spostano, su/salto/J ruotano, giù accelera, K li fa cadere di colpo). Il pezzo compare sopra l'avversario più vicino, con l'ombra di dove si poserà, e attraversa le piattaforme sottili. Colpisce chi tocca (12%, 18% se fatto cadere con K); posato, diventa blocchi solidi per 10 s. Sei blocchi in fila alla stessa altezza fanno una **riga**: esplode e lancia in alto chi ci sta sopra (16%). Tra un pezzo e il prossimo passano 0,8 s. Logica in `physics/arcade.ts`. |
| **Pac-Man** (#427, idea di Nicola) | Per 8 s si è Pac-Man: niente gravità, si va sempre dritti nella direzione dell'ultima freccia premuta, attraverso muri e pavimenti, e chi esce da un lato dello schermo rientra dall'altro. Intoccabili; chi si tocca viene mangiato (14% e lancio, poi 1,2 s di respiro). Gli altri diventano fantasmini e compaiono le palline (solo disegno). |

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
- Un evento nuovo o un campo nuovo dello snapshot è un cambio di protocollo: titolo `Protocollo: ...`.
- Il predittore del client (E17) torna allo stato del server quando c'è un potenziamento: un effetto
  che cambia il movimento va bene, ma va scritto in `predictor.gd` se cambia anche senza potenziamento.
