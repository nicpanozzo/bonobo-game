import Phaser from "phaser";
import { WORLD } from "../shared/constants";
import { GameScene } from "./GameScene";
import { LobbyScene } from "./LobbyScene";
import { connect, hasDirectJoin, readJoinDefaults } from "./network";

const game = new Phaser.Game({
  type: Phaser.AUTO,
  parent: "game",
  width: WORLD.width,
  height: WORLD.height,
  backgroundColor: "#111111",
  scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
  scene: [],
});

// Prima la lobby; con ?room=...&name=... nell'URL si salta dritti in partita
const defaults = readJoinDefaults();
game.scene.add("lobby", LobbyScene, false);
game.scene.add("game", GameScene, false);
if (hasDirectJoin(defaults)) game.scene.start("game", { socket: connect(), ...defaults });
else game.scene.start("lobby", { defaults });
