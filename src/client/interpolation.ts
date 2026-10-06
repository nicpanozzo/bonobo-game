import { NET } from "../shared/constants";

// Interpolazione degli snapshot (la tecnica dei giochi online con server autoritativo):
// si disegna il mondo com'era NET.interpolationDelayMs fa, a metà tra i due snapshot
// che stanno attorno a quell'istante. Niente Phaser qui, così si testa da solo.

export interface Point {
  x: number;
  y: number;
}

interface Frame<T> {
  t: number; // ora del server (GameSnapshot.t)
  positions: Map<string, T>;
}

// T è lo stato di un giocatore (basta che abbia x e y): si restituisce lo stato dello
// snapshot più vecchio dei due, con la posizione interpolata, così animazioni e posizione vanno insieme
export class SnapshotBuffer<T extends Point = Point> {
  private frames: Frame<T>[] = [];
  private offset: number | null = null; // ora locale - ora del server, stimata

  // receivedAt: ora locale di arrivo, nella stessa unità di serverTime (ms)
  push(serverTime: number, receivedAt: number, positions: Map<string, T>) {
    // Lo scarto più piccolo visto è il più vicino al vero: i ritardi di rete lo fanno solo crescere.
    // Si lascia salire piano, nel caso gli orologi derivino.
    const sample = receivedAt - serverTime;
    this.offset = this.offset === null ? sample : Math.min(sample, this.offset + 0.5);
    const last = this.frames[this.frames.length - 1];
    if (last && serverTime <= last.t) return; // fuori ordine o doppio
    this.frames.push({ t: serverTime, positions });
    if (this.frames.length > NET.bufferSize) this.frames.shift();
  }

  // Posizione da disegnare per un giocatore all'ora locale `now`
  sample(id: string, now: number): T | undefined {
    if (this.offset === null || this.frames.length === 0) return undefined;
    const renderTime = now - this.offset - NET.interpolationDelayMs;
    const frames = this.frames;
    // Il più recente prima di renderTime e il primo dopo
    let i = frames.length - 1;
    while (i > 0 && frames[i].t > renderTime) i--;
    const a = frames[i];
    const b = frames[i + 1];
    const pa = a.positions.get(id);
    if (!b || !pa || renderTime <= a.t) return pa ?? latest(frames, id);
    const pb = b.positions.get(id);
    if (!pb) return pa;
    if (Math.abs(pb.x - pa.x) > NET.teleportDistance || Math.abs(pb.y - pa.y) > NET.teleportDistance) {
      return renderTime - a.t < b.t - renderTime ? pa : pb;
    }
    const k = (renderTime - a.t) / (b.t - a.t);
    return { ...pa, x: pa.x + (pb.x - pa.x) * k, y: pa.y + (pb.y - pa.y) * k };
  }
}

function latest<T>(frames: Frame<T>[], id: string): T | undefined {
  for (let i = frames.length - 1; i >= 0; i--) {
    const p = frames[i].positions.get(id);
    if (p) return p;
  }
  return undefined;
}
