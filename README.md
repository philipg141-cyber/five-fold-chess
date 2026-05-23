# Fivefold Chess

A cross-platform Flutter chess app featuring five variants:

| Variant       | Summary                                                                 |
|---------------|--------------------------------------------------------------------------|
| Classic       | Standard FIDE rules.                                                     |
| Long          | 8×16 board; standard armies on each end, empty middle.                   |
| Silent        | Standard rules, but the UI never announces check — only mate.            |
| Reverse       | Antichess — lose all pieces to win; captures are forced; king is normal. |
| Barbarian     | Bishops, rooks and queens may pass through ONE piece (any color) to capture another piece; both pieces are removed. |

## Quick start

```bash
flutter pub get
flutter run
```

> The scaffold compiles and runs on Android and iOS. Firebase is stubbed;
> online multiplayer requires running `flutterfire configure` and wiring
> the Cloud Functions `submitMove` endpoint described in the spec.

## Project layout

```
lib/
  main.dart                       # App bootstrap (Hive + AdMob + Firebase)
  app.dart                        # ThemeData + MaterialApp + routes
  domain/                         # Pure Dart — no Flutter imports
    models/                       # Square, Piece, Board, Move, GameState
    engines/                      # RuleEngine + 5 variant implementations
  data/
    ads/admob_service.dart        # Banner + interstitial, frequency cap
    firebase/firebase_service.dart# Auth + Firestore + Cloud Functions stub
  presentation/
    screens/                      # Home, variant picker, game, settings
    widgets/                      # BoardWidget, AdBanner
test/engines/                     # Rule engine unit tests (barbarian covered)
```

## Rule engine abstraction

All five variants implement the same `RuleEngine` interface. The UI, AI,
and networking layers speak only to this interface, so the variants are
fully interchangeable. See the spec doc for the full contract and the
per-variant rule definitions.

## AdMob

`AdMobService` implements a balanced ad strategy:

- **Banner** on menu screens only (Home, Variant picker, Settings) — never in game.
- **Interstitial** on game end, capped at once per 120 seconds AND once per 3 completed games. The first game of a session is always ad-free.

The scaffold uses Google's public **test ad unit IDs**. Replace them in `admob_service.dart` before release; do not ship test IDs to production.

## Firebase (online multiplayer)

The `FirebaseService` class is a thin stub. Before multiplayer can run you need to:

1. `flutterfire configure` to generate `lib/firebase_options.dart`.
2. Deploy a `submitMove` Cloud Function that ports the Dart `RuleEngine` to TypeScript and re-validates every move server-side.
3. Lock down Firestore rules so clients cannot write to `/games` directly.

## Testing

```bash
flutter test
```

The test suite covers the Barbarian engine's key cases (pass-through capture, knight exclusion, self-sacrifice, two-piece rejection, and application that removes both pieces). The accompanying spec doc describes the full recommended test matrix.

## Shipping checklist (per the spec)

- [ ] Replace AdMob test IDs with production IDs.
- [ ] Implement Google UMP consent flow.
- [ ] Implement iOS App Tracking Transparency prompt.
- [ ] `flutterfire configure` + deploy Cloud Functions.
- [ ] Store listings + data-safety disclosures.
- [ ] Port rule engines to TypeScript for server-side move validation.
- [ ] Add Stockfish for Classic AI; variant minimax in an isolate for the rest.
- [ ] Promotion picker UI (scaffold defaults to queen).
- [ ] Beta via TestFlight + Play Internal Testing.
