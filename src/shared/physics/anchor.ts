// L'ancora-ragnatela di Capt. OrsoBlu (#547). Il suo recupero (Pesante + su in aria) spara l'ancora: solo su
// quasi in verticale, su + una direzione in diagonale. Se si pianta in un blocco o in una piattaforma lui resta
// appeso e dondola come un pendolo con la catena tesa: avanti e indietro danno slancio, su si arrampica, giù si
// cala, Salto si stacca con lo slancio e una spinta, Scudo lascia andare, Leggero e Pesante fanno l'attacco in aria,
// Speciale fa Avanti tutta!: riavvolge la catena e sfreccia verso l'ancora travolgendo chi c'è in mezzo.
// Toccando terra, prendendo un colpo o dopo maxHangMs la catena si lascia. Il disegno di catena e ancora è di Godot.

import { getCharacter } from "../characters";
import { ANCHOR, FIGHTER } from "../constants";
import { platformSurfaceY } from "./stage";
import { arcadeSolids } from "./arcade";
import { attackSpecFor, startAttack } from "./attacks";
import { consume, pressed, type Fighter, type PhysicsContext } from "./fighter";

export type AnchorSpec = typeof ANCHOR;

// I numeri dell'ancora del personaggio, o null se non ne ha una
export function anchorSpec(characterId: string): AnchorSpec | null {
  const own = getCharacter(characterId).anchor;
  return own ? { ...ANCHOR, ...own } : null;
}

// Dove le mani tengono la catena
const gripX = (f: Fighter) => f.x;
const gripY = (f: Fighter, a: AnchorSpec) => f.y - a.gripY;

// Appeso alla catena (piantata), non in volo né di ritorno
export const onRope = (f: Fighter) => f.anchor?.phase === "hold" || f.anchor?.phase === "climb";

// Il punto (x, y) è dentro un blocco pieno o sul filo di una piattaforma sottile? Lì l'ancora si pianta
export function hookable(x: number, y: number, ctx: PhysicsContext, a: AnchorSpec = ANCHOR): boolean {
  const solids = ctx.arcade?.blocks.length ? [...ctx.stage.solids, ...arcadeSolids(ctx)] : ctx.stage.solids;
  for (const s of solids) if (x >= s.x && x <= s.x + s.width && y >= s.y && y <= s.y + s.height) return true;
  for (const p of ctx.stage.platforms) {
    if (x < p.x || x > p.x + p.width) continue;
    if (Math.abs(y - platformSurfaceY(p, x)) <= a.platformGrabPx) return true;
  }
  return false;
}

// Il lancio, al posto del recupero comune (in alto) o della speciale neutra (forward: dritto in avanti, anche da
// terra). dir: la direzione tenuta (-1, 0, 1)
export function throwAnchor(f: Fighter, dir: number, ctx: PhysicsContext, forward = false): void {
  const a = anchorSpec(f.characterId);
  if (!a || f.anchor) return;
  if (!f.onGround && f.anchorThrows >= a.maxThrows) return;
  if (dir !== 0) f.facing = dir as 1 | -1;
  const angle = ((forward ? a.forwardAngleDeg : dir === 0 ? a.upAngleDeg : a.diagAngleDeg) * Math.PI) / 180;
  f.anchor = { x: gripX(f), y: gripY(f, a), phase: "fly" };
  f.anchorVx = f.facing * Math.cos(angle) * a.throwSpeed;
  f.anchorVy = -Math.sin(angle) * a.throwSpeed;
  if (!f.onGround) {
    f.anchorThrows += 1;
    f.recoveryUsed = f.anchorThrows >= a.maxThrows; // i bot e la predizione guardano questo
    f.vy = Math.min(f.vy, -a.throwLift);
    f.jumpRising = false;
  }
  startAttack(f, forward ? "specialNeutral" : "recovery", ctx); // l'animazione del lancio (e per il recupero il colpetto del braccio)
}

