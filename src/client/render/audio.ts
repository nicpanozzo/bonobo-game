import type Phaser from "phaser";
import { AUDIO, WORLD } from "../../shared/constants";
import type { GameEvent } from "../../shared/types";
import { getBus, setupAudioUnlock, type AudioBus } from "../audio/engine";
import { Music } from "../audio/music";
import { loadSamples, playSound, type SoundName } from "../audio/sfx";
import { getSettings, updateSettings } from "../settings";
import type { RenderModule } from "./module";

// Suoni e musica (#6) e voci (#16): partono dagli eventi di gioco.
// Qui si decide quale suono va con quale evento; come suona sta in audio/sfx.ts.
export class Audio implements RenderModule {
  private music?: Music;

  constructor(scene: Phaser.Scene) {
    setupAudioUnlock((bus) => this.ready(bus));
    if (getBus()) this.ready(getBus()!);
    // M accende e spegne la musica
    scene.input.keyboard?.on("keydown-M", () => updateSettings({ musicOn: !getSettings().musicOn }));
    scene.events.once("shutdown", () => this.music?.stop());
  }

  private ready(bus: AudioBus) {
    if (this.music) return;
    void loadSamples(bus);
    this.music = new Music(bus);
    this.music.start();
  }

  onEvent(e: GameEvent) {
    const bus = getBus();
    if (!bus || bus.ctx.state !== "running") return;
    // Il suono arriva dal lato dello schermo dove succede la cosa
    const pan = (x: number) => (x / WORLD.width) * 2 - 1;
    const play = (name: SoundName, opts: { volume?: number; pan?: number; pitch?: number } = {}) => playSound(bus, name, opts);

    switch (e.type) {
      case "attack":
        play(e.kind, { volume: 0.7, pitch: 0.95 + Math.random() * 0.1 });
        break;
      case "hit": {
        // Più alta la percentuale del bersaglio, più forte e più grave il colpo
        const strength = Math.min(1, e.percent / AUDIO.hitLoudPercent);
        play(e.kind === "heavy" ? "hitHeavy" : "hitLight", { volume: 0.6 + 0.4 * strength, pan: pan(e.x), pitch: 1.1 - 0.3 * strength });
        break;
      }
      case "jump":
        play(e.air ? "doubleJump" : "jump", { volume: 0.6, pan: pan(e.x) });
        break;
      case "land":
        play("land", { volume: 0.5, pan: pan(e.x) });
        break;
      case "ko":
        play("ko", { pan: pan(Math.max(0, Math.min(WORLD.width, e.x))) });
        break;
      case "taunt":
        play("taunt");
        break;
      case "matchStart":
        play("start");
        break;
      case "matchEnd":
        play("victory");
        break;
    }
  }
}
