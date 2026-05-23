import '../models/board.dart';
import '../models/game_state.dart';
import '../models/move.dart';
import '../models/piece.dart';
import '../models/square.dart';
import '../models/variant.dart';
import 'classic_engine.dart';

/// Barbarian Chess.
///
/// Standard 8x8 board, standard starting position, standard classic
/// rules — PLUS the "barbarian move":
///
///   A sliding piece (bishop, rook, or queen) travels along its usual
///   ray. It may pass through EXACTLY ONE intervening piece of either
///   color, removing that piece, and continue to a target square that
///   MUST be occupied by an ENEMY piece. The attacker lands on the
///   target, capturing it.
///
///   Net effect: 2 pieces removed from the board (the pass-through +
///   the target), attacker survives on the target square.
///
///   Pawns, knights, and kings CANNOT perform barbarian moves.
///
///   A barbarian move that would leave your own king in check is
///   illegal, exactly like any other move. Crucially, "in check" here
///   means classical check OR barbarian check — an enemy slider with a
///   barbarian-style line on your king is also a check, and you must
///   address it.
class BarbarianEngine extends ClassicEngine {
  @override
  GameState initialState() {
    final s = super.initialState();
    return GameState(
      variant: Variant.barbarian,
      board: s.board,
      sideToMove: s.sideToMove,
      history: s.history,
      rights: s.rights,
      enPassantTarget: s.enPassantTarget,
      halfmoveClock: s.halfmoveClock,
      fullmoveNumber: s.fullmoveNumber,
    );
  }

  /// Re-filter the classic-engine output (which only knows classic check)
  /// using the combined attack detector, then add barbarian moves and
  /// filter those the same way. This guarantees:
  ///   * No move can leave the moving side's king in classic OR barbarian
  ///     check.
  ///   * The opponent's king is never capturable as a side effect (the
  ///     opponent's previous move would have been illegal under the same
  ///     rule).
  @override
  List<Move> legalMoves(GameState state) {
    final candidates = <Move>[
      ...super.legalMoves(state),
      ..._pseudoBarbarianMoves(state),
    ];
    return candidates.where((m) => _isMoveSafe(state, m)).toList(growable: false);
  }

  bool _isMoveSafe(GameState before, Move m) {
    final next = applyMove(before, m);
    final mover = before.sideToMove;
    final myKing = next.board.kingSquare(mover);
    if (myKing == null) return false;
    // Defence in depth: a "legal" move never captures the opponent's king.
    // If it did, the opponent's previous move was illegal — but better to
    // refuse it here than to ever surface a king-capture move to the UI.
    final oppKing = next.board.kingSquare(mover.opposite);
    if (oppKing == null) return false;
    return !_isAttackedAnyMode(next.board, myKing, mover.opposite);
  }

  @override
  GameResult? terminal(GameState state) {
    if (legalMoves(state).isNotEmpty) {
      if (state.halfmoveClock >= 100) return GameResult.draw;
      return null;
    }
    final king = state.board.kingSquare(state.sideToMove);
    if (king == null) return null;
    final isCheck = _isAttackedAnyMode(state.board, king, state.sideToMove.opposite);
    if (isCheck) {
      return state.sideToMove == PieceColor.white
          ? GameResult.blackWins
          : GameResult.whiteWins;
    }
    return GameResult.draw; // stalemate
  }

  @override
  bool inCheck(GameState state, PieceColor who) {
    final k = state.board.kingSquare(who);
    if (k == null) return false;
    return _isAttackedAnyMode(state.board, k, who.opposite);
  }

  // ---------- attack detection (classical + barbarian) ------------------

  /// True if [square] on [board] is attacked by [attacker] under either
  /// classical rules OR a barbarian pass-through line.
  bool _isAttackedAnyMode(Board board, Square square, PieceColor attacker) {
    if (isSquareAttacked(board, square, attacker)) return true;
    return _hasBarbarianAttackOn(board, square, attacker);
  }

  /// Walk every enemy slider along every ray; the first piece on the ray
  /// (any colour) is the pass-through candidate; we then continue past it
  /// skipping empty squares; if the next occupied square is [target] (and
  /// the target is what we're checking attack on), this is a barbarian
  /// attack on target.
  ///
  /// Note we DON'T require the target to be an enemy here — we're asking
  /// "could a barbarian move land on this square?", separate from the
  /// move-generation rule that the landing must be an enemy piece. For
  /// check detection, the king itself is the prospective enemy, so the
  /// "must be enemy" rule is automatically satisfied.
  bool _hasBarbarianAttackOn(Board board, Square target, PieceColor attacker) {
    for (final entry in board.pieces.entries) {
      final from = entry.key;
      final p = entry.value;
      if (p.color != attacker) continue;
      if (!p.type.isSliding) continue;
      for (final d in _dirsForPiece(p.type)) {
        if (_barbarianRayLandsOn(board, from, d[0], d[1], target)) return true;
      }
    }
    return false;
  }

  /// Walk a ray from [from] in direction (df, dr); return true iff the
  /// barbarian landing square equals [target].
  bool _barbarianRayLandsOn(Board b, Square from, int df, int dr, Square target) {
    var s = from.offset(df, dr);
    // First piece on the ray (the pass-through).
    while (b.inBounds(s) && b.at(s) == null) {
      s = s.offset(df, dr);
    }
    if (!b.inBounds(s)) return false;
    // Continue past the pass-through, skipping empties.
    s = s.offset(df, dr);
    while (b.inBounds(s) && b.at(s) == null) {
      s = s.offset(df, dr);
    }
    if (!b.inBounds(s)) return false;
    return s == target;
  }

  // ---------- barbarian move generation (used by legalMoves) ------------

  List<Move> _pseudoBarbarianMoves(GameState state) {
    final out = <Move>[];
    state.board.pieces.forEach((sq, piece) {
      if (piece.color != state.sideToMove) return;
      if (!piece.type.isSliding) return;
      for (final d in _dirsForPiece(piece.type)) {
        _emitBarbarianMove(state, sq, d[0], d[1], out);
      }
    });
    return out;
  }

  void _emitBarbarianMove(GameState state, Square from, int df, int dr, List<Move> out) {
    final b = state.board;
    var s = from.offset(df, dr);
    while (b.inBounds(s) && b.at(s) == null) {
      s = s.offset(df, dr);
    }
    if (!b.inBounds(s)) return;
    final passThrough = s;
    s = s.offset(df, dr);
    while (b.inBounds(s) && b.at(s) == null) {
      s = s.offset(df, dr);
    }
    if (!b.inBounds(s)) return;
    final targetPiece = b.at(s)!;
    if (targetPiece.color == state.sideToMove) return;
    out.add(Move(from: from, to: s, barbarianPassThrough: passThrough));
  }

  static const _bishopDirs = [[1,1],[1,-1],[-1,1],[-1,-1]];
  static const _rookDirs   = [[1,0],[-1,0],[0,1],[0,-1]];

  List<List<int>> _dirsForPiece(PieceType t) {
    switch (t) {
      case PieceType.bishop: return _bishopDirs;
      case PieceType.rook:   return _rookDirs;
      case PieceType.queen:  return const [..._bishopDirs, ..._rookDirs];
      default: return const [];
    }
  }
}
