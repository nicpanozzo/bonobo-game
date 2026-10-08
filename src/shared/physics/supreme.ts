// Barra della suprema (#101): si carica con i danni dati, quelli presi e piano col tempo.
// Piena, il tasto suprema lancia la mossa e la barra torna a 0. La mossa di ogni personaggio
// arriva a parte (Bonobot: #102); finché non c'è, tutti usano ATTACKS.supreme.

import { getCharacter, supremeAttackSpec, type DropSupreme } from "../characters";
import { ATTACKS, FIGHTER, SUPREME } from "../constants";
import { startAttack } from "./attacks";
import type { StageSpec } from "../stages";
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
// e mentre si fa la suprema
export function tickSupreme(f: Fighter, dtMs: number): void {
  if (f.supremeBusyMs > 0) {
    f.supremeBusyMs = Math.max(0, f.supremeBusyMs - dtMs);
    return;
  }
  chargeSupreme(f, (dtMs / 1000) * SUPREME.perSecond);
}

// Il tasto suprema è stato premuto e si può attaccare (lo controlla tryStartAttack): true se parte
export function tryStartSupreme(f: Fighter, ctx: PhysicsContext): boolean {
  if (!pressed(f, "supreme")) return false;
  consume(f, "supreme");
  if (!supremeReady(f)) return false; // barra non piena: il tasto non fa niente
  f.supreme = 0;
  startAttack(f, "supreme", ctx);
  const own = supremeAttackSpec(f.characterId);
  const drop = getCharacter(f.characterId).supreme;
  f.supremeBusyMs = (own ?? ATTACKS.supreme).cooldownMs;
  // Quella di base si può interrompere dopo l'avvio; quella propria (#102) no, dall'inizio alla fine
  f.invulnerableTimer = Math.max(f.invulnerableTimer, own ? own.cooldownMs : SUPREME.invulnerableMs);
  f.invulnerable = true;
  if (drop) {
    f.supremeTimer = motionMs(drop);
    f.supremeX0 = f.x;
    f.supremeY0 = f.y;
    f.supremeX = f.x + f.facing * drop.leapDx; // la liana scende un po' davanti
    f.supremeY = groundBelow(ctx.stage, f.supremeX, f.y); // anche partendo in aria, l'orsogufo arriva a terra
  }
  return true;
}

const motionMs = (sp: DropSupreme) => sp.leapMs + sp.pullMs + sp.flipMs;

// Un passo della suprema propria in corso (#102): la fisica muove chi la fa lungo un percorso fisso
// (salto alla liana, appeso mentre tira, capriola all'indietro fuori dall'impatto). true finché lo guida:
// niente controlli, attacchi né gravità. Dopo la capriola si ricade normalmente, sempre imbersagliabili
export function supreming(f: Fighter, dtMs: number): boolean {
  const sp = getCharacter(f.characterId).supreme;
  if (f.supremeTimer <= 0 || !sp) return false;
  f.supremeTimer = Math.max(0, f.supremeTimer - dtMs);
  const t = motionMs(sp) - f.supremeTimer;
  const top = f.supremeY0 - sp.leapDy;
  if (t < sp.leapMs) {
    const k = t / sp.leapMs;
    f.x = f.supremeX0 + (f.supremeX - f.supremeX0) * k;
    f.y = f.supremeY0 - sp.leapDy * Math.sin((k * Math.PI) / 2); // sale in fretta e rallenta in cima
  } else if (t < sp.leapMs + sp.pullMs) {
    f.x = f.supremeX;
    f.y = top;
  } else {
    const k = Math.min(1, (t - sp.leapMs - sp.pullMs) / sp.flipMs);
    f.x = f.supremeX - f.facing * sp.flipDx * k; // all'indietro, guardando sempre la liana
    f.y = top + sp.leapDy * k - sp.flipArc * Math.sin(k * Math.PI);
  }
  f.vx = 0;
  f.vy = 0;
  f.onGround = false;
  return true;
}

// Il terreno sotto x da y in giù (blocco o piattaforma), come ground_y() in supreme_view.gd. Senza, y
export function groundBelow(stage: StageSpec, x: number, y: number): number {
  let best = Infinity;
  for (const s of [...stage.solids, ...stage.platforms]) {
    if (x >= s.x && x <= s.x + s.width && s.y >= y - 1) best = Math.min(best, s.y);
  }
  return best === Infinity ? y : best;
}

// Il punto da cui parte il colpo: la liana per la suprema propria (#102), altrimenti chi colpisce
export function hitOrigin(f: Fighter): { x: number; y: number } {
  return f.attack === "supreme" && getCharacter(f.characterId).supreme ? { x: f.supremeX, y: f.supremeY } : { x: f.x, y: f.y };
}

// Fino a dove arriva la suprema di questo personaggio, in orizzontale dal suo centro (per i bot)
export function supremeReach(characterId: string): number {
  const own = getCharacter(characterId).supreme;
  if (own) return own.leapDx + own.width / 2;
  return (ATTACKS.supreme.boxX ?? FIGHTER.width / 2) + ATTACKS.supreme.range;
}
