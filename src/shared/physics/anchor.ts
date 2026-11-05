// L'ancora-ragnatela di Capt. OrsoBlu (#547). Tutto passa dallo Speciale: da solo la spara in avanti (Tutti a
// bordo!), con su in alto, con su + una direzione in diagonale. Anche il recupero comune (Pesante + su in aria) la
// spara in alto. La mira è aiutata: va verso lo spigolo o la piattaforma più vicina alla direzione del lancio.
// Se si pianta resta appeso e dondola come un pendolo con la catena tesa: avanti e indietro danno slancio lungo
// l'arco, su si arrampica (in cima a una piattaforma ci si sale sopra), giù si cala, Salto si stacca con lo slancio,
// una spinta in alto e verso la direzione tenuta, Scudo lascia andare, Leggero e Pesante fanno l'attacco in aria,
// Speciale fa Avanti tutta!: riavvolge la catena e sfreccia verso l'ancora travolgendo chi c'è in mezzo.
// Lanciata da terra la catena tira subito fin lì, e su una piattaforma ci si ritrova sopra.
// Toccando terra, prendendo un colpo o dopo maxHangMs la catena si lascia. Il disegno di catena e ancora è di Godot.

import { getCharacter } from "../characters";
import { ANCHOR, ARREMBAGGIO, FIGHTER } from "../constants";
import { platformSurfaceY } from "./stage";
import { arcadeSolids } from "./arcade";
import { attackSpecFor, bodyBox, canBeHit, launch, startAttack } from "./attacks";
import { consume, pressed, type Fighter, type PhysicsContext } from "./fighter";
import type { ThinPlatform } from "../stages";

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

// La piattaforma sottile dove è piantata l'ancora, se è su una di quelle
function platformOf(x: number, y: number, ctx: PhysicsContext, a: AnchorSpec): ThinPlatform | undefined {
  return ctx.stage.platforms.find((p) => x >= p.x && x <= p.x + p.width && Math.abs(y - platformSurfaceY(p, x)) <= a.platformGrabPx);
}

// I punti dove l'ancora si può piantare: le superfici delle piattaforme sottili e i bordi dei blocchi pieni, appena
// dentro, ogni assistStepPx
function hookPoints(ctx: PhysicsContext, a: AnchorSpec): { x: number; y: number }[] {
  const out: { x: number; y: number }[] = [];
  const step = a.assistStepPx;
  const along = (x0: number, x1: number, at: (x: number) => void) => {
    for (let x = x0; x < x1; x += step) at(x);
    at(x1);
  };
  for (const p of ctx.stage.platforms) along(p.x, p.x + p.width, (x) => out.push({ x, y: platformSurfaceY(p, x) }));
  const solids = ctx.arcade?.blocks.length ? [...ctx.stage.solids, ...arcadeSolids(ctx)] : ctx.stage.solids;
  for (const s of solids) {
    const l = s.x + 2;
    const r = s.x + s.width - 2;
    const t = s.y + 2;
    const b = s.y + s.height - 2;
    along(l, r, (x) => out.push({ x, y: t }, { x, y: b }));
    for (let y = t + step; y < b; y += step) out.push({ x: l, y }, { x: r, y });
  }
  return out;
}

// Mira aiutata: la direzione (angolo in radianti, 0 = avanti, positivo = in su, rispetto a facing) verso il punto
// agganciabile più vicino a quella chiesta, entro coneDeg e a portata di catena; null se non ce n'è. Solo punti più
// in alto delle mani: l'ancora serve ad appendersi
function assistedAngle(f: Fighter, ox: number, oy: number, angle: number, coneDeg: number, ctx: PhysicsContext, a: AnchorSpec): number | null {
  const cone = (coneDeg * Math.PI) / 180;
  let best: number | null = null;
  let bestOff = cone;
  for (const p of hookPoints(ctx, a)) {
    const dx = (p.x - ox) * f.facing;
    const dy = oy - p.y;
    if (dy <= 0) continue;
    const d = Math.hypot(dx, dy);
    if (d < a.minLength || d > a.maxLength - 24) continue;
    const off = Math.abs(Math.atan2(dy, dx) - angle);
    if (off < bestOff) {
      bestOff = off;
      best = Math.atan2(dy, dx);
    }
  }
  return best;
}

