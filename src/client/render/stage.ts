import Phaser from "phaser";
import { WORLD } from "../../shared/constants";
import { getStage, type StageSpec } from "../../shared/stages";
import type { MatchInfo, RenderModule } from "./module";

// Sfondo, blocchi pieni e piattaforme sottili dell'arena (#14)
export class StageView implements RenderModule {
  private layer?: Phaser.GameObjects.Container;

  constructor(private scene: Phaser.Scene) {
    // L'arena vera arriva con il benvenuto del server; intanto si disegna quella base
    this.draw(getStage(undefined));
  }

  onWelcome(info: MatchInfo) {
    this.draw(getStage(info.stageId));
  }

  private draw(stage: StageSpec) {
    this.layer?.destroy();
    const s = this.scene;
    const layer = s.add.container(0, 0).setDepth(-1);
    layer.add(s.add.rectangle(WORLD.width / 2, WORLD.height / 2, WORLD.width, WORLD.height, stage.colors.sky));
    for (const r of stage.solids) {
      layer.add(s.add.rectangle(r.x, r.y, r.width, r.height, stage.colors.solid).setOrigin(0, 0).setStrokeStyle(4, stage.colors.solidEdge));
    }
    for (const p of stage.platforms) {
      layer.add(s.add.rectangle(p.x, p.y, p.width, 10, stage.colors.platform).setOrigin(0, 0));
    }
    this.layer = layer;
  }
}
