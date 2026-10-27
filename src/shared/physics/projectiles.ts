// Proiettili delle speciali (E10): li tira una speciale "projectile" e volano da soli.
// Deterministici come il resto della fisica: id in ordine, nessun caso. Si fermano contro i blocchi
// pieni, i lottatori, lo scudo e i proiettili degli altri (si annullano a vicenda).

import { getCharacter, SPECIAL_KINDS, specialsFor, type ProjectileSpecial, type SpecialSlot, type SupremeEagle } from "../characters";
import { FIGHTER, HITSTOP, SLICK, SPECIAL_MOVES } from "../constants";
import type { ProjectileState, PuddleState, SpecialKind } from "../types";
import { bodyBox, canBeHit, launch, overlap } from "./attacks";
import type { Fighter, PhysicsContext } from "./fighter";
import { hitShield } from "./shield";
import { counterAbsorbs } from "./specials";

export interface Projectile extends ProjectileState {
  ageMs: number;
  slick?: boolean; // dell'IRA di Lendmar (#13): dove sbatte per terra lascia una pozza che fa scivolare
  carryId?: string; // l'aquila della suprema: chi sta portando in volo
  carryMs?: number; // da quanto lo porta
  spent?: boolean; // l'aquila ha già mollato la sua preda: vola via senza colpire
}

export interface Puddle extends PuddleState {
  lifeMs: number; // quanto resta ancora
}

// Tutti i proiettili della partita: li crea match.ts (o il primo tiro, nei test)
export interface ProjectileWorld {
  list: Projectile[];
  nextId: number;
  puddles: Puddle[]; // pozze scivolose a terra (#13), con gli id dei proiettili da cui sono nate
}

export const createProjectileWorld = (): ProjectileWorld => ({ list: [], nextId: 1, puddles: [] });

const worldOf = (ctx: PhysicsContext) => (ctx.projectiles ??= createProjectileWorld());

// Quanti proiettili di f sono in volo: oltre maxAlive la speciale non parte
export const aliveOf = (f: Fighter, ctx: PhysicsContext) => worldOf(ctx).list.filter((p) => p.ownerId === f.id).length;

// Il proiettile esce dalle mani di f (o da spawnX/spawnY), nella direzione in cui guarda.
// v: un'altra velocità (la suprema "burst", #358). supreme: è l'aquila della suprema, coi numeri di lei
export function fire(f: Fighter, kind: SpecialKind, sp: ProjectileSpecial, ctx: PhysicsContext, v?: { vx: number; vy: number }, supreme = false): void {
  const world = worldOf(ctx);
  // le Ciacole di Bradipo: ogni tiro prende l'angolo successivo della lista (#13)
  const deg = !v && sp.spreadDeg?.length ? sp.spreadDeg[world.nextId % sp.spreadDeg.length] : 0;
  const p: Projectile = {
    id: world.nextId++,
    ownerId: f.id,
    kind,
    characterId: f.characterId,
    x: v ? f.x : f.x + f.facing * (sp.spawnX ?? FIGHTER.width / 2 + sp.range / 2),
    y: f.y - (sp.spawnY ?? SPECIAL_MOVES.projectileY),
    vx: v ? v.vx : f.facing * sp.speed * Math.cos((deg * Math.PI) / 180),
    vy: v ? v.vy : -(sp.lift ?? 0) - sp.speed * Math.sin((deg * Math.PI) / 180),
    ageMs: 0,
  };
  if (supreme) p.supreme = true;
  world.list.push(p);
  ctx.events.push({ type: "projectile", id: f.id, projectileId: p.id, x: Math.round(p.x), y: Math.round(p.y) });
}

