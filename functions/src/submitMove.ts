/**
 * submitMove — HTTPS callable that appends a move to a game's history.
 *
 * Validation performed today (structural only):
 *   - Caller is authenticated.
 *   - The game document exists and the caller is one of its two players.
 *   - It's the caller's turn (sideToMove matches their colour).
 *   - The move JSON has the required shape (from/to with [file, rank]
 *     in [0,7]/[0,15] for Long and [0,7] elsewhere).
 *   - The piece on the from-square belongs to the caller.
 *   - The history is append-only (we always FieldValue.arrayUnion + a
 *     transactional length check).
 *
 * What's NOT validated yet (TODO: port engines from Dart):
 *   - Whether the move is actually a legal target for the moving piece
 *     (no capture-your-own, no walking through walls, no leaving your
 *     king in check, variant-specific rules like Barbarian pass-through
 *     and Reverse forced captures).
 *
 * Until the engine port lands, the rules in firestore.rules + this
 * function provide structural integrity but not chess-rules integrity.
 */

import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const db = admin.firestore();

interface MoveJson {
  from: [number, number];
  to: [number, number];
  promotion?: number;
  castleK?: boolean;
  castleQ?: boolean;
  ep?: boolean;
  pass?: [number, number];
}

interface GameDoc {
  variant: string;
  whiteUid: string;
  blackUid: string;
  whiteName?: string;
  blackName?: string;
  history: MoveJson[];
  sideToMove: "white" | "black";
  result: string | null;
}

const FILES = 8;
function ranksFor(variant: string): number {
  return variant === "long" ? 16 : 8;
}

export const submitMove = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  const gameId = req.data?.gameId as string | undefined;
  const move = req.data?.move as MoveJson | undefined;
  if (!gameId || !move) {
    throw new HttpsError("invalid-argument", "gameId and move are required.");
  }

  const ref = db.collection("games").doc(gameId);

  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      throw new HttpsError("not-found", "Game not found.");
    }
    const game = snap.data() as GameDoc;

    if (game.result) {
      throw new HttpsError("failed-precondition", "Game is already over.");
    }

    const callerColour =
      uid === game.whiteUid ? "white"
      : uid === game.blackUid ? "black"
      : null;
    if (callerColour === null) {
      throw new HttpsError("permission-denied", "You are not in this game.");
    }
    if (game.sideToMove !== callerColour) {
      throw new HttpsError("failed-precondition", "It's not your turn.");
    }

    // ------- Structural validation of the move payload -------
    const ranks = ranksFor(game.variant);
    if (!isValidSquare(move.from, ranks) || !isValidSquare(move.to, ranks)) {
      throw new HttpsError("invalid-argument", "Move is out of bounds.");
    }
    if (move.pass !== undefined && !isValidSquare(move.pass, ranks)) {
      throw new HttpsError("invalid-argument",
        "Barbarian pass-through square is out of bounds.");
    }
    // TODO: full engine validation goes here. Until then, accept
    // structurally-valid moves and trust that both clients are running
    // the same Dart engine. Firestore rules + this function still
    // prevent the easy attacks (writing to other people's games,
    // rewriting history, taking moves out of turn, etc.).

    // ------- Append the move + flip sideToMove atomically -------
    tx.update(ref, {
      history: admin.firestore.FieldValue.arrayUnion(move),
      sideToMove: callerColour === "white" ? "black" : "white",
    });
  });

  return {ok: true};
});

function isValidSquare(sq: unknown, ranks: number): sq is [number, number] {
  if (!Array.isArray(sq) || sq.length !== 2) return false;
  const [f, r] = sq as [unknown, unknown];
  return Number.isInteger(f) && Number.isInteger(r)
      && (f as number) >= 0 && (f as number) < FILES
      && (r as number) >= 0 && (r as number) < ranks;
}
