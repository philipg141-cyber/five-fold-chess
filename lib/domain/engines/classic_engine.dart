import 'package:meta/meta.dart';

import '../models/board.dart';
import '../models/castling_rights.dart';
import '../models/game_state.dart';
import '../models/move.dart';
import '../models/piece.dart';
import '../models/square.dart';
import '../models/variant.dart';
import 'rule_engine.dart';

/// Reference implementation of standard FIDE chess.
///
/// The other variants (Silent, Long, Barbarian) inherit from this and
/// override only what they need. Reverse Chess does not inherit — its
/// rules diverge enough that it ships as its own engine.
class ClassicEngine extends RuleEngine {
  @override
  int get files => 8;
  @override
  int get ranks => 8;

  @override
  bool get announcesCheck => true;

  @override
  bool get forcedCaptures => false;

  @override
  GameState initialState() => GameState(
    variant: Variant.classic,
    board: RuleEngine.standardStartingBoard(),
    sideToMove: PieceColor.white,
    history: const [],
    rights: const CastlingRights(),
    enPassantTarget: null,
    halfmoveClock: 0,
    fullmoveNumber: 1,
  );

  @override
  List<Move> legalMoves(GameState state) {
    final pseudo = _pseudoLegalMoves(state);
    // Filter out any move that leaves our own king in check.
    return pseudo.where((m) {
      final next = _applyMoveRaw(state, m);
      return !_isSquareAttacked(next.board, next.board.kingSquare(state.sideToMove)!, state.sideToMove.opposite);
    }).toList(growable: false);
  }

  @override
  GameState applyMove(GameState state, Move move) => _applyMoveRaw(state, move);

  @override
  GameResult? terminal(GameState state) {
    if (legalMoves(state).isNotEmpty) {
      if (state.halfmoveClock >= 100) return GameResult.draw; // 50-move rule
      return null;
    }
    final king = state.board.kingSquare(state.sideToMove);
    if (king == null) return null;
    final inCheck = _isSquareAttacked(state.board, king, state.sideToMove.opposite);
    if (inCheck) {
      return state.sideToMove == PieceColor.white ? GameResult.blackWins : GameResult.whiteWins;
    }
    return GameResult.draw; // stalemate
  }

  /// True if [square] on [board] is attacked by any piece of [attacker].
  bool inCheck(GameState state, PieceColor who) {
    final k = state.board.kingSquare(who);
    if (k == null) return false;
    return _isSquareAttacked(state.board, k, who.opposite);
  }

  // ---------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------

  static const _bishopDirs = [[1,1],[1,-1],[-1,1],[-1,-1]];
  static const _rookDirs   = [[1,0],[-1,0],[0,1],[0,-1]];
  static const _queenDirs  = [..._bishopDirs, ..._rookDirs];
  static const _knightJumps = [
    [1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1],
  ];
  static const _kingSteps = _queenDirs;

  /// Generates moves WITHOUT filtering self-check. Override points for
  /// variants that add extra move kinds (e.g. Barbarian).
  List<Move> _pseudoLegalMoves(GameState state) {
    final moves = <Move>[];
    state.board.pieces.forEach((sq, p) {
      if (p.color != state.sideToMove) return;
      switch (p.type) {
        case PieceType.pawn:   _pawnMoves(state, sq, moves); break;
        case PieceType.knight: _leaperMoves(state, sq, _knightJumps, moves); break;
        case PieceType.bishop: _rayMoves(state, sq, _bishopDirs, moves); break;
        case PieceType.rook:   _rayMoves(state, sq, _rookDirs, moves); break;
        case PieceType.queen:  _rayMoves(state, sq, _queenDirs, moves); break;
        case PieceType.king:   _kingMoves(state, sq, moves); break;
      }
    });
    return moves;
  }

  void _pawnMoves(GameState state, Square from, List<Move> out) {
    final b = state.board;
    final p = b.at(from)!;
    final dir = p.color == PieceColor.white ? 1 : -1;
    final promoRank = p.color == PieceColor.white ? b.ranks - 1 : 0;
    final startRank = p.color == PieceColor.white ? 1 : b.ranks - 2;

    // Single forward push
    final one = from.offset(0, dir);
    if (b.inBounds(one) && b.isEmpty(one)) {
      _addPawnPush(one, from, promoRank, out);

      // Double push from starting rank
      final two = from.offset(0, dir * 2);
      if (from.rank == startRank && b.inBounds(two) && b.isEmpty(two)) {
        out.add(Move(from: from, to: two));
      }
    }

    // Captures (diagonals)
    for (final df in const [-1, 1]) {
      final cap = from.offset(df, dir);
      if (!b.inBounds(cap)) continue;
      final target = b.at(cap);
      if (target != null && target.color != p.color) {
        _addPawnCapture(cap, from, promoRank, out);
      }
      // En passant
      if (state.enPassantTarget == cap && target == null) {
        out.add(Move(from: from, to: cap, enPassantCapture: true));
      }
    }
  }

