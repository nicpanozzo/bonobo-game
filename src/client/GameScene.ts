import Phaser from "phaser";
import type { MatchRules } from "../shared/types";
import { KeyboardInput } from "./input";
import type { GameSocket } from "./network";
import { Audio } from "./render/audio";
import { CameraRig } from "./render/camera";
import { Effects } from "./render/effects";
import { FighterViews, preloadCharacters } from "./render/fighters";
import { Hud } from "./render/hud";
import { Results } from "./render/results";
import type { RenderModule } from "./render/module";
import { StageView } from "./render/stage";

export interface JoinData {
  socket: GameSocket;
  room: string;
  name: string;
  characterId?: string;
  stageId?: string; // contano solo se la stanza è nuova
  rules?: Partial<MatchRules>;
}

// La scena della partita fa da regista: collega il server ai moduli in src/client/render/,
// che disegnano, suonano e muovono la telecamera ascoltando snapshot ed eventi.
export class GameScene extends Phaser.Scene {
  private socket!: GameSocket;
  private joinData!: JoinData;
  private modules: RenderModule[] = [];
  private hud!: Hud;
  private keyboard!: KeyboardInput;
  private lastInput = "";

  constructor() {
    super("game");
  }

  init(data: JoinData) {
    this.joinData = data;
    this.socket = data.socket;
  }

  preload() {
    preloadCharacters(this);
  }

  create() {
    this.hud = new Hud(this);
    // L'ordine conta solo per chi disegna sopra chi
    this.modules = [new StageView(this), new FighterViews(this), new Effects(this), new CameraRig(this), new Audio(this), this.hud, new Results(this)];
    this.keyboard = new KeyboardInput(this);
    // A fine partita R fa ripartire subito (il server lo accetta solo se la partita è finita)
    this.input.keyboard!.on("keydown-R", () => this.socket.emit("rematch"));
    this.listen();
  }

  // Si ascolta il server solo dopo create(): con gli sprite da caricare, preload() ritarda la scena
  // e uno snapshot arrivato prima troverebbe i moduli non ancora creati.
  private listen() {
    const { room, name, characterId, stageId, rules } = this.joinData;
    const join = () => this.socket.emit("join", { room, name, characterId, stageId, rules });
    this.socket.on("welcome", ({ id, room, stageId, rules }) => {
      for (const m of this.modules) m.onWelcome?.({ myId: id, room, stageId, rules });
    });
    this.socket.on("roomFull", () => this.hud.setStatus("Stanza piena! Prova con un'altra stanza"));
    this.socket.on("snapshot", (snap) => {
      for (const e of snap.events) for (const m of this.modules) m.onEvent?.(e);
      for (const m of this.modules) m.onSnapshot?.(snap);
    });
    this.socket.on("connect", join);
    this.socket.on("disconnect", () => this.hud.setStatus("Connessione persa, riprovo..."));
    if (this.socket.connected) join();
  }

  update(time: number, delta: number) {
    this.sendInput();
    for (const m of this.modules) m.update?.(time, delta);
  }

  private sendInput() {
    const input = this.keyboard.read();
    // Mandiamo l'input solo quando cambia, per non intasare la rete
    const key = JSON.stringify(input);
    if (key !== this.lastInput && this.socket.connected) {
      this.lastInput = key;
      this.socket.emit("input", input);
    }
  }
}
