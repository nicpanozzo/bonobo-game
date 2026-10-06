import type Phaser from "phaser";
import type { GameEvent } from "../../shared/types";
import type { RenderModule } from "./module";

// Suoni e musica (#6) e voci (#16): partono dagli eventi di gioco (hit, ko, jump, land, taunt...).
export class Audio implements RenderModule {
  constructor(private scene: Phaser.Scene) {}

  onEvent(_event: GameEvent) {
    void this.scene;
  }
}