// Un tick: volo, poi muri, lottatori e altri proiettili
export function stepProjectiles(fighters: Fighter[], dtMs: number, ctx: PhysicsContext): void {
  const world = ctx.projectiles;
  if (!world) return;
  stepPuddles(world, dtMs);
  if (world.list.length === 0) return;
  const dt = dtMs / 1000;
  const byId = new Map(fighters.map((f) => [f.id, f]));
  const ended = new Set<Projectile>();
  const end = (p: Projectile, reason: "hit" | "blocked" | "expired" | "wall") => {
    ended.add(p);
    ctx.events.push({ type: "projectileEnd", projectileId: p.id, reason, x: Math.round(p.x), y: Math.round(p.y) });
  };

  for (const p of world.list) {
    const sp = specOf(p);
    if (p.carryId !== undefined) {
      carry(p, sp as SupremeEagle, byId, dtMs, ctx, end);
      continue;
    }
    p.ageMs += dtMs;
    p.vy += sp.gravity * dt;
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    const box = boxOf(p, sp);
    const z = ctx.stage.blastZone;
    if (p.ageMs >= sp.lifeMs || p.x < z.left || p.x > z.right || p.y < z.top || p.y > z.bottom) end(p, "expired");
    else if (ctx.stage.solids.some((s) => overlap(box, { x: s.x, y: s.y, w: s.width, h: s.height }))) {
      if (p.slick) dropPuddle(world, p, ctx);
      end(p, "wall");
    }
    else if (!p.spent) hitFighter(p, sp, box, fighters, byId, ctx, end);
  }

  // Due proiettili di giocatori diversi che si toccano si annullano
  const alive = world.list.filter((p) => !ended.has(p));
  for (let i = 0; i < alive.length; i++) {
    for (let j = i + 1; j < alive.length; j++) {
      const a = alive[i];
      const b = alive[j];
      if (ended.has(a) || ended.has(b) || a.ownerId === b.ownerId) continue;
      if (a.supreme || b.supreme) continue; // l'aquila non si ferma per un tiro
      if (!overlap(boxOf(a, specOf(a)), boxOf(b, specOf(b)))) continue;
      end(a, "hit");
      end(b, "hit");
    }
  }
  world.list = world.list.filter((p) => !ended.has(p));
}

function hitFighter(
  p: Projectile,
  sp: ProjectileSpecial,
  box: ReturnType<typeof boxOf>,
  fighters: Fighter[],
  byId: Map<string, Fighter>,
  ctx: PhysicsContext,
  end: (p: Projectile, reason: "hit" | "blocked" | "expired") => void,
): void {
  const owner = byId.get(p.ownerId);
  const dir: 1 | -1 = p.vx >= 0 ? 1 : -1;
  for (const t of fighters) {
    if (t.id === p.ownerId || !canBeHit(t) || t.away) continue;
    if (owner && ctx.canHit && !ctx.canHit(owner, t)) continue;
    if (!overlap(box, bodyBox(t))) continue;
    const x = Math.round(p.x);
    const y = Math.round(p.y);
    // Il contrattacco lo rimanda indietro: ora è di chi l'ha parato
    if (counterAbsorbs(t, p.ownerId, x, y, ctx)) {
      p.ownerId = t.id;
      p.vx = -p.vx;
      p.ageMs = 0;
      return;
    }
    if (t.shielding) {
      hitShield(t, p.ownerId, sp.damage, dir, x, y, ctx);
      end(p, "blocked");
      return;
    }
    if (!owner) {
      end(p, "expired"); // chi l'ha tirato è uscito dalla stanza: non colpisce più nessuno
      return;
    }
    if (p.supreme) {
      grab(p, sp as SupremeEagle, owner, t, ctx);
      return;
    }
    // Il colpo vola nella direzione del proiettile, non in quella in cui guarda chi l'ha tirato
    launch(t, { ...owner, facing: dir }, p.kind, x, y, ctx);
    t.hitstopTimer = Math.max(t.hitstopTimer, Math.min(HITSTOP.maxMs, HITSTOP.baseMs + HITSTOP.perDamageMs * sp.damage));
    end(p, "hit");
    return;
  }
}

// L'aquila afferra t: un po' di danno subito, poi lo porta (carry) e lo molla più in là
function grab(p: Projectile, sp: SupremeEagle, owner: Fighter, t: Fighter, ctx: PhysicsContext): void {
  p.carryId = t.id;
  p.carryMs = 0;
  p.x = t.x; // lo prende dall'alto: l'aquila va sopra la sua testa, lui non si sposta né va sotto terra
  p.y = Math.min(p.y, t.y - sp.hangPx);
  t.percent = Math.min(999, t.percent + sp.grabDamage);
  holdPrey(p, sp, t);
  ctx.events.push({ type: "hit", attackerId: owner.id, targetId: t.id, kind: p.kind, damage: sp.grabDamage, percent: t.percent, knockback: 0, x: Math.round(p.x), y: Math.round(p.y) });
}

// Chi è preso pende sotto l'aquila, stordito e senza cadere: lo si rimette lì a ogni tick
function holdPrey(p: Projectile, sp: SupremeEagle, t: Fighter): void {
  t.x = p.x;
  t.y = p.y + sp.hangPx;
  t.vx = p.vx;
  t.vy = p.vy;
  t.onGround = false;
  t.hitstunTimer = Math.max(t.hitstunTimer, 100);
  t.hitstun = true;
  t.attack = null;
  t.attackActive = false;
}

