// Il compagno di un lottatore (#369), per ora il beagle di Lampione: lo segue da solo, corre,
// salta sulle piattaforme e cade. Se resta troppo indietro o esce dall'arena torna accanto a lui.
// Si può colpire: con abbastanza danni va KO e torna dopo un po' (passo 3).
// Fa da trampolino: il padrone che gli cade sopra rimbalza in alto, una volta per salto (passo 4).

import { getCharacter, type CompanionSpec } from "../characters";
import { COMPANION, FIGHTER } from "../constants";
import type { CompanionState } from "../types";
import type { Fighter, PhysicsContext } from "./fighter";
import { platformSurfaceY } from "./stage";

export interface Companion {
  x: number; // centro
  y: number; // piedi
  vx: number;
  vy: number;
  facing: 1 | -1;
  onGround: boolean;
  lunged: boolean; // nel morso in corso ha già scattato
  percent: number; // danni presi: a COMPANION.koPercent va KO
  hurtMs: number; // ms in cui vola via dopo un colpo, senza seguire il padrone
  koMs: number; // ms prima che torni dopo il KO; 0 = in gioco
  bounced: boolean; // il padrone ci è già rimbalzato sopra in questo salto
  bites: boolean; // l'attacco base in corso lo fa lui: deciso quando parte, se è lì vicino a Lampione
}

export const companionOf = (characterId: string): CompanionSpec | null => getCharacter(characterId).companion ?? null;

// Il compagno sta facendo l'attacco in corso di f? (il beagle morde negli attacchi base, #369 passo 2)
export const biting = (f: Fighter): boolean => !!f.pet && f.pet.koMs <= 0 && f.pet.bites && !!f.attack && !!companionOf(f.characterId)?.bites.includes(f.attack);

// All'inizio di un attacco: il beagle morde solo se è lì, accanto al padrone e pronto. Se è rimasto indietro,
// sta volando via colpito o è su un altro piano, l'attacco lo fa il padrone: sennò il colpo partirebbe lontano da lui
export function chooseBiter(f: Fighter): void {
  const c = f.pet;
  if (!c) return;
  c.bites = c.koMs <= 0 && c.hurtMs <= 0 && c.onGround && Math.abs(c.x - f.x) <= COMPANION.biteReachPx && Math.abs(c.y - f.y) <= COMPANION.biteReachYPx;
}

// Il rettangolo del morso: davanti al compagno, alto quanto lui
export function biteBox(f: Fighter, range: number, height: number): { x: number; y: number; w: number; h: number } {
  const c = f.pet!;
  const half = (companionOf(f.characterId)?.width ?? 0) / 2;
  return { x: c.facing === 1 ? c.x + half : c.x - half - range, y: c.y - height, w: range, h: height };
}

// Accanto a f, un po' dietro: lì aspetta
const homeX = (f: Fighter) => f.x - f.facing * COMPANION.gapPx;

function placeBeside(f: Fighter): Companion {
  return { x: homeX(f), y: f.y, vx: 0, vy: 0, facing: f.facing, onGround: f.onGround, lunged: false, percent: 0, hurtMs: 0, koMs: 0, bounced: false, bites: false };
}

// Torna accanto al padrone tenendosi i danni
function sendHome(f: Fighter, c: Companion) {
  f.pet = { ...placeBeside(f), percent: c.percent };
}

// Un tick del compagno di f, dopo che f si è mosso
export function stepCompanion(f: Fighter, dtMs: number, ctx: PhysicsContext): void {
  const spec = companionOf(f.characterId);
  if (!spec || f.eliminated) {
    f.pet = null;
    return;
  }
  // Mentre f è fuori gioco il compagno lo aspetta dove ricompare
  if (!f.pet || f.respawning) {
    f.pet = placeBeside(f);
    return;
  }
  const c = f.pet;
  if (c.koMs > 0) {
    c.koMs -= dtMs;
    if (c.koMs <= 0) f.pet = placeBeside(f);
    return;
  }
  const dt = dtMs / 1000;
  const dx = homeX(f) - c.x;
  const z = ctx.stage.blastZone;
  if (Math.abs(dx) > COMPANION.teleportPx || Math.abs(f.y - c.y) > COMPANION.teleportPx || c.y > z.bottom || c.x < z.left || c.x > z.right) {
    sendHome(f, c);
    return;
  }
  bounce(f, c, spec, dt);
  // Colpito: vola via per un po', poi torna a seguire
  if (c.hurtMs > 0) {
    c.hurtMs -= dtMs;
    move(c, spec, f, dt, ctx);
    return;
  }
  // Il morso: all'inizio dell'attacco scatta in avanti dalla parte in cui guarda f, poi frena
  if (biting(f)) {
    c.facing = f.facing;
    if (!c.lunged && f.smashChargeMs < 0) {
      c.vx = f.facing * COMPANION.lungeSpeed; // caricando il pesante aspetta, scatta quando parte il colpo
      c.lunged = true;
    } else c.vx = Math.sign(c.vx) * Math.max(0, Math.abs(c.vx) - COMPANION.lungeFriction * dt);
    move(c, spec, f, dt, ctx);
    return;
  }
  c.lunged = false;
  // Corre verso il suo posto e si ferma vicino; in aria va più piano
  // Mentre il padrone salta lì vicino aspetta fermo: così gli può ricadere sopra (trampolino)
  const wait = Math.abs(dx) < COMPANION.slackPx || (!f.onGround && Math.abs(f.x - c.x) < COMPANION.waitAirPx);
  const want = wait ? 0 : Math.sign(dx) * FIGHTER.groundSpeed * spec.speed;
  const accel = (c.onGround ? COMPANION.groundAccel : COMPANION.airAccel) * dt;
  c.vx += Math.max(-accel, Math.min(accel, want - c.vx));
  if (Math.abs(c.vx) > 1) c.facing = c.vx > 0 ? 1 : -1;
  else if (Math.abs(f.x - c.x) > 4) c.facing = f.x > c.x ? 1 : -1;
  // Salta se f è più in alto, su una piattaforma
  if (c.onGround && (f.onGround && c.y - f.y > COMPANION.jumpIfAbovePx)) c.vy = -spec.jump;
  move(c, spec, f, dt, ctx);
}

