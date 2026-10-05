import Phaser from "phaser";
import { CREDITS } from "./credits";

export class CreditsScene extends Phaser.Scene {
  private content!: Phaser.GameObjects.Container;
  private scrollY = 0;
  private maxScroll = 0;

  constructor() {
    super("credits");
  }

  create() {
    const { width, height } = this.scale;

    this.add
      .rectangle(width / 2, height / 2, width, height, 0x111111)
      .setScrollFactor(0);

    this.add
      .text(width / 2, 30, "TITOLI DI CODA", {
        fontSize: "32px",
        color: "#ffffff",
        fontStyle: "bold",
      })
      .setOrigin(0.5);

    this.add
      .text(width / 2, 70, "Contributori di Bonobo", {
        fontSize: "18px",
        color: "#aaaaaa",
      })
      .setOrigin(0.5);

    this.content = this.add.container(0, 110);

    let y = 0;

    for (const credit of CREDITS) {
      const name = this.add
        .text(width / 2, y, credit.name, {
          fontSize: "22px",
          color: "#ffffff",
          fontStyle: "bold",
        })
        .setOrigin(0.5, 0);

      y += 30;

      const role = this.add
        .text(width / 2, y, credit.role, {
          fontSize: "16px",
          color: "#4fc3f7",
        })
        .setOrigin(0.5, 0);

      y += 25;

      const contribution = this.add
        .text(width / 2, y, credit.contribution, {
          fontSize: "15px",
          color: "#dddddd",
          align: "center",
          wordWrap: { width: width - 80 },
        })
        .setOrigin(0.5, 0);

      this.content.add([name, role, contribution]);

      y += contribution.height + 45;
    }

    this.maxScroll = Math.max(0, y - (height - 150));

    this.add
      .text(width / 2, height - 35, "C / ESC — Torna al gioco", {
        fontSize: "16px",
        color: "#aaaaaa",
      })
      .setOrigin(0.5);

    this.input.keyboard?.on("keydown-C", () => {
      this.scene.start("credits");
    });

    this.input.keyboard?.on("keydown-ESC", () => {
      this.scene.start("game");
    });

    this.input.keyboard?.on("keydown-UP", () => {
      this.scroll(-30);
    });

    this.input.keyboard?.on("keydown-DOWN", () => {
      this.scroll(30);
    });

    this.input.on("wheel", (_pointer: unknown, _gameObjects: unknown, _dx: number, dy: number) => {
      this.scroll(dy);
    });
  }

  private scroll(amount: number) {
    this.scrollY = Phaser.Math.Clamp(
      this.scrollY + amount,
      0,
      this.maxScroll,
    );

    this.content.y = 110 - this.scrollY;
  }
}
