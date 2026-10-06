import Phaser from "phaser";
import { CHARACTERS, getCharacter, type AnimationName } from "../../shared/characters";
import { ATTACKS, FIGHTER, WORLD } from "../../shared/constants";
import type { GameSnapshot, PlayerState } from "../../shared/types";
import type { MatchInfo, RenderModule } from "./module";

// Come appare un giocatore sullo schermo: lo sprite del suo personaggio,
// o un rettangolo colorato per chi non ce l'ha ancora.
interface FighterView {
  body: Phaser.GameObjects.Rectangle;
  fist: Phaser.GameObjects.Rectangle;
  label: Phaser.GameObjects.Text;
  marker: Phaser.GameObjects.Triangle; // freccia sul bordo quando si è fuori schermo
  sprite?: Phaser.GameObjects.Sprite; // solo per i personaggi con spritesheet; il rettangolo resta come riferimento
  target: PlayerState; // ultimo stato ricevuto dal server
}

// Da chiamare in preload() della scena
export function preloadCharacters(scene: Phaser.Scene) {
  for (const c of Object.values(CHARACTERS)) {
    if (!c.sprite) continue;
    scene.load.spritesheet(c.id, c.sprite.path, { frameWidth: c.sprite.frameWidth, frameHeight: c.sprite.frameHeight });
  }
}

export class FighterViews implements RenderModule {
  private views = new Map<string, FighterView>();
  private myId = "";

  constructor(private scene: Phaser.Scene) {
    // Un'animazione per riga dello spritesheet, con chiave "<personaggio>-<animazione>"
    for (const c of Object.values(CHARACTERS)) {
      if (!c.sprite) continue;
      for (const [name, a] of Object.entries(c.sprite.animations)) {
        const key = `${c.id}-${name}`;
        if (scene.anims.exists(key)) continue; // la scena può ripartire: le animazioni sono globali
        const start = a.row * c.sprite.columns;
        scene.anims.create({
          key,
          frames: scene.anims.generateFrameNumbers(c.id, { start, end: start + a.frames - 1 }),
          frameRate: a.fps,
          repeat: a.loop ? -1 : 0,
        });
      }
    }
  }

  onWelcome(info: MatchInfo) {
    this.myId = info.myId;
  }

  // Posizione sullo schermo (centro del corpo), per effetti e telecamera
  positionOf(id: string): { x: number; y: number } | undefined {
    const v = this.views.get(id);
    return v && { x: v.body.x, y: v.body.y };
  }

  onSnapshot(snap: GameSnapshot) {
    const seen = new Set<string>();
    for (const p of snap.players) {
      seen.add(p.id);
      let v = this.views.get(p.id);
      if (!v) {
        v = this.createView(p);
        this.views.set(p.id, v);
      }
      v.target = p;
    }
    for (const [id, v] of this.views) {
      if (seen.has(id)) continue;
      v.body.destroy();
      v.fist.destroy();
      v.label.destroy();
      v.marker.destroy();
      v.sprite?.destroy();
      this.views.delete(id);
    }
  }

  update(_time: number, delta: number) {
    // Interpolazione: ci avviciniamo dolcemente all'ultimo stato del server
    const k = Math.min(1, delta / 50);
    for (const v of this.views.values()) {
      const t = v.target;
      const tx = t.x;
      const ty = t.y - FIGHTER.height / 2;
      // Dopo un respawn si salta direttamente alla nuova posizione
      if (Math.abs(tx - v.body.x) > 300 || Math.abs(ty - v.body.y) > 300) {
        v.body.setPosition(tx, ty);
      } else {
        v.body.x += (tx - v.body.x) * k;
        v.body.y += (ty - v.body.y) * k;
      }
      this.layout(v);
    }
  }

  private createView(p: PlayerState): FighterView {
    const s = this.scene;
    const body = s.add.rectangle(p.x, p.y - FIGHTER.height / 2, FIGHTER.width, FIGHTER.height, p.color);
    if (p.id === this.myId) body.setStrokeStyle(3, 0xffffff);
    const fist = s.add.rectangle(0, 0, 10, 10, 0xffffff).setVisible(false);
    const label = s.add.text(0, 0, p.name, { fontSize: "14px", color: "#ffffff" }).setOrigin(0.5, 1);
    const marker = s.add.triangle(0, 0, 0, 0, 20, 0, 10, 16, p.color).setVisible(false);
    const character = getCharacter(p.characterId);
    let sprite: Phaser.GameObjects.Sprite | undefined;
    if (character.sprite && s.textures.exists(character.id)) {
      // I piedi dello sprite coincidono con quelli del giocatore (y in PlayerState)
      sprite = s.add.sprite(p.x, p.y, character.id).setOrigin(0.5, 1);
      body.setVisible(false);
    }
    return { body, fist, label, marker, sprite, target: p };
  }

  private layout(v: FighterView) {
    const t = v.target;
    const hidden = t.respawning || t.eliminated;
    const top = v.body.y - FIGHTER.height / 2;
    const alpha = t.invulnerable ? 0.4 + 0.3 * Math.sin(this.scene.time.now / 60) : 1;
    v.label.setVisible(!hidden);
    if (v.sprite) {
      v.sprite.setVisible(!hidden).setAlpha(alpha);
      v.sprite.setPosition(v.body.x, v.body.y + FIGHTER.height / 2);
      v.sprite.setFlipX(t.facing === -1);
      const key = `${t.characterId}-${animationFor(t)}`;
      if (v.sprite.anims.currentAnim?.key !== key) v.sprite.play(key);
    } else {
      v.body.setVisible(!hidden);
      v.body.setAlpha(alpha);
      v.body.setFillStyle(t.hitstun ? 0xffffff : t.color);
    }

    // Il colpo si vede già durante la preparazione (più trasparente), pieno quando può colpire
    if (t.attack && !hidden) {
      const spec = ATTACKS[t.attack];
      v.fist.setVisible(true);
      v.fist.setSize(spec.range, spec.height);
      v.fist.setDisplaySize(spec.range, spec.height);
      v.fist.setAlpha(t.attackActive ? 1 : 0.3);
      v.fist.setFillStyle(t.attack === "heavy" ? 0xff9f43 : 0xffffff);
      v.fist.x = v.body.x + t.facing * (FIGHTER.width / 2 + spec.range / 2);
      v.fist.y = top + FIGHTER.height * 0.3 + spec.height / 2;
    } else {
      v.fist.setVisible(false);
    }

    v.label.setPosition(v.body.x, top - 6);

    // Freccia sul bordo dello schermo per chi è stato lanciato fuori
    const off = v.body.x < 0 || v.body.x > WORLD.width || v.body.y < 0 || v.body.y > WORLD.height;
    v.marker.setVisible(off && !hidden);
    if (off) {
      const mx = Phaser.Math.Clamp(v.body.x, 16, WORLD.width - 16);
      const my = Phaser.Math.Clamp(v.body.y, 16, WORLD.height - 16);
      v.marker.setPosition(mx, my);
      v.marker.setRotation(Math.atan2(v.body.y - my, v.body.x - mx) - Math.PI / 2);
    }
  }
}

// Quale animazione mostrare, dai soli campi dello snapshot
function animationFor(p: PlayerState): AnimationName {
  if (p.hitstun) return "hit";
  if (p.attack) return p.attack;
  if (!p.onGround) return p.vy < 0 ? "jump" : "fall";
  if (Math.abs(p.vx) > 20) return "walk";
  return "idle";
}
