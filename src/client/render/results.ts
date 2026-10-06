import Phaser from "phaser";
import { WORLD } from "../../shared/constants";
import type { GameEvent, GameSnapshot } from "../../shared/types";
import type { RenderModule } from "./module";

interface Stats {
  kos: number; // avversari mandati fuori
  falls: number; // vite perse
  damage: number; // percentuale inflitta
  flags: number; // portabandiera avversari buttati fuori (Bandiera, #56)
}

// Classifica a fine partita, calcolata dagli eventi di gioco (hit, ko)
export class Results implements RenderModule {
  private stats = new Map<string, Stats>();
  private panel: Phaser.GameObjects.Text;
  private shownFor: string | null = null;

  constructor(private scene: Phaser.Scene) {
    this.panel = scene.add
      .text(WORLD.width / 2, 260, "", {
        fontSize: "20px",
        color: "#ffffff",
        align: "center",
        backgroundColor: "#000000aa",
        padding: { x: 24, y: 16 },
        lineSpacing: 6,
      })
      .setOrigin(0.5, 0)
      .setDepth(25)
      .setVisible(false);
  }

  private of(id: string): Stats {
    let s = this.stats.get(id);
    if (!s) this.stats.set(id, (s = { kos: 0, falls: 0, damage: 0, flags: 0 }));
    return s;
  }

  onEvent(e: GameEvent) {
    if (e.type === "matchStart") this.stats.clear();
    if (e.type === "hit") this.of(e.attackerId).damage += e.damage;
    if (e.type === "flag" && e.byId) this.of(e.byId).flags += 1;
    if (e.type === "ko") {
      this.of(e.id).falls += 1;
      if (e.byId) this.of(e.byId).kos += 1;
    }
  }

  onSnapshot(snap: GameSnapshot) {
    if (!snap.winnerId) {
      this.panel.setVisible(false);
      this.shownFor = null;
      return;
    }
    if (this.shownFor === snap.winnerId) return;
    this.shownFor = snap.winnerId;
    const rows = [...snap.players]
      .map((p) => ({ p, s: this.of(p.id) }))
      .sort((a, b) => Number(b.p.id === snap.winnerId) - Number(a.p.id === snap.winnerId) || b.s.flags - a.s.flags || b.s.kos - a.s.kos || b.s.damage - a.s.damage)
      .map(({ p, s }) => `${p.id === snap.winnerId ? "👑 " : ""}${p.name}   ${snap.teamScores ? `🚩 ${s.flags} · ` : ""}KO ${s.kos} · cadute ${s.falls} · danni ${s.damage}%`);
    this.panel.setText([...rows, "", "R: rivincita subito"].join("\n")).setVisible(true);
  }
}
