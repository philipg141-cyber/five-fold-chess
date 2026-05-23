import '../engines/rule_engine.dart';
import '../models/game_state.dart';
import '../models/piece.dart';

/// Snapshot of which pieces each side has captured during the current game.
///
/// Order within each list is move-order. Use [byTypeSorted] for a value-
/// descending grouping suitable for display.
class CaptureLog {
  /// Pieces white has taken from black, in the order white took them.
  final List<PieceType> takenByWhite;

  /// Pieces black has taken from white, in the order black took them.
  final List<PieceType> takenByBlack;

  const CaptureLog({
    required this.takenByWhite,
    required this.takenByBlack,
  });

  static const empty =
      CaptureLog(takenByWhite: [], takenByBlack: []);

  /// Material score from white's perspective. Standard piece values:
  /// pawn 1, knight 3, bishop 3, rook 5, queen 9. Used by the captured-
  /// pieces strip to show "+3" advantage badges.
  int get materialDiffForWhite {
    int score = 0;
    for (final t in takenByWhite) score += _value(t);
    for (final t in takenByBlack) score -= _value(t);
    return score;
  }

  static int _value(PieceType t) {
    switch (t) {
      case PieceType.pawn:   return 1;
      case PieceType.knight: return 3;
      case PieceType.bishop: return 3;
      case PieceType.rook:   return 5;
      case PieceType.queen:  return 9;
      case PieceType.king:   return 0; // shouldn't be captured
    }
  }

  /// Returns piece types grouped and ordered Q, R, B, N, P (descending
  /// value, the standard chess display convention) with their counts.
  static List<MapEntry<PieceType, int>> byTypeSorted(List<PieceType> raw) {
    final counts = <PieceType, int>{};
    for (final t in raw) counts[t] = (counts[t] ?? 0) + 1;
    const order = [
      PieceType.queen,
      PieceType.rook,
      PieceType.bishop,
      PieceType.knight,
      PieceType.pawn,
    ];
    return [
      for (final t in order)
        if ((counts[t] ?? 0) > 0) MapEntry(t, counts[t]!),
    ];
  }
}

/// Replays the move history through the engine to determine which pieces
/// each side has captured.
///
/// The engine is the source of truth — we ask it for each intermediate
/// state and read the piece that was on the relevant square BEFORE the
/// move. This works correctly for regular captures, en-passant, Barbarian
/// pass-through (a single move can capture TWO pieces), and is unaffected
/// by promotions (which don't involve captures by themselves).
CaptureLog deriveCaptures(RuleEngine engine, GameState state) {
  final byWhite = <PieceType>[];
  final byBlack = <PieceType>[];

  GameState s = engine.initialState();
  for (final m in state.history) {
    final mover = s.sideToMove;
    final captured = <PieceType>[];

    // Regular capture: any piece on the destination square.
    final atTo = s.board.at(m.to);
    if (atTo != null) captured.add(atTo.type);

    // En passant: the captured pawn is on (to.file, from.rank).
    if (m.enPassantCapture) {
      captured.add(PieceType.pawn);
    }

    // Barbarian pass-through: the pass-through piece is removed too.
    final pt = m.barbarianPassThrough;
    if (pt != null) {
      final p = s.board.at(pt);
      if (p != null && p.color != mover) {
        // Only count as a capture for the mover when the pass-through
        // piece belonged to the opponent. (A slider may sacrifice its
        // OWN piece as the pass-through too — that's a self-loss, not
        // a capture by the mover.)
        captured.add(p.type);
      }
    }

    if (mover == PieceColor.white) {
      byWhite.addAll(captured);
    } else {
      byBlack.addAll(captured);
    }
    s = engine.applyMove(s, m);
  }

  return CaptureLog(takenByWhite: byWhite, takenByBlack: byBlack);
}
