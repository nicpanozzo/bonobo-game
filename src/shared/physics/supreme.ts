// Barra della suprema (#101): si carica con i danni dati, quelli presi e piano col tempo.
// Piena, il tasto suprema lancia la mossa e la barra torna a 0. La mossa di ogni personaggio
// arriva a parte (Bonobot: #102); finché non c'è, tutti usano ATTACKS.supreme.

import { SUPREME } from "../constants";
import { startAttack } from "./attacks";
import { consume, pressed, type Fighter, type PhysicsContext } from "./fighter";

export const supremeReady = (f: Fighter) => f.supreme >= SUPREME.max;

// Aggiunge carica, senza passare il massimo (negli snapshot viaggia arrotondata per difetto, match.ts)
export function chargeSupreme(f: Fighter, amount: number): void {
  if (amount <= 0 || f.eliminated) return;
  f.supreme = Math.min(SUPREME.max, f.supreme + amount);
}

// Un colpo di damage punti da attacker a target. attacker null: trappole e colpi senza autore.
// Chi sta facendo la suprema non si ricarica con lei, chi la prende sì
export function chargeFromHit(attacker: Fighter | null | undefined, target: Fighter, damage: number): void {
  if (attacker && attacker !== target && attacker.attack !== "supreme") chargeSupreme(attacker, damage * SUPREME.perDamageDealt);
  chargeSupreme(target, damage * SUPREME.perDamageTaken);
}

// Il tempo carica la barra di chi è in gioco (stepFighter non la chiama durante il ritorno dopo un KO)
export function tickSupreme(f: Fighter, dtMs: number): void {
  chargeSupreme(f, (dtMs / 1000) * SUPREME.perSecond);
}

// Il tasto suprema è stato premuto e si può attaccare (lo controlla tryStartAttack): true se parte
export function tryStartSupreme(f: Fighter, ctx: PhysicsContext): boolean {
  if (!pressed(f, "supreme")) return false;
  consume(f, "supreme");
  if (!supremeReady(f)) return false; // barra non piena: il tasto non fa niente
  f.supreme = 0;
  startAttack(f, "supreme", ctx);
  f.invulnerableTimer = Math.max(f.invulnerableTimer, SUPREME.invulnerableMs);
  f.invulnerable = true;
  return true;
}