  void _addPawnPush(Square to, Square from, int promoRank, List<Move> out) {
    if (to.rank == promoRank) {
      for (final promo in const [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight]) {
        out.add(Move(from: from, to: to, promotion: promo));
      }
    } else {
      out.add(Move(from: from, to: to));
    }
  }

  void _addPawnCapture(Square to, Square from, int promoRank, List<Move> out) {
    if (to.rank == promoRank) {
      for (final promo in const [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight]) {
        out.add(Move(from: from, to: to, promotion: promo));
      }
    } else {
      out.add(Move(from: from, to: to));
    }
  }

  void _leaperMoves(GameState state, Square from, List<List<int>> offsets, List<Move> out) {
    final b = state.board;
    final p = b.at(from)!;
    for (final o in offsets) {
      final to = from.offset(o[0], o[1]);
      if (!b.inBounds(to)) continue;
      final t = b.at(to);
      if (t == null || t.color != p.color) out.add(Move(from: from, to: to));
    }
  }

  void _rayMoves(GameState state, Square from, List<List<int>> dirs, List<Move> out) {
    final b = state.board;
    final p = b.at(from)!;
    for (final d in dirs) {
      var s = from.offset(d[0], d[1]);
      while (b.inBounds(s)) {
        final t = b.at(s);
        if (t == null) {
          out.add(Move(from: from, to: s));
        } else {
          if (t.color != p.color) out.add(Move(from: from, to: s));
          break;
        }
        s = s.offset(d[0], d[1]);
      }
    }
  }

  void _kingMoves(GameState state, Square from, List<Move> out) {
    _leaperMoves(state, from, _kingSteps, out);
    _castlingMoves(state, from, out);
  }

  void _castlingMoves(GameState state, Square kingSq, List<Move> out) {
    final b = state.board;
    final p = b.at(kingSq)!;
    if (p.hasMoved) return;
    if (_isSquareAttacked(b, kingSq, p.color.opposite)) return;

    // Kingside: king passes f, lands on g
    if (state.rights.kingside(p.color)) {
      final f = kingSq.offset(1, 0);
      final g = kingSq.offset(2, 0);
      if (b.isEmpty(f) && b.isEmpty(g) &&
          !_isSquareAttacked(b, f, p.color.opposite) &&
          !_isSquareAttacked(b, g, p.color.opposite)) {
        out.add(Move(from: kingSq, to: g, isCastleKingside: true));
      }
    }
    // Queenside: king passes d, lands on c; b-file must also be empty
    if (state.rights.queenside(p.color)) {
      final d = kingSq.offset(-1, 0);
      final c = kingSq.offset(-2, 0);
      final bFile = kingSq.offset(-3, 0);
      if (b.isEmpty(d) && b.isEmpty(c) && b.isEmpty(bFile) &&
          !_isSquareAttacked(b, d, p.color.opposite) &&
          !_isSquareAttacked(b, c, p.color.opposite)) {
        out.add(Move(from: kingSq, to: c, isCastleQueenside: true));
      }
    }
  }

  /// True if any piece of [attacker] is attacking [square] on [board].
  ///
  /// Note: does not recurse through checks; purely a static attack check.
  /// Protected visibility so variants (Barbarian) can reuse it.
  @protected
  bool isSquareAttacked(Board board, Square square, PieceColor attacker) =>
      _isSquareAttacked(board, square, attacker);

