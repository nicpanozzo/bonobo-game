# Scheda mosse di un lottatore

Modello da copiare e riempire con chi ha proposto il personaggio (#384, passo D1). Serve a dare a ogni lottatore mosse **sue**: chi anima sa che posa disegnare, chi programma sa quali tempi e zone ritoccare.

**Come si usa**
1. Copia il blocco qui sotto in un commento dell'issue del personaggio (o in un file `docs/mosse/<id>.md`).
2. Per ogni stato scrivi **cosa fa** (la posa, l'oggetto che usa) e **come si distingue** dagli altri: più lento ma più forte, più lungo, più rapido, in un'altra direzione.
3. Le colonne *Tempi* e *Zona* sono facoltative: se le lasci vuote valgono quelle di tutti (`ATTACKS` in `src/shared/constants.ts`). I ritocchi restano entro ±30% dei tempi comuni (passo D2).
4. Chi disegna i fotogrammi segue la guida "Animare come Smash" in [stile-grafico.md](stile-grafico.md#animare-come-smash-384).

Le mosse già scritte nelle schede della community (speciali, supreme, battute) **restano**: la scheda le riprende, non le sostituisce.

---

```markdown
## Scheda mosse: <nome del lottatore>

Proposto da: <chi>  ·  Disegna i fotogrammi: <chi, oppure "scheletro">
Carattere in una riga: <es. allenatore urlante, lento ma pesante>
Peso: leggero / medio / pesante  ·  Scia del colpo: <colore o forma, es. "fischio giallo">

### Movimento
| Stato | Cosa fa | Come si distingue |
|---|---|---|
| idle (fermo) | | |
| walk (camminata) | | |
| dash (corsa) | | |
| jump (salto) | | |
| doubleJump (secondo salto) | | |
| fall (caduta) | | |
| land (atterraggio) | | |
| ledge (appeso al bordo) | | |
| climb (risale dal bordo) | | |
| taunt (provocazione) | | |

### Attacchi
| Stato | Cosa fa | Come si distingue | Tempi (avvio/attivo/recupero ms) | Zona |
|---|---|---|---|---|
| light (leggero) | | | | |
| lightUp (leggero in alto) | | | | |
| lightDown (leggero in basso) | | | | |
| lightAir (leggero in aria) | | | | |
| heavy (pesante, si carica) | | | | |
| heavyUp (pesante in alto) | | | | |
| heavyDown (pesante in basso) | | | | |
| heavyAir (pesante in aria) | | | | |
| dashAttack (pesante in corsa) | | | | |

### Speciali e suprema
| Stato | Cosa fa | Come si distingue |
|---|---|---|
| specialNeutral (speciale) | | |
| specialSide (speciale di lato) | | |
| specialDown (speciale in basso) | | |
| recovery (speciale in alto, recupero) | | |
| supreme (suprema) | | |

### Difesa e prese
| Stato | Cosa fa | Come si distingue |
|---|---|---|
| shield (scudo) | | |
| grab (presa) | | |
| throw (lancio) | | |
| grabbed (preso) | | |

### Colpito
| Stato | Cosa fa | Come si distingue |
|---|---|---|
| hit (colpito) | | |
| tumble (vola via) | | |
```

---

**Esempio di riga ben scritta**

| Stato | Cosa fa | Come si distingue |
|---|---|---|
| heavy (pesante) | Coach Cartier carica il fischietto e soffia: onda d'urto davanti | più lento di tutti (+30% avvio), zona più lunga, la scia è un cerchio giallo |