export function releaseAnchor(f: Fighter): void {
  f.anchor = undefined;
  f.anchorMs = 0;
  f.anchorZip = false;
}

// Si riprendono i lanci: a terra, aggrappati al bordo, colpiti, al rientro
export function resetAnchor(f: Fighter): void {
  f.anchorThrows = 0;
}

// L'ancora in volo o di ritorno, dopo che il lottatore si è mosso: parte e torna sempre dalle sue mani
export function stepHook(f: Fighter, dtMs: number, ctx: PhysicsContext): void {
  const h = f.anchor;
  if (!h || onRope(f)) return;
  const a = anchorSpec(f.characterId) ?? ANCHOR;
  const dt = dtMs / 1000;
  const hx = gripX(f);
  const hy = gripY(f, a);
  if (h.phase === "back") {
    const dx = hx - h.x;
    const dy = hy - h.y;
    const d = Math.hypot(dx, dy);
    const step = a.retractSpeed * dt;
    if (d <= step) return releaseAnchor(f);
    h.x += (dx / d) * step;
    h.y += (dy / d) * step;
    return;
  }
  // In volo: a passi corti, così non salta oltre una piattaforma sottile
  const dist = Math.hypot(f.anchorVx, f.anchorVy) * dt;
  const steps = Math.max(1, Math.ceil(dist / a.hookStepPx));
  for (let i = 0; i < steps; i++) {
    h.x += (f.anchorVx * dt) / steps;
    h.y += (f.anchorVy * dt) / steps;
    if (hookable(h.x, h.y, ctx, a)) {
      h.phase = "hold";
      f.anchorLen = Math.max(a.minLength, Math.min(a.maxLength, Math.hypot(hx - h.x, hy - h.y)));
      f.anchorMs = 0;
      // Lanciata da terra: la catena tira subito verso l'ancora, come Avanti tutta! (a terra non si dondola)
      if (f.onGround) f.anchorZip = true;
      if (f.attack === "recovery" || f.attack === "specialNeutral") {
        f.attack = null; // piantata: da appeso si può già attaccare
        f.attackActive = false;
        f.cooldownTimer = 0;
      }
      f.helpless = false;
      return;
    }
    if (Math.hypot(hx - h.x, hy - h.y) >= a.maxLength) {
      h.phase = "back"; // non ha trovato niente: torna in mano
      return;
    }
  }
}

