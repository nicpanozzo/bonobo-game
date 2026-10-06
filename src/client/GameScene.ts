import Phaser from "phaser";
import { ATTACK, FIGHTER, WORLD } from "../shared/constants";
import type { GameSnapshot, InputState, PlayerState } from "../shared/types";
import type { GameSocket } from "./network";
import { GameCamera } from "./render/camera";

// Come appare un giocatore sullo schermo. Per ora sono rettangoli:
// sostituirli con sprite animati è un ottimo primo contributo!
interface FighterView {
  body: Phaser.GameObjects.Rectangle;
  fist: Phaser.GameObjects.Rectangle;
  label: Phaser.GameObjects.Text;
  hpBack: Phaser.GameObjects.Rectangle;
  hpBar: Phaser.GameObjects.Rectangle;
  target: PlayerState;
}

export class GameScene extends Phaser.Scene {
  private socket!: GameSocket;
  private myId = "";
  private views = new Map<string, FighterView>();
  private keys!: Record<string, Phaser.Input.Keyboard.Key>;
  private lastInput = "";
  private statusText!: Phaser.GameObjects.Text;
  private scoreText!: Phaser.GameObjects.Text;
  private gameCamera!: GameCamera;

  constructor() {
    super("game");
  }

  init(data: { socket: GameSocket; room: string; name: string }) {
    this.socket = data.socket;

    this.socket.on("welcome", ({ id, room }) => {
      this.myId = id;
      this.statusText.setText(
        `Stanza: ${room} · manda il link agli amici`,
      );
    });

    this.socket.on("roomFull", () =>
      this.statusText.setText(
        "Stanza piena! Prova con un altro ?room=",
      ),
    );

    this.socket.on("snapshot", (snap) => this.applySnapshot(snap));

    this.socket.on("connect", () =>
      this.socket.emit("join", {
        room: data.room,
        name: data.name,
      }),
    );

    this.socket.on("disconnect", () =>
      this.statusText.setText(
        "Connessione persa, riprovo...",
      ),
    );

    if (this.socket.connected) {
      this.socket.emit("join", {
        room: data.room,
        name: data.name,
      });
    }
  }

  create() {
    this.gameCamera = new GameCamera(this);

    // Sfondo e pavimento
    this.add.rectangle(
      WORLD.width / 2,
      WORLD.height / 2,
      WORLD.width,
      WORLD.height,
      0x1d2b3a,
    );

    this.add.rectangle(
      WORLD.width / 2,
      WORLD.floorY + 30,
      WORLD.width,
      60,
      0x3b2a1a,
    );

    // HUD
    this.statusText = this.add
      .text(
        12,
        10,
        "Connessione...",
        {
          fontSize: "16px",
          color: "#ffffff",
        },
      )
      .setScrollFactor(0);

    this.scoreText = this.add
      .text(
        WORLD.width - 12,
        10,
        "",
        {
          fontSize: "16px",
          color: "#ffffff",
          align: "right",
        },
      )
      .setOrigin(1, 0)
      .setScrollFactor(0);

    const kb = this.input.keyboard!;

    this.keys = kb.addKeys(
      "LEFT,RIGHT,UP,A,D,W,J,SPACE",
    ) as Record<string, Phaser.Input.Keyboard.Key>;
  }

  update(_time: number, delta: number) {
    this.sendInput();

    // Interpolazione: ci avviciniamo dolcemente
    // all'ultimo stato ricevuto dal server.
    const k = Math.min(1, delta / 50);

    for (const v of this.views.values()) {
      const t = v.target;

      v.body.x += (t.x - v.body.x) * k;

      v.body.y +=
        (t.y - FIGHTER.height / 2 - v.body.y) * k;

      this.layout(v);
    }

    // La camera segue tutti i giocatori.
    this.gameCamera.update(
      Array.from(this.views.values()).map(
        (view) => view.target,
      ),
    );
  }

  private sendInput() {
    const input: InputState = {
      left:
        this.keys.LEFT.isDown ||
        this.keys.A.isDown,

      right:
        this.keys.RIGHT.isDown ||
        this.keys.D.isDown,

      jump:
        this.keys.UP.isDown ||
        this.keys.W.isDown,

      attack:
        this.keys.J.isDown ||
        this.keys.SPACE.isDown,
    };

    // Mandiamo l'input solo quando cambia,
    // per non intasare la rete.
    const key = JSON.stringify(input);

    if (
      key !== this.lastInput &&
      this.socket.connected
    ) {
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
      if (seen.has(id)) {
        continue;
      }

      v.body.destroy();
      v.fist.destroy();
      v.label.destroy();
      v.hpBack.destroy();
      v.hpBar.destroy();

      this.views.delete(id);
    }

    this.scoreText.setText(
      snap.players
        .slice()
        .sort((a, b) => b.kos - a.kos)
        .map(
          (p) => `${p.name}: ${p.kos} KO`,
        )
        .join("\n"),
    );
  }

  private createView(
    p: PlayerState,
  ): FighterView {
    const body = this.add.rectangle(
      p.x,
      p.y - FIGHTER.height / 2,
      FIGHTER.width,
      FIGHTER.height,
      p.color,
    );

    if (p.id === this.myId) {
      body.setStrokeStyle(
        3,
        0xffffff,
      );
    }

    const fist = this.add
      .rectangle(
        0,
        0,
        ATTACK.range,
        ATTACK.height,
        0xffffff,
      )
      .setVisible(false);

    const label = this.add
      .text(
        0,
        0,
        p.name,
        {
          fontSize: "14px",
          color: "#ffffff",
        },
      )
      .setOrigin(0.5, 1);

    const hpBack = this.add.rectangle(
      0,
      0,
      60,
      6,
      0x000000,
    );

    const hpBar = this.add
      .rectangle(
        0,
        0,
        60,
        6,
        0x2ecc71,
      )
      .setOrigin(0, 0.5);

    return {
      body,
      fist,
      label,
      hpBack,
      hpBar,
      target: p,
    };
  }

  private layout(v: FighterView) {
    const t = v.target;

    const top =
      v.body.y -
      FIGHTER.height / 2;

    v.body.setAlpha(
      t.ko ? 0.25 : 1,
    );

    v.body.setFillStyle(
      t.hitstun
        ? 0xffffff
        : t.color,
    );

    v.fist.setVisible(
      t.attacking,
    );

    v.fist.x =
      v.body.x +
      t.facing *
        (FIGHTER.width / 2 +
          ATTACK.range / 2);

    v.fist.y =
      top +
      FIGHTER.height * 0.25 +
      ATTACK.height / 2;

    v.label.setPosition(
      v.body.x,
      top - 12,
    );

    v.hpBack.setPosition(
      v.body.x,
      top - 6,
    );

    v.hpBar.setPosition(
      v.body.x - 30,
      top - 6,
    );

    v.hpBar.width =
      60 *
      (t.hp / FIGHTER.maxHp);
  }
}