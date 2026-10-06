import { AUDIO } from "../../shared/constants";
import type { AudioBus } from "./engine";

// Musica di sottofondo sintetizzata: basso, accordi e batteria in loop.
// Le note si programmano con un po' di anticipo sul clock dell'AudioContext,
// così il ritmo resta preciso anche se il gioco rallenta.
// TODO community: una musica nostra (#6) in public/assets/music/

const LOOKAHEAD_S = 0.2;
const STEPS = 16; // sedicesimi in una battuta

// Giro di quattro accordi (La minore, Fa, Do, Sol): note in Hz
const CHORDS = [
  [220, 261.6, 329.6],
  [174.6, 220, 261.6],
  [261.6, 329.6, 392],
  [196, 246.9, 293.7],
];

export class Music {
  private timer: number | undefined;
  private nextTime = 0;
  private step = 0;

  constructor(private bus: AudioBus) {}

  start() {
    if (this.timer !== undefined) return;
    this.nextTime = this.bus.ctx.currentTime + 0.1;
    this.timer = window.setInterval(() => this.schedule(), 50);
  }

  stop() {
    window.clearInterval(this.timer);
    this.timer = undefined;
  }

  private schedule() {
    const stepDur = 60 / AUDIO.musicBpm / 4;
    while (this.nextTime < this.bus.ctx.currentTime + LOOKAHEAD_S) {
      this.playStep(this.step, this.nextTime);
      this.nextTime += stepDur;
      this.step = (this.step + 1) % (STEPS * CHORDS.length);
    }
  }

  private playStep(step: number, t: number) {
    const chord = CHORDS[Math.floor(step / STEPS)];
    const s = step % STEPS;
    if (s % 4 === 0) this.kick(t);
    if (s % 8 === 4) this.snare(t);
    if (s % 2 === 1) this.hat(t);
    if (s % 4 === 0 || s === 6 || s === 14) this.note(t, "triangle", chord[0] / 2, 0.18, 0.35);
    if ([0, 3, 6, 10, 12].includes(s)) this.note(t, "square", chord[(s / 3) % 3 | 0] * 2, 0.09, 0.05);
  }

  private note(t: number, type: OscillatorType, freq: number, dur: number, vol: number) {
    const { ctx, music } = this.bus;
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.type = type;
    o.frequency.value = freq;
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g).connect(music);
    o.start(t);
    o.stop(t + dur + 0.02);
  }

  private kick(t: number) {
    const { ctx, music } = this.bus;
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.frequency.setValueAtTime(140, t);
    o.frequency.exponentialRampToValueAtTime(40, t + 0.12);
    g.gain.setValueAtTime(0.7, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + 0.15);
    o.connect(g).connect(music);
    o.start(t);
    o.stop(t + 0.17);
  }

  private snare(t: number) {
    this.burst(t, 1800, 0.12, 0.25);
  }

  private hat(t: number) {
    this.burst(t, 7000, 0.03, 0.08);
  }

  private burst(t: number, freq: number, dur: number, vol: number) {
    const { ctx, music } = this.bus;
    const buf = ctx.createBuffer(1, Math.ceil(ctx.sampleRate * dur), ctx.sampleRate);
    const d = buf.getChannelData(0);
    for (let i = 0; i < d.length; i++) d[i] = Math.random() * 2 - 1;
    const src = ctx.createBufferSource();
    src.buffer = buf;
    const f = ctx.createBiquadFilter();
    f.type = "highpass";
    f.frequency.value = freq;
    const g = ctx.createGain();
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(f).connect(g).connect(music);
    src.start(t);
  }
}
