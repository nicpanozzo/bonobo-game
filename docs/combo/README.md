# Combo per personaggio

Le combo sono dati in `src/shared/characters.ts` (`combos`), fatte solo di mosse già disegnate. I numeri comuni sono in `COMBO` (`src/shared/constants.ts`).

```ts
combos: [{ name: "Uomo in mare", steps: [{ move: "heavy", windowMs: 400 }, { move: "specialNeutral", windowMs: 400 }, { move: "light" }] }]
```

- Il colpo di un passo che entra apre la finestra del passo dopo (`windowMs` dopo la fine della mossa, sennò `COMBO.windowMs`): in quella finestra la mossa dopo parte senza aspettare l'attesa del colpo.
- `holdMs` tiene il bersaglio stordito almeno quei ms (max `COMBO.maxHoldMs`): serve ai passi di mezzo prima di una speciale lenta. Con `angleDeg: 0` chi è a terra resta a terra e non si rialza al volo.
- `text` è la riga che si legge nel menu di pausa (sezione Combo, coi tasti di ogni colpo in fila).
- `angleDeg` e `knockbackMult` ritoccano il lancio di quel passo. Sul primo passo valgono ogni volta che quella mossa entra: meglio lasciarlo senza ritocchi quando si può.
- Un proiettile può chiudere una combo, non aprirla né continuarla. La presa non è un passo, i lanci sì.
- La combo di leggeri e le combo di #557 (Arrembaggio, Piano quinquennale, Groove, Scivolone, Capra e cavaliere) restano regole a parte. Dall'11/11/2026 tre sono vere come nei picchiaduro di riferimento: il jab spinge quasi in orizzontale chi sta a terra e lo stordisce almeno `JAB.holdMs` (vero a 0-70%, tranne Lampione, dove morde il beagle, ed Elvedeo e Marcomunista, il cui leggero alza); chi è tirato a bordo dall'ancora resta stordito 0,6 s e non si rialza al volo (Arrembaggio vero col jab e con Avanti tutta!); i colpi in aria che rialzano Marcomunista mandano in alto e stordiscono almeno `PIANO_QUINQUENNALE.holdMs` (due colpi in aria veri a 50-120%, la catena intera dal lancio si può evitare).

## Le combo di tutti (11/11/2026)

Ogni personaggio ne ha almeno tre vere. Le percentuali, rifatte dal laboratorio, sono in `<id>.md`. Lo schema che lega quasi sempre: leggero, leggero in giù tenuto a terra (`holdMs: 450, angleDeg: 0`) e una speciale, che dà a ognuno una chiusura sua; poi un giro in su (due leggeri in su) per le percentuali medie e un pesante in su per quelle basse.

## Laboratorio

`npm run combo-lab` (i 5 del nucleo) o `npm run combo-lab -- <id>` prova con la fisica vera ogni coppia di mosse a ogni percentuale e riscrive `docs/combo/<id>.md`: le combo del personaggio con le percentuali a cui sono vere, le coppie che legano, le catene che non finiscono mai e le **clip che servono**. Dopo aver cambiato una combo o i numeri di un colpo, rilancialo.

Per trovare una combo nuova: guarda in `<id>.md` le coppie che entrano "solo se non reagisce", scrivile in `combos` e rilancia il laboratorio: spesso basta la finestra, che toglie l'attesa.