// Un tick dell'aquila con la preda: avanti e su per carryMs, poi la molla col colpo e vola via senza colpire più
function carry(p: Projectile, sp: SupremeEagle, byId: Map<string, Fighter>, dtMs: number, ctx: PhysicsContext, end: (p: Projectile, reason: "expired") => void): void {
  const owner = byId.get(p.ownerId);
  const t = byId.get(p.carryId!);
  const dir: 1 | -1 = p.vx >= 0 ? 1 : -1;
  p.carryMs! += dtMs;
  p.vx = dir * sp.carrySpeed;
  p.vy = -sp.carryRise;
  p.x += (p.vx * dtMs) / 1000;
  p.y += (p.vy * dtMs) / 1000;
  if (!t || t.eliminated || t.respawning || !owner) {
    end(p, "expired"); // la preda è andata KO (o chi l'ha tirata è uscito): l'aquila sparisce
    return;
  }
  holdPrey(p, sp, t);
  if (p.carryMs! < sp.carryMs) return;
  p.carryId = undefined;
  p.spent = true;
  p.ageMs = Math.max(p.ageMs, sp.lifeMs - 500); // ancora mezzo secondo di volo, poi sparisce
  launch(t, { ...owner, facing: dir }, p.kind, Math.round(p.x), Math.round(p.y), ctx, undefined, sp);
  t.hitstopTimer = Math.max(t.hitstopTimer, Math.min(HITSTOP.maxMs, HITSTOP.baseMs + HITSTOP.perDamageMs * sp.damage));
}

// I numeri del proiettile: quelli della speciale del personaggio che l'ha tirato (fire controlla il tipo),
// o dell'aquila della sua suprema
const SLOT_OF = Object.fromEntries(Object.entries(SPECIAL_KINDS).map(([slot, kind]) => [kind, slot])) as Record<SpecialKind, SpecialSlot>;
const specOf = (p: Projectile): ProjectileSpecial => {
  const sup = getCharacter(p.characterId).supreme;
  if (p.supreme && sup?.type === "spin" && sup.eagle) return sup.eagle;
  return specialsFor(p.characterId)[SLOT_OF[p.kind]] as ProjectileSpecial;
};

// Il rettangolo del proiettile: range × height intorno al centro
const boxOf = (p: Projectile, sp: ProjectileSpecial) => ({ x: p.x - sp.range / 2, y: p.y - sp.height / 2, w: sp.range, h: sp.height });

// Per lo snapshot: solo quello che serve al client
export const projectileStates = (world: ProjectileWorld): ProjectileState[] =>
  world.list.map((p) => ({ id: p.id, ownerId: p.ownerId, kind: p.kind, characterId: p.characterId, x: Math.round(p.x), y: Math.round(p.y), vx: Math.round(p.vx), vy: Math.round(p.vy), ...(p.supreme ? { supreme: true } : {}) }));

// Le pozze dell'IRA (#13): la merda che cade sopra un blocco resta lì per un po', le più vecchie spariscono per prime
function dropPuddle(world: ProjectileWorld, p: Projectile, ctx: PhysicsContext): void {
  const half = SLICK.width / 2;
  const s = ctx.stage.solids.find((s) => p.x >= s.x && p.x <= s.x + s.width && p.y <= s.y + SLICK.landSlackPx && p.vy > 0);
  if (!s || s.width < SLICK.width) return; // presa di lato o da sotto: niente pozza
  const x = Math.round(Math.min(s.x + s.width - half, Math.max(s.x + half, p.x)));
  world.puddles.push({ id: p.id, ownerId: p.ownerId, x, y: s.y, width: SLICK.width, lifeMs: SLICK.lifeMs });
  if (world.puddles.length > SLICK.max) world.puddles.shift();
}

function stepPuddles(world: ProjectileWorld, dtMs: number): void {
  if (world.puddles.length === 0) return;
  for (const q of world.puddles) q.lifeMs -= dtMs;
  world.puddles = world.puddles.filter((q) => q.lifeMs > 0);
}

// f ha i piedi su una pozza non sua? Allora a terra scivola (movement.ts)
export const onPuddle = (f: Fighter, ctx: PhysicsContext): boolean =>
  f.onGround && (ctx.projectiles?.puddles ?? []).some((q) => q.ownerId !== f.id && Math.abs(f.y - q.y) < 2 && Math.abs(f.x - q.x) < q.width / 2 + FIGHTER.width / 4);

export const puddleStates = (world: ProjectileWorld): PuddleState[] => world.puddles.map(({ id, ownerId, x, y, width }) => ({ id, ownerId, x, y, width }));
