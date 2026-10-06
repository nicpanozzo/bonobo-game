import type Phaser from "phaser";
import type { InputState } from "../shared/types";

// Tastiera → InputState. È l'unica cosa che il client manda al server.
export class KeyboardInput {
  private keys: Record<string, Phaser.Input.Keyboard.Key>;

  constructor(scene: Phaser.Scene) {
    this.keys = scene.input.keyboard!.addKeys("LEFT,RIGHT,UP,DOWN,A,D,W,S,SPACE,J,K,T") as Record<string, Phaser.Input.Keyboard.Key>;
  }

  read(): InputState {
    const k = this.keys;
    return {
      left: k.LEFT.isDown || k.A.isDown,
      right: k.RIGHT.isDown || k.D.isDown,
      up: k.UP.isDown || k.W.isDown || k.SPACE.isDown,
      down: k.DOWN.isDown || k.S.isDown,
      light: k.J.isDown,
      heavy: k.K.isDown,
      taunt: k.T.isDown,
    };
  }
}
