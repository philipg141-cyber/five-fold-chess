/**
 * Fivefold Chess — Cloud Functions entry point.
 *
 * Exposes:
 *   - submitMove   (HTTPS callable)     v2 onCall
 *   - finalizeGame (Firestore trigger)  v2 onWrite on /games/{id}
 *
 * Deploy:        firebase deploy --only functions
 * Run locally:   npm run serve   (uses the Firebase emulator suite)
 */

import * as admin from "firebase-admin";

admin.initializeApp();

export {submitMove} from "./submitMove";
export {finalizeGame} from "./finalizeGame";
