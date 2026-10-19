## Scheda mosse: Nonna Gina

Proposto da: Claude, per Nicola (#384, esempio del flusso completo)  ·  Disegna i fotogrammi: scheletro (`tools/rig/genera_pezzi_lottatore.py` e `tools/rig/animazioni_nonnagina.py`)
Carattere in una riga: la nonna di Cologna Veneta che alla domenica dà da mangiare a tutto il Cuamm; curva e lenta, ma col mattarello non perdona
Peso: pesante  ·  Scia del colpo: legno del mattarello (`#e0ae74`)

**Storia.** Gina ha cresciuto tre figli, sette nipoti e mezzo collegio. Quando sente che "i ragazzi del Discord" fanno a botte, prende il mattarello, si mette le ciabatte buone e arriva. Non vuole vincere: vuole che mangiate. Battute: provoca con *"Mangia che ti fa bene!"*, va KO con *"Ostrega!"*, vince con *"Ti go fato el brodo"*.

**Aspetto.** Chignon grigio, occhiali, golfino viola, gonna blu, grembiule bianco col taschino, calze color carne, ciabatte rosse. Nella mano vicina tiene sempre il mattarello, che allunga i suoi colpi.

**Statistiche** (1 = Bonobot): peso 1,15 · corsa 0,85 · aria 0,95 · salto 0,9 · gravità 0,95.

### Movimento
| Stato | Cosa fa | Come si distingue |
|---|---|---|
| idle (fermo) | respira curva, il mattarello lungo la gamba | schiena curva in ogni posa |
| walk (camminata) | passi corti, busto in avanti, braccia quasi ferme | la più lenta (0,85), passo più corto |
| dash (corsa) | trotterella piegata in avanti | corsa più bassa e meno slanciata |
| jump (salto) | come i lottatori in piedi | salta poco (0,9) |
| doubleJump (secondo salto) | capriola raccolta | - |
| fall (caduta) | braccia larghe | cade piano (gravità 0,95) |
| land (atterraggio) | si piega sulle ginocchia | - |
| ledge (appeso al bordo) | appesa con le due mani | - |
| climb (risale dal bordo) | risale | - |
| taunt (provocazione) | alza il mattarello e lo agita brontolando | "Mangia che ti fa bene!" nel fumetto |

### Attacchi
| Stato | Cosa fa | Come si distingue | Tempi (avvio/attivo/recupero ms) | Zona |
|---|---|---|---|---|
| light (leggero) | tira indietro il mattarello sopra la spalla e lo spinge di punta | più lungo (+23%) e un po' più lento (+25%), 6% | 50 / 100 / 280 | range 64 |
| lightUp (leggero in alto) | il mattarello passa sopra la testa | come tutti | - | - |
| lightDown (leggero in basso) | spazzata bassa col mattarello | come tutti, ma il mattarello allunga la posa | - | - |
| lightAir (leggero in aria) | rovescio col mattarello | come tutti | - | - |
| heavy (pesante, si carica) | sulle punte col mattarello dietro la testa, pausa, mattarellata a due mani | più lento (+23%), più lungo e alto, 15% e spinge di più | 320 / 120 / 860 | range 84, height 54 |
| heavyUp (pesante in alto) | mattarello al cielo | come tutti | - | - |
| heavyDown (pesante in basso) | si butta avanti e fa rotolare il mattarello radente | arriva lontanissimo (+18%), 13% | 280 / 140 / 760 | range 104 |
| heavyAir (pesante in aria) | mattarellata in aria | come tutti | - | - |
| dashAttack (pesante in corsa) | la posa della mattarellata | come tutti | - | - |

### Speciali e suprema
| Stato | Cosa fa | Come si distingue |
|---|---|---|
| specialNeutral (speciale) | **Polpetta**: la prende dal grembiule e la lancia ad arco dal basso | tiro ad arco, due in volo insieme |
| specialSide (speciale di lato) | **Ciabatta**: se la sfila e la tira dritta, di braccio | dritta e velocissima, 9% |
| specialDown (speciale in basso) | **Mangia!**: para col mattarello di traverso e risponde con una botta | contrattacco che allontana molto |
| recovery (speciale in alto, recupero) | il salto di recupero di tutti | - |
| supreme (suprema) | **Pranzo della domenica**: tre bracciate di polpette da tutte e due le parti | 15 polpette ad arco tutto intorno |

### Difesa e prese
| Stato | Cosa fa | Come si distingue |
|---|---|---|
| shield (scudo) | lo scudo di tutti | - |
| grab (presa) | afferra con le due mani | - |
| throw (lancio) | i quattro lanci di tutti | - |
| grabbed (preso) | si dimena | - |

### Colpito
| Stato | Cosa fa | Come si distingue |
|---|---|---|
| hit (colpito) | piegata all'indietro | pesante: vola meno degli altri |
| tumble (vola via) | gira su se stessa | - |
