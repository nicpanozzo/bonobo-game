import Phaser from "phaser";
import { CHARACTERS, getCharacter, type AnimationName } from "../shared/characters";
import { ATTACKS, FIGHTER, PLATFORMS, STAGE, STOCKS, WORLD } from "../shared/constants";
import type { GameSnapshot, InputState, PlayerState } from "../shared/types";
import type { GameSocket } from "./network";

// Come appare un giocatore sullo schermo. Per ora sono rettangoli:
// sostituirli con sprite animati è un ottimo primo contributo!
interface FighterView {
  body: Phaser.GameObjects.Rectangle;
  fist: Phaser.GameObjects.Rectangle;
  label: Phaser.GameObjects.Text;
  marker: Phaser.GameObjects.Triangle; // freccia sul bordo quando si è fuori schermo
  hud: Phaser.GameObjects.Text;
  sprite?: Phaser.GameObjects.Sprite; // solo per i personaggi con spritesheet; il rettangolo resta come riferimento
  target: PlayerState; // ultimo stato ricevuto dal server
}

interface JoinData {
  socket: GameSocket;
  room: string;
  name: string;
  characterId?: string;
}

const HUD_Y = WORLD.height - 56;

export class GameScene extends Phaser.Scene {
  private socket!: GameSocket;
  private joinData!: JoinData;
  private myId = "";
  private views = new Map<string, FighterView>();
  private keys!: Record<string, Phaser.Input.Keyboard.Key>;
  private lastInput = "";
  private statusText!: Phaser.GameObjects.Text;
  private bannerText!: Phaser.GameObjects.Text;

  constructor() {
    super("game");
  }

  init(data: JoinData) {
    this.joinData = data;
    this.socket = data.socket;
  }

  // Si ascolta il server solo dopo create(): con gli sprite da caricare, preload() ritarda la scena
  // e uno snapshot arrivato prima troverebbe testi e animazioni non ancora creati.
  private listen() {
    const data = this.joinData;
    this.socket.on("welcome", ({ id, room }) => {
      this.myId = id;
      this.statusText.setText(`Stanza: ${room} · manda il link agli amici`);
    });
    this.socket.on("roomFull", () => this.statusText.setText("Stanza piena! Prova con un altro ?room="));
    this.socket.on("snapshot", (snap) => this.applySnapshot(snap));
    this.socket.on("connect", () => this.socket.emit("join", { room: data.room, name: data.name, characterId: data.characterId }));
    this.socket.on("disconnect", () => this.statusText.setText("Connessione persa, riprovo..."));
    if (this.socket.connected) this.socket.emit("join", { room: data.room, name: data.name, characterId: data.characterId });
  }

  preload() {
    for (const c of Object.values(CHARACTERS)) {
      if (!c.sprite) continue;
      this.load.spritesheet(c.id, c.sprite.path, { frameWidth: c.sprite.frameWidth, frameHeight: c.sprite.frameHeight });
    }
  }

  create() {
    // Un'animazione per riga dello spritesheet, con chiave "<personaggio>-<animazione>"
    for (const c of Object.values(CHARACTERS)) {
      if (!c.sprite) continue;
      for (const [name, a] of Object.entries(c.sprite.animations)) {
        const start = a.row * c.sprite.columns;
        this.anims.create({
          key: `${c.id}-${name}`,
          frames: this.anims.generateFrameNumbers(c.id, { start, end: start + a.frames - 1 }),
          frameRate: a.fps,
          repeat: a.loop ? -1 : 0,
        });
      }
    }

    // Sfondo, palco principale e piattaforme sottili
    this.add.rectangle(WORLD.width / 2, WORLD.height / 2, WORLD.width, WORLD.height, 0x1d2b3a);
    this.add
      .rectangle(STAGE.x, STAGE.y, STAGE.width, STAGE.thickness, 0x5a3d26)
      .setOrigin(0, 0)
      .setStrokeStyle(4, 0x8b6a45);
    for (const p of PLATFORMS) {
      this.add.rectangle(p.x, p.y, p.width, 10, 0xa0a8b8).setOrigin(0, 0);
    }

    this.statusText = this.add.text(12, 10, "Connessione...", { fontSize: "16px", color: "#ffffff" });
    this.bannerText = this.add
      .text(WORLD.width / 2, 200, "", { fontSize: "48px", color: "#ffffff", fontStyle: "bold" })
      .setOrigin(0.5)
      .setDepth(10);

    const kb = this.input.keyboard!;
    this.keys = kb.addKeys("LEFT,RIGHT,UP,DOWN,A,D,W,S,SPACE,J,K") as Record<string, Phaser.Input.Keyboard.Key>;

    this.listen();
  }