function move(c: Companion, spec: CompanionSpec, f: Fighter, dt: number, ctx: PhysicsContext) {
  c.vy = Math.min(FIGHTER.maxFallSpeed, c.vy + FIGHTER.gravity * dt);
  const prevY = c.y;
  c.x += c.vx * dt;
  c.y += c.vy * dt;
  land(c, prevY, spec.width / 2, f.onGround && f.y - c.y > COMPANION.jumpIfAbovePx, ctx);
}

// Come gli oggetti: si posa su blocchi e piattaforme venendo dall'alto. Le piattaforme le attraversa
// in salita, e anche in discesa quando f è a terra più in basso (drop: lo raggiunge)
function land(c: Companion, prevY: number, half: number, drop: boolean, ctx: PhysicsContext) {
  c.onGround = false;
  if (c.vy < 0) return;
  for (const s of drop ? ctx.stage.solids : [...ctx.stage.solids, ...ctx.stage.platforms]) {
    const over = c.x + half > s.x && c.x - half < s.x + s.width;
    const sy = "height" in s ? s.y : platformSurfaceY(s, c.x);
    if (over && prevY <= sy && c.y >= sy) {
      c.y = sy;
      c.vy = 0;
      c.onGround = true;
      return;
    }
  }
}

// Il trampolino: f che scende sulla schiena del compagno fermo a terra rimbalza in alto e riprende un salto.
// Tenendo giù ci si posa senza rimbalzare
function bounce(f: Fighter, c: Companion, spec: CompanionSpec, dt: number) {
  if (f.onGround) c.bounced = false;
  if (c.bounced || !c.onGround || c.hurtMs > 0 || f.onGround || f.vy <= 0 || f.input.down || f.ledge) return;
  const top = c.y - spec.height;
  const prevY = f.y - f.vy * dt;
  if (Math.abs(f.x - c.x) > spec.width / 2 + FIGHTER.width / 4 || f.y < top || prevY > top + COMPANION.bounceSlackPx) return;
  f.y = top;
  f.vy = -COMPANION.bounceVy;
  f.jumpsLeft = Math.max(f.jumpsLeft, 1);
  c.bounced = true;
}

// Un colpo di attacker col rettangolo box tocca i compagni degli altri? Prendono danni e volano via;
// a COMPANION.koPercent vanno KO. hit: chi è già stato colpito da questo attacco (le chiavi "pet:<id padrone>")
export function hitPets(attacker: Fighter, box: { x: number; y: number; w: number; h: number }, damage: number, fighters: Fighter[], hit: Set<string>, ctx: PhysicsContext): void {
  for (const owner of fighters) {
    const c = owner.pet;
    if (owner === attacker || !c || c.koMs > 0 || hit.has(`pet:${owner.id}`)) continue;
    if (ctx.canHit && !ctx.canHit(attacker, owner)) continue;
    const spec = companionOf(owner.characterId);
    if (!spec) continue;
    const h = Math.max(spec.height, COMPANION.hurtHeight);
    const body = { x: c.x - spec.width / 2, y: c.y - h, w: spec.width, h };
    if (!(box.x < body.x + body.w && box.x + box.w > body.x && box.y < body.y + body.h && box.y + box.h > body.y)) continue;
    hit.add(`pet:${owner.id}`);
    c.percent += damage;
    if (c.percent >= COMPANION.koPercent) {
      c.koMs = COMPANION.koMs;
      continue;
    }
    const push = COMPANION.knockBase + COMPANION.knockPerDamage * damage;
    c.vx = attacker.facing * push;
    c.vy = -push * 0.6;
    c.onGround = false;
    c.hurtMs = COMPANION.hurtMs;
  }
}

// Quello che va nello snapshot: niente mentre è KO; bite se morde lui nell'attacco in corso
export const companionState = (f: Fighter): CompanionState | null => {
  const c = f.pet;
  if (!c || c.koMs > 0) return null;
  return { x: Math.round(c.x), y: Math.round(c.y), facing: c.facing, onGround: c.onGround, percent: Math.round(c.percent), ...(biting(f) && { bite: true }) };
};
