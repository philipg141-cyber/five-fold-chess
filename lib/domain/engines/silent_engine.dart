import '../models/game_state.dart';
import '../models/variant.dart';
import 'classic_engine.dart';

/// Silent Chess: identical rules to classic, but the UI never announces
/// check. The engine still enforces legality (you cannot leave your own
/// king in check) — only the *notification* is suppressed.
///
/// That behavior is achieved by overriding [announcesCheck] to false.
/// Game-end mate is still surfaced normally.
class SilentEngine extends ClassicEngine {
  @override
  bool get announcesCheck => false;

  @override
  GameState initialState() {
    final s = super.initialState();
    return GameState(
      variant: Variant.silent,
      board: s.board,
      sideToMove: s.sideToMove,
      history: s.history,
      rights: s.rights,
      enPassantTarget: s.enPassantTarget,
      halfmoveClock: s.halfmoveClock,
      fullmoveNumber: s.fullmoveNumber,
    );
  }
}
