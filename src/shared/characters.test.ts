import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { ANIMATION_NAMES, CHARACTERS, OPTIONAL_ANIMATION_NAMES, isSpriteFolder, spriteStatePath, type SpriteFolderSpec } from "./characters";

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
