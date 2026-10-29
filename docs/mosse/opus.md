## Scheda mosse: Maestro Opus

Proposto da: Claude, per Davide ("crea un personaggio tuo")  ·  Disegna i fotogrammi: scheletro (`tools/rig/genera_pezzi_opus.py`, `tools/rig/animazioni_opus.py`, oggetti e ritratto in `tools/rig/genera_oggetti_opus.py`)
Carattere in una riga: un bonobo piccoletto e pieno di sé che dirige l'orchestra, e combatte dirigendo
Peso: leggero  ·  Scia del colpo: la punta d'oro della bacchetta (`#ffd77a`)

**Storia.** Opus ha diretto una sola sinfonia in vita sua, ma ne parla come se fossero cento. Si presenta in frac con le code, panciotto e farfallino bianchi, il garofano rosso all'occhiello e la criniera bianca alla Beethoven; le scarpe no, i piedi da bonobo non ci stanno. La bacchetta è enorme e ha la punta d'oro. Sta benissimo nella Sala Prove (`docs/arena-musicale.md`). Battute: provoca con *"Grazie, grazie, troppo gentili!"*, va KO con *"Che stonatura!"*, vince con *"Bis! Bis!"*, lancia la suprema con *"Gran Finale!"*.

**Statistiche** (1 = Bonobot): peso 0,85 · corsa 1,08 · aria 1,12 · salto 1,15 · gravità 0,88. Il più svolazzante del roster: salta alto e cade piano, ma vola via presto.

### Movimento
| Stato | Cosa fa | Come si distingue |
|---|---|---|
| idle (fermo) | petto in fuori e mento su, tiene il tempo con la bacchetta (quattro battute), la sinistra sul fianco | la bacchetta batte, le code del frac ondeggiano |
| walk (camminata) | passetti svelti e impettiti, la bacchetta batte a ogni passo | dirige anche camminando |
| dash (corsa) | piegato in avanti, la bacchetta puntata come una lancia | criniera e code al vento |
| jump (salto) | si raccoglie e si allunga con la bacchetta al cielo | salta alto (1,15) |
| doubleJump (secondo salto) | piroetta a corpo raccolto con la bacchetta tesa | - |
| fall (caduta) | a braccia aperte, come se dirigesse la caduta | cade piano (gravità 0,88), code e criniera salgono |
| land (atterraggio) | si schiaccia e si raddrizza col mento su | - |
| ledge, climb (bordo) | le pose dei lottatori in piedi | - |
| taunt (provocazione) | un giro di bacchetta, poi l'inchino a 90 gradi al pubblico; resta giù a raccogliere gli applausi | "Grazie, grazie, troppo gentili!" |

### Attacchi normali (la bacchetta allunga tutti i colpi: le zone sono dove arriva la punta)
| Stato | Cosa fa | Come si distingue | Tempi (avvio/attivo/recupero ms) | Zona |
|---|---|---|---|---|
| light (leggero) | stoccata: la tira indietro vicino all'orecchio e la scocca dritta in avanti | più lungo (range 67), recupero più svelto, 4% | 40 / 100 / 250 | range 67 |
| lightUp | dal basso la bacchetta passa sopra la testa e punta il cielo | - | - | - |
| lightDown | giù su un ginocchio, bacchettata alle caviglie | arriva lontano (78) | - | range 78 |
| lightAir | rovescio in aria da dietro la spalla | - | - | - |
| heavy ("Fortissimo") | in punta di piedi con la bacchetta a due mani dietro la testa, una pausa, giù di peso | parte prima (230 ms) ma fa meno male, 12% | 230 / 120 / 720 | - |
| heavyUp ("Crescendo") | accucciato con la bacchetta tra le ginocchia, poi su dritto a braccia tese | - | - | - |
| heavyDown | spaccata alla Fred Astaire: bacchetta radente davanti, l'altra mano spazza dietro | colpisce dai due lati | - | - |
| heavyAir | il Fortissimo in aria | - | - | - |
| recovery | sale avvitandosi come un ballerino, bacchetta al cielo | - | - | - |

### Speciali e suprema
| Stato | Tipo | Cosa fa | Come si distingue |
|---|---|---|---|
| specialNeutral | proiettile | **Staccato**: alza la bacchetta, la sinistra chiama l'orchestra, gesto secco: parte una coppia di crome d'oro | due note in volo insieme, un po' su e un po' giù a turno; 5% |
| specialSide | scatto | **Glissando**: scivola in avanti su un ginocchio con la bacchetta tesa come un fioretto | basso (la zona sta all'altezza della vita), 9% |
| specialDown | contrattacco | **Fermata**: la mano aperta in avanti ("silenzio!"), occhi chiusi e mento su; chi lo colpisce nella pausa si prende il "tutti" | finestra di 420 ms, risposta ×1,35 |
| supreme | caduta dall'alto ("drop", come Omar) | **Gran Finale**: salta alla liana, la tira, capriola all'indietro, alza la bacchetta... e cade un pianoforte a coda. All'impatto il colpo di bacchetta più grande della sua vita, poi l'inchino. Dal puff scappa un pianoforte piccolo coi denti di tasti | tempi e numeri della suprema di Omar |

### Difesa e prese
| Stato | Cosa fa |
|---|---|
| shield (scudo) | accucciato, la bacchetta di traverso davanti alla faccia, occhi strizzati |
| grab, throw | si allunga con le due mani e tira a sé; i lanci di tutti |
| grabbed | si dimena |

### Colpito
| Stato | Cosa fa |
|---|---|
| hit | indietro col mento, bocca aperta, la criniera frusta in avanti e la bacchetta vola su |
| tumble | rotola con le code del frac all'aria |

### Rifarlo
```bash
python3 tools/rig/genera_pezzi_opus.py         # pezzi e rig.json
python3 tools/rig/animazioni_opus.py           # dopo npm run export:godot: legge i tempi da godot/data/game.json
python3 tools/rig/rendi_sprite.py public/assets/characters/opus/rig public/assets/characters/opus/rig/animazioni.json public/assets/characters/opus
python3 tools/rig/genera_oggetti_opus.py       # note, pianoforte e il ritratto da vicino (dopo rendi_sprite.py)
npm run export:godot
python3 tools/sprite/zone_dei_colpi.py opus    # se cambiano le pose: zone e hurtbox da ricopiare in characters.ts
```
