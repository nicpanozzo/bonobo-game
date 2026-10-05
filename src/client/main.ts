import Phaser from "phaser";
import { WORLD } from "../shared/constants";
import { CreditsScene } from "./CreditsScene";
import { GameScene } from "./GameScene";
import { connect, readRoomAndName } from "./network";

const { room, name } = readRoomAndName();
const socket = connect();

const game = new Phaser.Game({
  type: Phaser.AUTO,
  parent: "game",
  width: WORLD.width,
  height: WORLD.height,
  backgroundColor: "#111111",
  scale: { mode: Phaser.Scale.FIT, autoCenter: Phaser.Scale.CENTER_BOTH },
  scene: [],
});

game.scene.add("game", GameScene, true, { socket, room, name });
game.scene.add("credits", CreditsScene);

window.addEventListener("keydown", (event) => {
  if (event.key.toLowerCase() !== "c") return;
  if (game.scene.isActive("credits")) return;

  game.scene.pause("game");
  game.scene.start("credits");
});
