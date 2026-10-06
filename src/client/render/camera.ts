import Phaser from "phaser";
import { FIGHTER, WORLD } from "../../shared/constants";
import type { PlayerState } from "../../shared/types";

const CAMERA = {
  minZoom: 0.75,
  maxZoom: 1.25,
  padding: 180,
  lerp: 0.08,
};

export class GameCamera {
  private readonly camera: Phaser.Cameras.Scene2D.Camera;

  constructor(scene: Phaser.Scene) {
    this.camera = scene.cameras.main;

    this.camera.setBounds(0, 0, WORLD.width, WORLD.height);
    this.camera.setZoom(1);
  }

  update(players: PlayerState[]) {
    if (players.length === 0) {
      return;
    }

    const alivePlayers = players.filter((player) => !player.ko);
    const trackedPlayers =
      alivePlayers.length > 0 ? alivePlayers : players;

    let minX = Infinity;
    let maxX = -Infinity;
    let minY = Infinity;
    let maxY = -Infinity;

    for (const player of trackedPlayers) {
      const halfWidth = FIGHTER.width / 2;
      const halfHeight = FIGHTER.height;

      minX = Math.min(minX, player.x - halfWidth);
      maxX = Math.max(maxX, player.x + halfWidth);
      minY = Math.min(minY, player.y - halfHeight);
      maxY = Math.max(maxY, player.y);
    }

    const centerX = (minX + maxX) / 2;
    const centerY = (minY + maxY) / 2;

    const requiredWidth = maxX - minX + CAMERA.padding * 2;
    const requiredHeight = maxY - minY + CAMERA.padding * 2;

    const zoomX = WORLD.width / requiredWidth;
    const zoomY = WORLD.height / requiredHeight;

    const targetZoom = Phaser.Math.Clamp(
      Math.min(zoomX, zoomY),
      CAMERA.minZoom,
      CAMERA.maxZoom,
    );

    this.camera.zoom = Phaser.Math.Linear(
      this.camera.zoom,
      targetZoom,
      CAMERA.lerp,
    );

    const halfVisibleWidth = WORLD.width / (2 * this.camera.zoom);
    const halfVisibleHeight = WORLD.height / (2 * this.camera.zoom);

    const targetX = Phaser.Math.Clamp(
      centerX,
      halfVisibleWidth,
      WORLD.width - halfVisibleWidth,
    );

    const targetY = Phaser.Math.Clamp(
      centerY,
      halfVisibleHeight,
      WORLD.height - halfVisibleHeight,
    );

    this.camera.scrollX = Phaser.Math.Linear(
      this.camera.scrollX,
      targetX - halfVisibleWidth,
      CAMERA.lerp,
    );

    this.camera.scrollY = Phaser.Math.Linear(
      this.camera.scrollY,
      targetY - halfVisibleHeight,
      CAMERA.lerp,
    );
  }
}