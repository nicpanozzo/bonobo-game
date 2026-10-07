// Posti tenuti per la riconnessione (#107): chi perde la rete per qualche secondo rientra nello stesso lottatore.
// Ogni giocatore riceve nel welcome un token segreto; finché il posto è tenuto, quel token lo riporta dentro.
// Puro: l'orologio arriva come parametro, così i test non aspettano davvero. Un Seats per stanza: un token
// non vale in un'altra stanza.
import { randomBytes } from "node:crypto";

export class Seats {
  private tokens = new Map<string, string>(); // token → playerId
  private held = new Map<string, number>(); // playerId → ms in cui il posto scade

  constructor(private readonly holdMs: number) {}

  // Token nuovo per un giocatore appena entrato
  issue(playerId: string): string {
    const token = randomBytes(16).toString("base64url");
    this.tokens.set(token, playerId);
    return token;
  }

  // Il giocatore si è disconnesso: il suo posto resta tenuto fino a now + holdMs
  hold(playerId: string, now: number) {
    this.held.set(playerId, now + this.holdMs);
  }

  isHeld(playerId: string): boolean {
    return this.held.has(playerId);
  }

  get heldCount(): number {
    return this.held.size;
  }

  // Rientro con il token: restituisce il playerId se il posto è ancora tenuto, altrimenti null
  resume(token: string, now: number): string | null {
    const playerId = this.tokens.get(token);
    if (playerId === undefined) return null;
    const until = this.held.get(playerId);
    if (until === undefined || now >= until) return null;
    this.held.delete(playerId);
    return playerId;
  }

  // Posti scaduti: si tolgono qui e chi chiama rimuove i lottatori
  expired(now: number): string[] {
    const gone: string[] = [];
    for (const [playerId, until] of this.held) {
      if (now < until) continue;
      gone.push(playerId);
      this.release(playerId);
    }
    return gone;
  }

  // Il giocatore è uscito del tutto: il suo token non vale più
  release(playerId: string) {
    this.held.delete(playerId);
    for (const [token, id] of this.tokens) if (id === playerId) this.tokens.delete(token);
  }
}
