// Barra della suprema (#101): si carica con i danni dati, quelli presi e piano col tempo.
// Piena, il tasto suprema lancia la mossa e la barra torna a 0. La mossa di ogni personaggio
// arriva a parte (Bonobot: #102); finché non c'è, tutti usano ATTACKS.supreme.

import { getCharacter, specialsFor, supremeAttackSpec, type BurstSupreme, type DropSupreme, type GrabSupreme, type SpinSupreme } from "../characters";
import { ATTACKS, FIGHTER, GRAB, SUPREME } from "../constants";
import { startAttack } from "./attacks";
import type { StageSpec } from "../stages";
import { consume, pressed, type Fighter, type PhysicsContext } from "./fighter";
import { fire } from "./projectiles";

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
  const drop = dropOf(f.characterId);
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

// La suprema propria di un personaggio, se è di quel tipo
function dropOf(characterId: string): DropSupreme | null {
  const sp = getCharacter(characterId).supreme;
  return sp?.type === "drop" ? sp : null;
}
function spinOf(characterId: string): SpinSupreme | null {
  const sp = getCharacter(characterId).supreme;
  return sp?.type === "spin" ? sp : null;
}

function grabOf(characterId: string): GrabSupreme | null {
  const sp = getCharacter(characterId).supreme;
  return sp?.type === "grab" ? sp : null;
}

function burstOf(characterId: string): BurstSupreme | null {
  const sp = getCharacter(characterId).supreme;
  return sp?.type === "burst" ? sp : null;
}

// La suprema colpisce col suo rettangolo? Non la "burst", che colpisce coi proiettili
export const supremeMelee = (characterId: string) => !burstOf(characterId);

// La suprema "burst" (#358): a ogni raffica tira count proiettili della speciale neutra a ventaglio, da una parte
// all'altra; le raffiche dispari sono spostate di mezzo passo, così non passano dagli stessi punti
export function burstFire(f: Fighter, dtMs: number, ctx: PhysicsContext): void {
  const sp = f.attack === "supreme" ? burstOf(f.characterId) : null;
  const neutral = specialsFor(f.characterId).neutral;
  if (!sp || neutral.type !== "projectile" || f.attackTimer < sp.windupMs) return;
  const wave = (ms: number) => Math.floor((ms - sp.windupMs) / sp.waveEveryMs);
  const w = wave(f.attackTimer);
  const prev = f.attackTimer - dtMs;
  if (w >= sp.waves || (prev >= sp.windupMs && wave(prev) === w)) return;
  for (let i = 0; i < sp.count; i++) {
    const k = Math.min(1, ((i + 0.5 + (w % 2) * 0.5) / sp.count) * 2 - 1); // da -1 (sinistra) a 1 (destra)
    fire(f, "specialNeutral", neutral, ctx, { vx: k * sp.speed, vy: -sp.lift * (1 - 0.35 * Math.abs(k)) });
  }
}

// La suprema "grab" (#358) ha preso target: lo tira davanti a chi la fa e dice l'angolo del lancio.
// A terra la schiacciata rimbalza in alto, in aria resta verso il basso. Per le altre l'angolo resta quello
export function snatch(attacker: Fighter, target: Fighter, angleDeg: number): number {
  const sp = attacker.attack === "supreme" ? grabOf(attacker.characterId) : null;
  if (!sp) return angleDeg;
  target.x = attacker.x + attacker.facing * GRAB.holdDistance;
  target.y = attacker.y;
  return attacker.onGround ? Math.abs(angleDeg) : angleDeg;
}

// La suprema "spin" (#358) colpisce più volte: a ogni giro (hitEveryMs) chi è già stato colpito può esserlo di nuovo.
// t è attackTimer dopo il passo di dtMs
export function spinRehit(f: Fighter, t: number, dtMs: number): void {
  const sp = f.attack === "supreme" ? spinOf(f.characterId) : null;
  if (!sp || t <= sp.windupMs) return;
  const turn = (ms: number) => Math.floor((ms - sp.windupMs) / sp.hitEveryMs);
  if (turn(t) !== turn(Math.max(sp.windupMs, t - dtMs))) f.alreadyHit.clear();
}

// Quanto si corre a terra durante un attacco: fermi, tranne mentre la "spin" gira (#358)
export function attackMoveFactor(f: Fighter): number {
  const sp = f.attack === "supreme" ? spinOf(f.characterId) : null;
  return sp && f.attackActive ? sp.moveSpeed : 0;
}

// Un passo della suprema propria in corso (#102): la fisica muove chi la fa lungo un percorso fisso
// (salto alla liana, appeso mentre tira, capriola all'indietro fuori dall'impatto). true finché lo guida:
// niente controlli, attacchi né gravità. Dopo la capriola si ricade normalmente, sempre imbersagliabili
export function supreming(f: Fighter, dtMs: number): boolean {
  const sp = dropOf(f.characterId);
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
  return f.attack === "supreme" && dropOf(f.characterId) ? { x: f.supremeX, y: f.supremeY } : { x: f.x, y: f.y };
}

// Fino a dove arriva la suprema di questo personaggio, in orizzontale dal suo centro (per i bot)
export function supremeReach(characterId: string): number {
  const own = getCharacter(characterId).supreme;
  if (own?.type === "drop") return own.leapDx + own.width / 2;
  if (own?.type === "spin") return own.width / 2;
  if (own?.type === "grab") return FIGHTER.width / 2 + own.reach;
  if (own?.type === "burst") return own.speed * 0.6; // dove cadono più o meno i proiettili
  return (ATTACKS.supreme.boxX ?? FIGHTER.width / 2) + ATTACKS.supreme.range;
}
