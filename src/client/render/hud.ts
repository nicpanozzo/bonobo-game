import Phaser from "phaser";
import { STOCKS, TEAM_NAMES, WORLD } from "../../shared/constants";
import { getStage } from "../../shared/stages";
import type { GameSnapshot, MatchRules } from "../../shared/types";
import type { MatchInfo, RenderModule } from "./module";

const HUD_Y = WORLD.height - 56;

// Scritte sopra il gioco: stato della connessione, riquadri con percentuale e vite, vincitore
export class Hud implements RenderModule {
  private status: Phaser.GameObjects.Text;
  private banner: Phaser.GameObjects.Text;
  private boxes = new Map<string, Phaser.GameObjects.Text>();
  private maxStocks = STOCKS; // vite a testa nelle regole della stanza
  private timer: Phaser.GameObjects.Text;
  private rules?: MatchRules;

  constructor(private scene: Phaser.Scene) {
    this.status = scene.add.text(12, 10, "Connessione...", { fontSize: "16px", color: "#ffffff" }).setDepth(20);
    this.banner = scene.add
      .text(WORLD.width / 2, 200, "", { fontSize: "48px", color: "#ffffff", fontStyle: "bold" })
      .setOrigin(0.5)
      .setDepth(20);
    this.timer = scene.add
      .text(WORLD.width / 2, 12, "", { fontSize: "28px", color: "#ffffff", fontStyle: "bold" })
      .setOrigin(0.5, 0)
      .setStroke("#000000", 4)
      .setDepth(20);
  }

  setStatus(text: string) {
    this.status.setText(text);
  }

  onWelcome(info: MatchInfo) {
    this.maxStocks = info.rules.stocks;
    this.rules = info.rules;
    const mode = info.rules.mode === "teams" ? "Squadre" : "Tutti contro tutti";
    this.setStatus(`Stanza: ${info.room} · ${getStage(info.stageId).name} · ${mode} · manda il link agli amici`);
  }

  onSnapshot(snap: GameSnapshot) {
    // Un riquadro in basso per giocatore
    const seen = new Set<string>();
    const slot = WORLD.width / Math.max(snap.players.length, 1);
    snap.players.forEach((p, i) => {
      seen.add(p.id);
      let box = this.boxes.get(p.id);
      if (!box) {
        box = this.scene.add
          .text(0, HUD_Y, "", { fontSize: "20px", color: "#ffffff", align: "center", fontStyle: "bold" })
          .setOrigin(0.5, 0)
          .setDepth(20)
          .setStroke(`#${p.color.toString(16).padStart(6, "0")}`, 4);
        this.boxes.set(p.id, box);
      }
      box.setPosition(slot * i + slot / 2, HUD_Y);
      const lives = "●".repeat(Math.max(0, p.stocks)) + "○".repeat(Math.max(0, this.maxStocks - p.stocks));
      box.setText(`${p.name}\n${p.eliminated ? "OUT" : `${p.percent}%`}  ${lives}`);
      setColorIfChanged(box, percentColor(p.percent, p.eliminated));
    });
    for (const [id, box] of this.boxes) {
      if (seen.has(id)) continue;
      box.destroy();
      this.boxes.delete(id);
    }

    const winner = snap.players.find((p) => p.id === snap.winnerId);
    const team = winner && this.rules?.mode === "teams" ? TEAM_NAMES[winner.team as 1 | 2] : undefined;
    this.banner.setText(winner ? `${team ? `Squadra ${team}` : winner.name} vince!` : "");

    // Conto alla rovescia, rosso negli ultimi 10 secondi
    if (snap.timeLeftMs === null) {
      this.timer.setText("");
    } else {
      const sec = Math.ceil(snap.timeLeftMs / 1000);
      this.timer.setText(`${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, "0")}`);
      setColorIfChanged(this.timer, sec <= 10 ? "#ff5a4a" : "#ffffff");
    }
  }
}

// setColor ridisegna sempre il testo (in Phaser setText invece controlla già se è cambiato):
// con gli snapshot a 30 al secondo conviene saltarlo quando il colore è lo stesso
function setColorIfChanged(text: Phaser.GameObjects.Text, color: string) {
  if (text.style.color !== color) text.setColor(color);
}

// Bianco a 0%, poi giallo, arancione e rosso man mano che si accumula danno
function percentColor(percent: number, eliminated: boolean): string {
  if (eliminated) return "#777777";
  const t = Math.min(percent / 150, 1);
  const g = Math.round(255 * (1 - t * 0.85));
  const b = Math.round(255 * Math.max(0, 1 - t * 2));
  return `rgb(255,${g},${b})`;
}
