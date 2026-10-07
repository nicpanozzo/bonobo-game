import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ATTACKS, DEFAULT_SPECIALS } from "./constants";
import {
  ANIMATION_FALLBACK,
  ANIMATION_NAMES,
  CHARACTERS,
  SPECIAL_SLOTS,
  specialsFor,
  type SpecialSpec,
  OPTIONAL_ANIMATION_NAMES,
  SPRITE_STATES,
  isSpriteFolder,
  resolveAnimation,
  resolvedAnimations,
  spriteStatePath,
  type SpriteFolderSpec,
} from "./characters";

const folder: SpriteFolderSpec = {
  dir: "assets/characters/prova",
  frameWidth: 256,
  frameHeight: 240,
  scale: 0.5,
  animations: {
    idle: { fps: 12, loop: true },
    walk: { fps: 24, loop: true },
    jump: { fps: 24, loop: false },
    fall: { fps: 24, loop: true },
    light: { fps: 24, loop: false },
    heavy: { fps: 24, loop: false },
    hit: { fps: 24, loop: false },
    taunt: { fps: 12, loop: false },
  },
};

describe("stati degli sprite (E7 passo 2)", () => {
  it("ogni nome di stato compare una volta sola, tra obbligatori e facoltativi", () => {
    const all = [...ANIMATION_NAMES, ...OPTIONAL_ANIMATION_NAMES];
    assert.equal(new Set(all).size, all.length);
  });

  it("i personaggi usano solo stati con un nome conosciuto e hanno tutti quelli obbligatori", () => {
    const known = new Set<string>([...ANIMATION_NAMES, ...OPTIONAL_ANIMATION_NAMES]);
    for (const c of Object.values(CHARACTERS)) {
      if (!c.sprite) continue;
      for (const state of Object.keys(c.sprite.animations)) assert.ok(known.has(state), `${c.id}: stato sconosciuto ${state}`);
      for (const state of ANIMATION_NAMES) assert.ok(state in c.sprite.animations, `${c.id}: manca ${state}`);
    }
  });
});

describe("formato cartella", () => {
  it("si distingue dal foglio unico", () => {
    assert.equal(isSpriteFolder(folder), true);
    const sheet = CHARACTERS.bonobot.sprite;
    assert.ok(sheet);
    assert.equal(isSpriteFolder(sheet), false);
  });

  it("ogni stato è <dir>/<stato>.png", () => {
    assert.equal(spriteStatePath(folder, "idle"), "assets/characters/prova/idle.png");
    assert.equal(spriteStatePath(folder, "taunt"), "assets/characters/prova/taunt.png");
  });
});

describe("ripiego delle animazioni (E7 passo 3)", () => {
  it("ogni stato facoltativo, seguendo il ripiego, arriva a uno obbligatorio", () => {
    const required = new Set<string>(ANIMATION_NAMES);
    for (const state of OPTIONAL_ANIMATION_NAMES) {
      assert.ok(required.has(resolveAnimation({}, state)), `${state} non arriva a uno stato obbligatorio`);
      assert.notEqual(ANIMATION_FALLBACK[state], state, `${state} ripiega su sé stesso`);
    }
  });

  it("ogni personaggio ha tutti gli stati risolti", () => {
    for (const c of Object.values(CHARACTERS)) {
      if (!c.sprite) continue;
      const table = resolvedAnimations(c.sprite.animations);
      for (const state of SPRITE_STATES) {
        const a = table[state];
        assert.ok(a, `${c.id}: ${state} non si risolve`);
        assert.ok(Object.hasOwn(c.sprite.animations, a.src), `${c.id}: ${state} ripiega su ${a.src}, che non c'è`);
      }
    }
  });

  it("uno stato disegnato si usa, uno mancante prende il ripiego", () => {
    const table = resolvedAnimations(folder.animations);
    assert.equal(table.taunt.src, "taunt");
    assert.equal(table.lightUp.src, "light");
    assert.equal(table.heavyAir.src, "heavy");
    assert.equal(table.land.src, "idle");
    assert.equal(table.recovery.src, "jump");
    assert.equal(table.tumble.src, "hit");
    assert.equal(table.lightUp.fps, folder.animations.light.fps);
  });

  it("il fotogramma d'impatto sta dentro l'animazione", () => {
    for (const c of Object.values(CHARACTERS)) {
      if (!c.sprite || isSpriteFolder(c.sprite)) continue; // nel formato cartella lo controlla l'export, che conta i fotogrammi
      for (const [state, a] of Object.entries(c.sprite.animations)) {
        if (a.hitFrame === undefined) continue;
        assert.ok(state in ATTACKS, `${c.id}: hitFrame su ${state}, che non è un attacco`);
        assert.ok(a.hitFrame >= 0 && a.hitFrame < a.frames, `${c.id}: hitFrame ${a.hitFrame} fuori da ${a.frames} fotogrammi`);
      }
    }
  });
});