// Un passo da appeso: tasti, gravità e slancio. true se i controlli soliti e la gravità si saltano: si muove il
// pendolo, o ci si è appena staccati col salto o lo scudo.
// La catena si tende dopo lo spostamento, con tightenAnchor
export function swingAnchor(f: Fighter, dtMs: number, ctx: PhysicsContext): boolean {
  if (!onRope(f)) return false;
  const h = f.anchor!;
  const a = anchorSpec(f.characterId) ?? ANCHOR;
  f.anchorMs += dtMs;
  if (f.hitstun || (f.onGround && !f.anchorZip) || f.anchorMs >= a.maxHangMs || !hookable(h.x, h.y, ctx, a)) {
    releaseAnchor(f);
    return false;
  }
  // Salto: ci si stacca tenendo lo slancio, con una spinta verso l'alto
  if (pressed(f, "jump")) {
    consume(f, "jump");
    releaseAnchor(f);
    f.vy = Math.min(f.vy, 0) - a.releaseBoost;
    ctx.events.push({ type: "jump", id: f.id, x: Math.round(f.x), y: Math.round(f.y), air: true });
    return true; // in questo tick niente altri controlli: lo stesso tasto farebbe anche il doppio salto
  }
  // Scudo: si lascia andare e basta (in questo tick non fa anche la schivata in aria)
  if (pressed(f, "shield")) {
    releaseAnchor(f);
    return true;
  }
  const dt = dtMs / 1000;
  const dir = (f.input.right ? 1 : 0) - (f.input.left ? 1 : 0);
  // Avanti tutta! Speciale da appeso: la speciale laterale, già attiva, lungo la catena
  if (!f.anchorZip && !f.attack && pressed(f, "special")) {
    startAttack(f, "specialSide", ctx);
    f.attackTimer = attackSpecFor(f).startupMs; // parte già attiva: il lancio della catena c'è già stato
    f.attackActive = true; // colpisce già in questo tick
    f.facing = (Math.sign(h.x - f.x) || f.facing) as 1 | -1;
    f.anchorZip = true;
  }
  if (f.anchorZip) return zip(f, h, a, dt);
  // Il calcio in oscillazione: l'attacco in aria, qualunque direzione si tenga (su e giù servono alla catena)
  if (!f.attack && f.cooldownTimer === 0 && (pressed(f, "light") || pressed(f, "heavy"))) {
    startAttack(f, pressed(f, "light") ? "lightAir" : "heavyAir", ctx);
  }
  if (f.input.up && !f.input.down) {
    f.anchorLen = Math.max(a.minLength, f.anchorLen - a.climbSpeed * dt);
    h.phase = "climb";
  } else {
    if (f.input.down) f.anchorLen = Math.min(a.maxLength, f.anchorLen + a.lowerSpeed * dt);
    h.phase = "hold";
  }
  f.vx += dir * a.pumpAccel * dt;
  f.vy += FIGHTER.gravity * dt;
  const drag = Math.max(0, 1 - a.swingDrag * dt);
  f.vx *= drag;
  f.vy *= drag;
  const speed = Math.hypot(f.vx, f.vy);
  if (speed > a.maxSwingSpeed) {
    f.vx *= a.maxSwingSpeed / speed;
    f.vy *= a.maxSwingSpeed / speed;
  }
  if (dir !== 0 && !f.attack) f.facing = dir as 1 | -1;
  return true;
}

// La teleferica: si va dritti verso l'ancora, la catena si accorcia con lui. Arrivati in cima resta un po' di
// spinta verso l'ancora e si torna appesi; vicino a uno spigolo ci si aggrappa al bordo (tryGrabLedge)
function zip(f: Fighter, h: { x: number; y: number }, a: AnchorSpec, dt: number): boolean {
  const dx = h.x - gripX(f);
  const dy = h.y - gripY(f, a);
  const d = Math.hypot(dx, dy) || 1;
  if (d - a.zipSpeed * dt <= a.minLength) {
    f.anchorZip = false;
    f.anchorLen = a.minLength;
    f.vx = (dx / d) * a.zipEndSpeed;
    f.vy = (dy / d) * a.zipEndSpeed;
    if (f.attack === "specialSide") {
      f.attack = null;
      f.attackActive = false;
      f.cooldownTimer = a.zipEndLagMs;
    }
    return true;
  }
  f.anchorLen = d - a.zipSpeed * dt;
  f.vx = (dx / d) * a.zipSpeed;
  f.vy = (dy / d) * a.zipSpeed;
  return true;
}

// Dopo lo spostamento: la catena non si allunga. Le mani tornano sul cerchio e la velocità che tira via si perde
export function tightenAnchor(f: Fighter): void {
  if (!onRope(f)) return;
  const h = f.anchor!;
  const a = anchorSpec(f.characterId) ?? ANCHOR;
  const dx = gripX(f) - h.x;
  const dy = gripY(f, a) - h.y;
  const d = Math.hypot(dx, dy);
  if (d <= f.anchorLen || d === 0) return;
  const ux = dx / d;
  const uy = dy / d;
  f.x = h.x + ux * f.anchorLen;
  f.y = h.y + uy * f.anchorLen + a.gripY;
  const out = f.vx * ux + f.vy * uy;
  if (out > 0) {
    f.vx -= out * ux;
    f.vy -= out * uy;
  }
}
