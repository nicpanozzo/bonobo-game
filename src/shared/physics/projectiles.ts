// Proiettili delle speciali (E10): li tira una speciale "projectile" e volano da soli.
// Deterministici come il resto della fisica: id in ordine, nessun caso. Si fermano contro i blocchi
// pieni, i lottatori, lo scudo e i proiettili degli altri (si annullano a vicenda).

import { SPECIAL_KINDS, specialsFor, type ProjectileSpecial, type SpecialSlot } from "../characters";
import { FIGHTER, HITSTOP, SPECIAL_MOVES } from "../constants";
import type { ProjectileState, SpecialKind } from "../types";
import { bodyBox, canBeHit, launch, overlap } from "./attacks";
import type { Fighter, PhysicsContext } from "./fighter";
import { hitShield } from "./shield";
import { counterAbsorbs } from "./specials";

export interface Projectile extends ProjectileState {
  ageMs: number;
}

// Tutti i proiettili della partita: li crea match.ts (o il primo tiro, nei test)
export interface ProjectileWorld {
  list: Projectile[];
  nextId: number;
}

export const createProjectileWorld = (): ProjectileWorld => ({ list: [], nextId: 1 });

const worldOf = (ctx: PhysicsContext) => (ctx.projectiles ??= createProjectileWorld());

// Quanti proiettili di f sono in volo: oltre maxAlive la speciale non parte
export const aliveOf = (f: Fighter, ctx: PhysicsContext) => worldOf(ctx).list.filter((p) => p.ownerId === f.id).length;

// Il proiettile esce dalle mani di f, nella direzione in cui guarda
export function fire(f: Fighter, kind: SpecialKind, sp: ProjectileSpecial, ctx: PhysicsContext): void {
  const world = worldOf(ctx);
  const p: Projectile = {
    id: world.nextId++,
    ownerId: f.id,
    kind,
    characterId: f.characterId,
    x: f.x + f.facing * (FIGHTER.width / 2 + sp.range / 2),
    y: f.y - SPECIAL_MOVES.projectileY,
    vx: f.facing * sp.speed,
    vy: -(sp.lift ?? 0),
    ageMs: 0,
  };
  world.list.push(p);
  ctx.events.push({ type: "projectile", id: f.id, projectileId: p.id, x: Math.round(p.x), y: Math.round(p.y) });
}

// Un tick: volo, poi muri, lottatori e altri proiettili
export function stepProjectiles(fighters: Fighter[], dtMs: number, ctx: PhysicsContext): void {
  const world = ctx.projectiles;
  if (!world || world.list.length === 0) return;
  const dt = dtMs / 1000;
  const byId = new Map(fighters.map((f) => [f.id, f]));
  const ended = new Set<Projectile>();
  const end = (p: Projectile, reason: "hit" | "blocked" | "expired" | "wall") => {
    ended.add(p);
    ctx.events.push({ type: "projectileEnd", projectileId: p.id, reason, x: Math.round(p.x), y: Math.round(p.y) });
  };

  for (const p of world.list) {
    const sp = specOf(p);
    p.ageMs += dtMs;
    p.vy += sp.gravity * dt;
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    const box = boxOf(p, sp);
    const z = ctx.stage.blastZone;
    if (p.ageMs >= sp.lifeMs || p.x < z.left || p.x > z.right || p.y < z.top || p.y > z.bottom) end(p, "expired");
    else if (ctx.stage.solids.some((s) => overlap(box, { x: s.x, y: s.y, w: s.width, h: s.height }))) end(p, "wall");
    else hitFighter(p, sp, box, fighters, byId, ctx, end);
  }

  // Due proiettili di giocatori diversi che si toccano si annullano
  const alive = world.list.filter((p) => !ended.has(p));
  for (let i = 0; i < alive.length; i++) {
    for (let j = i + 1; j < alive.length; j++) {
      const a = alive[i];
      const b = alive[j];
      if (ended.has(a) || ended.has(b) || a.ownerId === b.ownerId) continue;
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
    // Il colpo vola nella direzione del proiettile, non in quella in cui guarda chi l'ha tirato
    launch(t, { ...owner, facing: dir }, p.kind, x, y, ctx);
    t.hitstopTimer = Math.max(t.hitstopTimer, Math.min(HITSTOP.maxMs, HITSTOP.baseMs + HITSTOP.perDamageMs * sp.damage));
    end(p, "hit");
    return;
  }
}

// I numeri del proiettile: quelli della speciale del personaggio che l'ha tirato (fire controlla il tipo)
const SLOT_OF = Object.fromEntries(Object.entries(SPECIAL_KINDS).map(([slot, kind]) => [kind, slot])) as Record<SpecialKind, SpecialSlot>;
const specOf = (p: Projectile) => specialsFor(p.characterId)[SLOT_OF[p.kind]] as ProjectileSpecial;

// Il rettangolo del proiettile: range × height intorno al centro
const boxOf = (p: Projectile, sp: ProjectileSpecial) => ({ x: p.x - sp.range / 2, y: p.y - sp.height / 2, w: sp.range, h: sp.height });

// Per lo snapshot: solo quello che serve al client
export const projectileStates = (world: ProjectileWorld): ProjectileState[] =>
  world.list.map((p) => ({ id: p.id, ownerId: p.ownerId, kind: p.kind, characterId: p.characterId, x: Math.round(p.x), y: Math.round(p.y), vx: Math.round(p.vx), vy: Math.round(p.vy) }));

