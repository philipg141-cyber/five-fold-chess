# Cloud Functions for Fivefold Chess

Server-side logic for online play: move submission validation and ELO updates.

## What's deployed

- **`submitMove`** — HTTPS callable. Clients call this instead of writing
  directly to `/games/{id}`. Validates auth, ownership, and turn order;
  appends the move and flips `sideToMove` atomically.
- **`finalizeGame`** — Firestore trigger on `/games/{id}`. Fires when the
  `result` field transitions from `null` to `"white" | "black" | "draw"`,
  and updates both players' per-variant ELO (K-factor 24) plus their
  `gamesPlayed` counter.

## Prerequisites

1. **Blaze plan.** Cloud Functions require pay-as-you-go billing. The free
   tier covers 2M invocations and 400k GB-seconds of compute per month —
   plenty for a small game, but you must enable billing on the Firebase
   project to deploy.
2. **Node 20.** Set in `package.json`.
3. **Firebase CLI installed globally:**
   ```
   npm install -g firebase-tools
   firebase login
   ```

## First-time setup

From the project root (where `firebase.json` lives):

```
cd functions
npm install
cd ..
firebase use five-fold-chess          # selects the project
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only functions
```

The first deploy takes 2–4 minutes (provisions the Cloud Build pipeline).
Subsequent deploys are usually under a minute.

## Local development

Run everything in the Firebase Emulator Suite:

```
firebase emulators:start
```

This spins up local Firestore, Auth, and Functions on ports listed in
the CLI output. The Flutter app needs to be told to use the emulator —
add this in `main.dart` BEFORE `runApp`:

```dart
if (kDebugMode) {
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
}
```

(For Android emulator, replace `localhost` with `10.0.2.2`.)

## What's NOT validated yet

`submitMove` performs structural validation only — it confirms:

- The caller is signed in and is one of the two players.
- It's the caller's turn.
- The move's from/to squares are in bounds.
- The history grows by exactly one entry per call (append-only).

It does **NOT** verify that the move is actually legal in chess — that
the moving piece can reach the target, that the king isn't left in
check, that variant rules (Barbarian pass-through, Reverse forced
captures) are respected. Doing that requires porting the five Dart rule
engines (`lib/domain/engines/*.dart`) to TypeScript.

Until that port lands, the trust model is:

- **Strong** against drive-by tampering and obvious cheats (bad turns,
  arbitrary writes, history rewrites).
- **Weak** against a custom client that constructs a legal-looking but
  illegal move JSON. Both honest clients running the Dart engine would
  reject such a move on receipt, so the cheater would desync from their
  opponent — but their own local view would advance.

## Engine port plan (when you're ready)

1. Create `functions/src/engines/` mirroring `lib/domain/engines/`.
2. Port `Square`, `Piece`, `Move`, `Board`, `GameState`, `CastlingRights`
   to TypeScript first (pure data, no logic).
3. Port `ClassicEngine.legalMoves()`. Add a comprehensive unit test suite
   (many positions, compare results against the Dart engine's output).
4. Port `SilentEngine`, `LongEngine`, `ReverseEngine`, `BarbarianEngine`
   in that order (Silent and Long are tiny deltas off Classic; Reverse
   and Barbarian are larger).
5. Inside `submitMove`'s transaction, replay the full history then call
   `engine.legalMoves(state)` and reject if `move` isn't in the list.

The port is mostly mechanical translation. Plan ~1–2 days of work plus
a parity test suite.
