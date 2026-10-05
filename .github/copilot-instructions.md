# Istruzioni per GitHub Copilot

Le regole del progetto sono in [AGENTS.md](../AGENTS.md) nella radice della repo: leggile e seguile, sono le stesse per tutti gli agenti.

In breve: prima di scrivere codice apri una PR in bozza con il piano, poi pusha presto e spesso (git è il modo in cui gli agenti si parlano); mai pushare su `main`; un compito = un'issue = un branch `<nome>/<cosa-fai>` = una PR; il server è l'arbitro e la logica di gioco sta in `src/shared/physics.ts`; i numeri stanno in `src/shared/constants.ts`; il protocollo in `src/shared/types.ts` si cambia solo in PR dedicate; niente refactor fuori dal perimetro del compito; `npm run typecheck` e `npm run build` devono passare.