  bool _isSquareAttacked(Board board, Square square, PieceColor attacker) {
    // Pawn attacks
    final dir = attacker == PieceColor.white ? 1 : -1;
    for (final df in const [-1, 1]) {
      final s = square.offset(df, -dir); // a pawn from attacker's side would attack FROM here
      final p = board.at(s);
      if (p != null && p.color == attacker && p.type == PieceType.pawn) return true;
    }
    // Knight attacks
    for (final j in _knightJumps) {
      final s = square.offset(j[0], j[1]);
      final p = board.at(s);
      if (p != null && p.color == attacker && p.type == PieceType.knight) return true;
    }
    // Sliding attacks
    bool slide(List<List<int>> dirs, Set<PieceType> types) {
      for (final d in dirs) {
        var s = square.offset(d[0], d[1]);
        while (board.inBounds(s)) {
          final p = board.at(s);
          if (p != null) {
            if (p.color == attacker && types.contains(p.type)) return true;
            break;
          }
          s = s.offset(d[0], d[1]);
        }
      }
      return false;
    }
    if (slide(_bishopDirs, {PieceType.bishop, PieceType.queen})) return true;
    if (slide(_rookDirs,   {PieceType.rook,   PieceType.queen})) return true;
    // King proximity
    for (final k in _kingSteps) {
      final s = square.offset(k[0], k[1]);
      final p = board.at(s);
      if (p != null && p.color == attacker && p.type == PieceType.king) return true;
    }
    return false;
  }

  /// Apply without legality filtering. Used both by applyMove (after
  /// legalMoves filter) and by legalMoves internally for check testing.
  GameState _applyMoveRaw(GameState state, Move move) {
    final b = state.board;
    final piece = b.at(move.from)!;
    final captured = b.at(move.to);
    final removed = <Square>[move.from];
    final placed = <Square, Piece>{};

    // En passant capture removes a pawn on an adjacent square
    if (move.enPassantCapture) {
      final dir = piece.color == PieceColor.white ? -1 : 1;
      removed.add(Square(move.to.file, move.to.rank + dir));
    }

    // Barbarian: remove the pass-through piece too
    if (move.isBarbarian) {
      removed.add(move.barbarianPassThrough!);
    }

    final newType = move.promotion ?? piece.type;
    placed[move.to] = Piece(newType, piece.color, hasMoved: true);

    // Castling also moves the rook
    if (move.isCastleKingside) {
      final rookFrom = Square(b.files - 1, move.from.rank);
      final rookTo = Square(move.to.file - 1, move.from.rank);
      removed.add(rookFrom);
      placed[rookTo] = Piece(PieceType.rook, piece.color, hasMoved: true);
    } else if (move.isCastleQueenside) {
      final rookFrom = Square(0, move.from.rank);
      final rookTo = Square(move.to.file + 1, move.from.rank);
      removed.add(rookFrom);
      placed[rookTo] = Piece(PieceType.rook, piece.color, hasMoved: true);
    }

    final newBoard = b.mutate(removed: removed, placed: placed);

    // Update castling rights
    var rights = state.rights;
    if (piece.type == PieceType.king) {
      if (piece.color == PieceColor.white) {
        rights = rights.copyWith(wk: false, wq: false);
      } else {
        rights = rights.copyWith(bk: false, bq: false);
      }
    }
    if (piece.type == PieceType.rook) {
      if (piece.color == PieceColor.white && move.from == const Square(0, 0)) rights = rights.copyWith(wq: false);
      if (piece.color == PieceColor.white && move.from == const Square(7, 0)) rights = rights.copyWith(wk: false);
      if (piece.color == PieceColor.black && move.from == Square(0, b.ranks - 1)) rights = rights.copyWith(bq: false);
      if (piece.color == PieceColor.black && move.from == Square(7, b.ranks - 1)) rights = rights.copyWith(bk: false);
    }

    // Update en passant target (set only on double pawn push)
    Square? ep;
    if (piece.type == PieceType.pawn && (move.to.rank - move.from.rank).abs() == 2) {
      ep = Square(move.from.file, (move.from.rank + move.to.rank) ~/ 2);
    }

    // Halfmove clock
    final resetsClock = piece.type == PieceType.pawn || captured != null || move.isBarbarian || move.enPassantCapture;
    final halfmove = resetsClock ? 0 : state.halfmoveClock + 1;

    return state.copyWith(
      board: newBoard,
      sideToMove: state.sideToMove.opposite,
      history: [...state.history, move],
      rights: rights,
      enPassantTarget: ep,
      clearEnPassant: ep == null,
      halfmoveClock: halfmove,
      fullmoveNumber: state.sideToMove == PieceColor.black
          ? state.fullmoveNumber + 1
          : state.fullmoveNumber,
    );
  }
}
