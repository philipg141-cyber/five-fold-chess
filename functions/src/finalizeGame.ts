/**
 * finalizeGame — Firestore trigger that updates per-variant ELO when a
 * game's `result` field transitions from null to a final value.
 *
 * Result values: "white" | "black" | "draw".
 *
 * Uses standard Elo with K=24. The same formula runs server-side for both
 * players, so cheating clients can't inflate their own rating.
 */

import * as admin from "firebase-admin";
import {onDocumentWritten} from "firebase-functions/v2/firestore";

const db = admin.firestore();
const K_FACTOR = 24;
const DEFAULT_ELO = 1200;

interface GameDoc {
  variant: string;
  whiteUid: string;
  blackUid: string;
  result: "white" | "black" | "draw" | null;
}

const ELO_FIELD: Record<string, string> = {
  classic:   "eloClassic",
  long:      "eloLong",
  silent:    "eloSilent",
  reverse:   "eloReverse",
  barbarian: "eloBarbarian",
};

export const finalizeGame = onDocumentWritten("games/{gameId}", async (e) => {
  const before = e.data?.before.data() as GameDoc | undefined;
  const after  = e.data?.after.data()  as GameDoc | undefined;
  if (!after) return; // doc deleted; nothing to do

  // Only fire when result first becomes non-null.
  if (after.result == null) return;
  if (before && before.result === after.result) return;

  const eloField = ELO_FIELD[after.variant];
  if (!eloField) {
    console.warn(`Unknown variant ${after.variant}; skipping ELO update`);
    return;
  }

  const whiteRef = db.collection("users").doc(after.whiteUid);
  const blackRef = db.collection("users").doc(after.blackUid);

  await db.runTransaction(async (tx) => {
    const whiteSnap = await tx.get(whiteRef);
    const blackSnap = await tx.get(blackRef);
    const wElo = (whiteSnap.data()?.[eloField] as number | undefined)
                 ?? DEFAULT_ELO;
    const bElo = (blackSnap.data()?.[eloField] as number | undefined)
                 ?? DEFAULT_ELO;

    const whiteScore =
      after.result === "white" ? 1 :
      after.result === "draw"  ? 0.5 : 0;
    const blackScore = 1 - whiteScore;

    const expectedWhite = 1 / (1 + Math.pow(10, (bElo - wElo) / 400));
    const expectedBlack = 1 - expectedWhite;

    const newWhite = Math.round(wElo + K_FACTOR * (whiteScore - expectedWhite));
    const newBlack = Math.round(bElo + K_FACTOR * (blackScore - expectedBlack));

    tx.set(whiteRef, {
      [eloField]: newWhite,
      gamesPlayed: admin.firestore.FieldValue.increment(1),
    }, {merge: true});

    tx.set(blackRef, {
      [eloField]: newBlack,
      gamesPlayed: admin.firestore.FieldValue.increment(1),
    }, {merge: true});
  });
});