  update(_time: number, delta: number) {
    this.sendInput();

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

  private sendInput() {
    const k = this.keys;
    const input: InputState = {
      left: k.LEFT.isDown || k.A.isDown,
      right: k.RIGHT.isDown || k.D.isDown,
      up: k.UP.isDown || k.W.isDown || k.SPACE.isDown,
      down: k.DOWN.isDown || k.S.isDown,
      light: k.J.isDown,
      heavy: k.K.isDown,
    };
    // Mandiamo l'input solo quando cambia, per non intasare la rete
    const key = JSON.stringify(input);
    if (key !== this.lastInput && this.socket.connected) {
      this.lastInput = key;
      this.socket.emit("input", input);
    }
  }

  private applySnapshot(snap: GameSnapshot) {
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
      v.hud.destroy();
      v.sprite?.destroy();
      this.views.delete(id);
    }

    // Riquadri in basso con percentuale e vite, uno per giocatore
    const ordered = snap.players;
    ordered.forEach((p, i) => {
      const v = this.views.get(p.id)!;
      const slot = WORLD.width / Math.max(ordered.length, 1);
      v.hud.setPosition(slot * i + slot / 2, HUD_Y);
      v.hud.setText(`${p.name}\n${p.eliminated ? "OUT" : `${p.percent}%`}  ${"●".repeat(Math.max(0, p.stocks))}${"○".repeat(Math.max(0, STOCKS - p.stocks))}`);
      v.hud.setColor(percentColor(p.percent, p.eliminated));
    });

    const winner = snap.players.find((p) => p.id === snap.winnerId);
    this.bannerText.setText(winner ? `${winner.name} vince!` : "");
  }

  private createView(p: PlayerState): FighterView {
    const body = this.add.rectangle(p.x, p.y - FIGHTER.height / 2, FIGHTER.width, FIGHTER.height, p.color);
    if (p.id === this.myId) body.setStrokeStyle(3, 0xffffff);
    const fist = this.add.rectangle(0, 0, 10, 10, 0xffffff).setVisible(false);
    const label = this.add.text(0, 0, p.name, { fontSize: "14px", color: "#ffffff" }).setOrigin(0.5, 1);
    const marker = this.add.triangle(0, 0, 0, 0, 20, 0, 10, 16, p.color).setVisible(false);
    const hud = this.add
      .text(0, HUD_Y, "", { fontSize: "20px", color: "#ffffff", align: "center", fontStyle: "bold" })
      .setOrigin(0.5, 0)
      .setStroke(`#${p.color.toString(16).padStart(6, "0")}`, 4);
    const character = getCharacter(p.characterId);
    let sprite: Phaser.GameObjects.Sprite | undefined;
    if (character.sprite && this.textures.exists(character.id)) {
      // I piedi dello sprite coincidono con quelli del giocatore (y in PlayerState)
      sprite = this.add.sprite(p.x, p.y, character.id).setOrigin(0.5, 1);
      body.setVisible(false);
    }
    return { body, fist, label, marker, hud, sprite, target: p };
  }

  private layout(v: FighterView) {
    const t = v.target;
    const hidden = t.respawning || t.eliminated;
    const top = v.body.y - FIGHTER.height / 2;
    const alpha = t.invulnerable ? 0.4 + 0.3 * Math.sin(this.time.now / 60) : 1;
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

// Bianco a 0%, poi giallo, arancione e rosso man mano che si accumula danno
function percentColor(percent: number, eliminated: boolean): string {
  if (eliminated) return "#777777";
  const t = Math.min(percent / 150, 1);
  const g = Math.round(255 * (1 - t * 0.85));
  const b = Math.round(255 * Math.max(0, 1 - t * 2));
  return `rgb(255,${g},${b})`;
}
