# Combo per personaggio

Le combo sono dati in `src/shared/characters.ts` (`combos`), fatte solo di mosse già disegnate. I numeri comuni sono in `COMBO` (`src/shared/constants.ts`).

```ts
combos: [{ name: "Uomo in mare", steps: [{ move: "heavy", windowMs: 400 }, { move: "specialNeutral", windowMs: 400 }, { move: "light" }] }]
```

- Il colpo di un passo che entra apre la finestra del passo dopo (`windowMs` dopo la fine della mossa, sennò `COMBO.windowMs`): in quella finestra la mossa dopo parte senza aspettare l'attesa del colpo.
- `angleDeg` e `knockbackMult` ritoccano il lancio di quel passo. Sul primo passo valgono ogni volta che quella mossa entra: meglio lasciarlo senza ritocchi quando si può.
- Un proiettile può chiudere una combo, non aprirla né continuarla. La presa non è un passo, i lanci sì.
- La combo di leggeri e le combo di #557 (Arrembaggio, Piano quinquennale, Groove, Scivolone, Capra e cavaliere) restano regole a parte.

## Laboratorio

`npm run combo-lab` (i 5 del nucleo) o `npm run combo-lab -- <id>` prova con la fisica vera ogni coppia di mosse a ogni percentuale e riscrive `docs/combo/<id>.md`: le combo del personaggio con le percentuali a cui sono vere, le coppie che legano, le catene che non finiscono mai e le **clip che servono**. Dopo aver cambiato una combo o i numeri di un colpo, rilancialo.

Per trovare una combo nuova: guarda in `<id>.md` le coppie che entrano "solo se non reagisce", scrivile in `combos` e rilancia il laboratorio: spesso basta la finestra, che toglie l'attesa.
