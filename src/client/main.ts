import Phaser from "phaser";
import { WORLD } from "../shared/constants";
import { GameScene } from "./GameScene";
import { connect, readRoomAndName } from "./network";

const { room, name, characterId } = readRoomAndName();
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

game.scene.add("game", GameScene, true, { socket, room, name, characterId });
