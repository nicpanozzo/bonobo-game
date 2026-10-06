import Phaser from "phaser";
import { WORLD } from "../../shared/constants";
import { getStage, type StageSpec } from "../../shared/stages";
import type { GameEvent } from "../../shared/types";
import type { MatchInfo, RenderModule } from "./module";

// Sfondo, blocchi pieni e piattaforme sottili dell'arena (#14)
export class StageView implements RenderModule {
  private layer?: Phaser.GameObjects.Container;
  private sky?: Phaser.GameObjects.Rectangle;
  private checkpoints: Phaser.GameObjects.Triangle[] = [];
  private myId = "";

  constructor(private scene: Phaser.Scene) {
    // L'arena vera arriva con il benvenuto del server; intanto si disegna quella base
    this.draw(getStage(undefined));
  }

  onWelcome(info: MatchInfo) {
    this.myId = info.myId;
    this.draw(getStage(info.stageId));
  }

  // Il proprio checkpoint diventa verde; a una nuova partita si ricomincia da capo
  onEvent(e: GameEvent) {
    if (e.type === "matchStart") for (const f of this.checkpoints) f.setFillStyle(0x999999);
    if (e.type === "checkpoint" && e.id === this.myId) this.checkpoints.slice(0, e.index).forEach((f) => f.setFillStyle(0x2ecc71));
  }

  private draw(stage: StageSpec) {
    this.layer?.destroy();
    const s = this.scene;
    const layer = s.add.container(0, 0).setDepth(-1);
    // Il cielo resta fermo anche quando la telecamera scorre (percorsi della Corsa)
    this.sky?.destroy();
    this.sky = s.add.rectangle(WORLD.width / 2, WORLD.height / 2, WORLD.width, WORLD.height, stage.colors.sky).setScrollFactor(0).setDepth(-2);
    for (const r of stage.solids) {
      layer.add(s.add.rectangle(r.x, r.y, r.width, r.height, stage.colors.solid).setOrigin(0, 0).setStrokeStyle(4, stage.colors.solidEdge));
    }
    for (const p of stage.platforms) {
      layer.add(s.add.rectangle(p.x, p.y, p.width, 10, stage.colors.platform).setOrigin(0, 0));
    }
    // Corsa (#57): checkpoint (asta grigia, diventa verde quando lo si prende) e traguardo a scacchi
    this.checkpoints = (stage.checkpoints ?? []).slice(1).map((c) => {
      const flag = s.add.triangle(c.x + 2, c.y - 70, 0, 0, 26, 8, 0, 16, 0x999999).setOrigin(0, 0);
      layer.add([s.add.rectangle(c.x, c.y, 4, 70, 0xdddddd).setOrigin(0.5, 1), flag]);
      return flag;
    });
    if (stage.goal) {
      const g = stage.goal;
      const cell = 20;
      for (let y = 0; y < g.height; y += cell)
        for (let x = 0; x < g.width; x += cell)
          layer.add(s.add.rectangle(g.x + x, g.y + y, cell, cell, (x + y) / cell % 2 ? 0x111111 : 0xffffff, 0.75).setOrigin(0, 0));
      layer.add(s.add.text(g.x + g.width / 2, g.y - 8, "ARRIVO", { fontSize: "22px", color: "#ffcf4a", fontStyle: "bold" }).setOrigin(0.5, 1).setStroke("#000000", 4));
    }
    this.layer = layer;
  }
}
