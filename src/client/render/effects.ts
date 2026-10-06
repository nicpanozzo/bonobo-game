import type Phaser from "phaser";
import type { GameEvent } from "../../shared/types";
import type { RenderModule } from "./module";

// Sensazione dei colpi (#15): particelle, lampi, scossa dello schermo.
// Ascolta gli eventi di gioco: per esempio `hit` porta punto d'impatto e knockback.
export class Effects implements RenderModule {
  constructor(private scene: Phaser.Scene) {}

  onEvent(_event: GameEvent) {
    // Vuoto per ora: è la corsia di #15
    void this.scene;
  }
}
