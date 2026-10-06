import type Phaser from "phaser";
import type { GameSnapshot } from "../../shared/types";
import type { RenderModule } from "./module";

// Telecamera che segue e inquadra i giocatori (#12). Per ora resta ferma sull'arena intera.
export class CameraRig implements RenderModule {
  constructor(private scene: Phaser.Scene) {}

  onSnapshot(_snap: GameSnapshot) {
    void this.scene;
  }
}
