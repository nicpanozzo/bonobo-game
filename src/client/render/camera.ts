import type Phaser from "phaser";
import { WORLD } from "../../shared/constants";
import { getStage, stageWidth } from "../../shared/stages";
import type { MatchInfo, RenderModule } from "./module";

// Telecamera. Nelle arene resta ferma sull'arena intera (lo zoom sui giocatori è #12);
// nei percorsi della Corsa (#57), più larghi dello schermo, segue il proprio lottatore.
export class CameraRig implements RenderModule {
  private follow = false;
  private myId = "";

  constructor(
    private scene: Phaser.Scene,
    private positionOf: (id: string) => { x: number; y: number } | undefined,
  ) {}

  onWelcome(info: MatchInfo) {
    const cam = this.scene.cameras.main;
    const width = stageWidth(getStage(info.stageId));
    this.myId = info.myId;
    this.follow = width > WORLD.width;
    cam.setBounds(0, 0, width, WORLD.height);
    cam.setScroll(0, 0);
  }

  update(_time: number, delta: number) {
    if (!this.follow) return;
    const me = this.positionOf(this.myId);
    if (!me) return;
    // Il lottatore sta un po' a sinistra del centro: si vede di più la strada davanti.
    // L'inseguimento morbido toglie gli scatti; i limiti li impone setBounds.
    const cam = this.scene.cameras.main;
    const target = me.x - WORLD.width * 0.4;
    const k = 1 - Math.exp(-delta / 120);
    cam.setScroll(cam.scrollX + (target - cam.scrollX) * k, 0);
  }
}