// Il lancio, al posto del recupero comune (in alto) o della speciale neutra (forward: dritto in avanti, anche da
// terra). dir: la direzione tenuta (-1, 0, 1)
export function throwAnchor(f: Fighter, dir: number, ctx: PhysicsContext, forward = false): void {
  const a = anchorSpec(f.characterId);
  if (!a || f.anchor) return;
  if (!f.onGround && f.anchorThrows >= a.maxThrows) return;
  if (dir !== 0) f.facing = dir as 1 | -1;
  const asked = ((forward ? a.forwardAngleDeg : dir === 0 ? a.upAngleDeg : a.diagAngleDeg) * Math.PI) / 180;
  const ox = gripX(f);
  const oy = forward ? f.y - a.forwardY : gripY(f, a);
  const angle = assistedAngle(f, ox, oy, asked, forward ? a.assistForwardDeg : dir === 0 ? a.assistUpDeg : a.assistDiagDeg, ctx, a) ?? asked;
  f.anchor = { x: ox, y: oy, phase: "fly" };
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
    f.vx += ((f.input.right ? 1 : 0) - (f.input.left ? 1 : 0)) * a.releasePush;
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
  if (f.anchorZip) return zip(f, h, a, dt, ctx);
  // Il calcio in oscillazione: l'attacco in aria, qualunque direzione si tenga (su e giù servono alla catena)
  if (!f.attack && f.cooldownTimer === 0 && (pressed(f, "light") || pressed(f, "heavy"))) {
    startAttack(f, pressed(f, "light") ? "lightAir" : "heavyAir", ctx);
  }
  if (f.input.up && !f.input.down) {
    // In cima a una piattaforma sottile ci si sale sopra
    if (f.anchorLen <= a.minLength && hopOnto(f, h, a, ctx)) return true;
    f.anchorLen = Math.max(a.minLength, f.anchorLen - a.climbSpeed * dt);
    h.phase = "climb";
  } else {
    if (f.input.down) f.anchorLen = Math.min(a.maxLength, f.anchorLen + a.lowerSpeed * dt);
    h.phase = "hold";
  }
  // Lo slancio va lungo l'arco, nella direzione tenuta, e solo sotto l'ancora: così si dondola senza tirare la
  // catena e senza girarci sopra
  const rx = gripX(f) - h.x;
  const ry = gripY(f, a) - h.y;
  const rl = Math.hypot(rx, ry) || 1;
  if (dir !== 0 && ry > 0) {
    let tx = -ry / rl;
    let ty = rx / rl;
    if (tx * dir < 0) {
      tx = -tx;
      ty = -ty;
    }
    f.vx += tx * a.pumpAccel * dt;
    f.vy += ty * a.pumpAccel * dt;
  }
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
function zip(f: Fighter, h: { x: number; y: number }, a: AnchorSpec, dt: number, ctx: PhysicsContext): boolean {
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
    hopOnto(f, h, a, ctx); // arrivati sotto una piattaforma ci si sale sopra
    return true;
  }
  f.anchorLen = d - a.zipSpeed * dt;
  f.vx = (dx / d) * a.zipSpeed;
  f.vy = (dy / d) * a.zipSpeed;
  return true;
}

// Su una piattaforma sottile dove è piantata l'ancora: un balzo che porta i piedi platformHopPx sopra, si lascia la
// catena e si atterra lì (le sottili si attraversano dal basso). false se l'ancora non è su una piattaforma
function hopOnto(f: Fighter, h: { x: number; y: number }, a: AnchorSpec, ctx: PhysicsContext): boolean {
  const p = platformOf(h.x, h.y, ctx, a);
  if (!p) return false;
  const rise = Math.max(0, f.y - platformSurfaceY(p, h.x)) + a.platformHopPx;
  releaseAnchor(f);
  f.vy = -Math.sqrt(2 * FIGHTER.gravity * rise);
  f.vx = (h.x - f.x) * 2; // verso l'ancora: in un balzo ci si arriva sopra
  f.helpless = false;
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

// Tutti a bordo! (#547): l'ancora in volo che tocca un avversario lo tira verso chi l'ha lanciata e torna in mano.
// Dopo che tutti si sono mossi, prima dei colpi
export function hookFighters(fighters: Fighter[], ctx: PhysicsContext): void {
  for (const f of fighters) {
    const h = f.anchor;
    if (h?.phase !== "fly") continue;
    const a = anchorSpec(f.characterId) ?? ANCHOR;
    for (const t of fighters) {
      if (t === f || !canBeHit(t) || t.away || (ctx.canHit && !ctx.canHit(f, t))) continue;
      const b = bodyBox(t);
      if (h.x < b.x || h.x > b.x + b.w || h.y < b.y || h.y > b.y + b.h) continue;
      h.phase = "back";
      if (t.shielding) break; // lo scudo la respinge
      launch(t, f, "specialNeutral", Math.round(h.x), Math.round(h.y), ctx, undefined, { damage: a.pullDamage, baseKnockback: 0, knockbackGrowth: 0, angleDeg: 0 });
      t.vx = Math.sign(f.x - t.x) * a.pullSpeed;
      t.vy = -a.pullLift;
      t.hitstunTimer = a.pullHitstunMs;
      t.boardedBy = f.id; // ora il colpo di OrsoBlu vale l'arrembaggio (#557)
      t.boardedMs = ARREMBAGGIO.windowMs;
      break;
    }
  }
}
