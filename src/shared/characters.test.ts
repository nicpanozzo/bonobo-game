import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ATTACKS } from "./constants";
import {
  ANIMATION_FALLBACK,
  ANIMATION_NAMES,
  CHARACTERS,
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