// Mosse speciali (E10 passo 1): numeri sensati per ogni speciale di ogni personaggio
function specialProblems(sp: SpecialSpec): string[] {
  const out: string[] = [];
  const positive = (name: string, v: number) => !(v > 0) && out.push(`${name} = ${v}, deve essere > 0`);
  if (!sp.name) out.push("senza nome");
  positive("range", sp.range);
  positive("height", sp.height);
  positive("baseKnockback", sp.baseKnockback);
  if (!(sp.knockbackGrowth >= 0)) out.push(`knockbackGrowth = ${sp.knockbackGrowth}`);
  if (!(sp.angleDeg >= 0 && sp.angleDeg <= 180)) out.push(`angleDeg = ${sp.angleDeg}, fuori da 0-180`);
  const damage = sp.type === "counter" ? sp.minDamage : sp.damage;
  if (!(damage >= 0 && damage <= 30)) out.push(`danno ${damage}, fuori da 0-30`);
  switch (sp.type) {
    case "projectile":
      for (const k of ["startupMs", "cooldownMs", "speed", "lifeMs", "maxAlive"] as const) positive(k, sp[k]);
      if (!(sp.gravity >= 0)) out.push(`gravity = ${sp.gravity}`);
      break;
    case "dash":
      for (const k of ["startupMs", "durationMs", "speed", "endLagMs"] as const) positive(k, sp[k]);
      break;
    case "charge":
      for (const k of ["minMs", "maxMs", "activeMs", "endLagMs"] as const) positive(k, sp[k]);
      if (!(sp.maxMs > sp.minMs)) out.push("maxMs deve superare minMs");
      if (!(sp.maxMultiplier >= 1 && sp.damage * sp.maxMultiplier <= 30)) out.push(`maxMultiplier = ${sp.maxMultiplier}`);
      break;
    case "counter":
      for (const k of ["startupMs", "windowMs", "endLagMs", "multiplier"] as const) positive(k, sp[k]);
      break;
  }
  return out;
}

describe("mosse speciali (E10 passo 1)", () => {
  it("ogni personaggio ha le tre speciali, con numeri validi", () => {
    for (const id of Object.keys(CHARACTERS)) {
      const specials = specialsFor(id);
      for (const slot of SPECIAL_SLOTS) {
        assert.ok(specials[slot], `${id}: manca la speciale ${slot}`);
        assert.deepEqual(specialProblems(specials[slot]), [], `${id}.${slot}`);
      }
    }
  });

  it("chi non ne ha di sue usa quelle di base, e un id sconosciuto quelle del personaggio base", () => {
    assert.deepEqual(specialsFor("default"), DEFAULT_SPECIALS);
    assert.deepEqual(specialsFor("nessuno"), specialsFor("default"));
  });

  it("il controllo trova i numeri sbagliati", () => {
    const bad = { ...DEFAULT_SPECIALS.side, durationMs: 0, damage: 45 } as SpecialSpec;
    assert.equal(specialProblems(bad).length, 2);
  });

  it("il recupero di un personaggio non tocca gli altri attacchi", () => {
    // Solo i ritocchi dichiarati in characters.ts: nessuno per ora, quindi attackSpecFor = ATTACKS
    for (const c of Object.values(CHARACTERS)) for (const k of Object.keys(c.recovery ?? {})) assert.ok(k in ATTACKS.recovery || k === "speed" || k === "drift", `${c.id}: ${k}`);
  });
});
