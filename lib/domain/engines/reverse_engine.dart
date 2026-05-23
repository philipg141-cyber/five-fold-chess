import '../models/board.dart';
import '../models/castling_rights.dart';
import '../models/game_state.dart';
import '../models/move.dart';
import '../models/piece.dart';
import '../models/square.dart';
import '../models/variant.dart';
import 'rule_engine.dart';

/// Reverse Chess (a.k.a. Antichess / Losing Chess).
///
/// Rules:
///  * Standard 8x8 board and starting position.
///  * King is a NORMAL piece — no check, no checkmate, no castling.
///    It can be captured like any other piece.
///  * If the side to move has any capture available, they MUST play a
///    capture. If multiple are available they may choose which.
///  * Pawns promote (reaching the far rank) to any piece including KING.
///  * You WIN if you have no pieces left, OR you have no legal move
///    on your turn (stalemate = win for the stalemated side).
class ReverseEngine extends RuleEngine {
  @override
  int get files => 8;
  @override
  int get ranks => 8;

  @override
  bool get announcesCheck => false;

  @override
  bool get forcedCaptures => true;

  @override
  GameState initialState() => GameState(
    variant: Variant.reverse,
    board: RuleEngine.standardStartingBoard(),
    sideToMove: PieceColor.white,
    history: const [],
    rights: CastlingRights.none, // no castling in antichess
    enPassantTarget: null,
    halfmoveClock: 0,
    fullmoveNumber: 1,
  );

  @override
  List<Move> legalMoves(GameState state) {
    final all = <Move>[];
    final captures = <Move>[];
    state.board.pieces.forEach((sq, piece) {
      if (piece.color != state.sideToMove) return;
      final out = <Move>[];
      switch (piece.type) {
        case PieceType.pawn:   _pawnMoves(state, sq, out); break;
        case PieceType.knight: _leaperMoves(state, sq, _knightJumps, out); break;
        case PieceType.bishop: _rayMoves(state, sq, _bishopDirs, out); break;
        case PieceType.rook:   _rayMoves(state, sq, _rookDirs, out); break;
        case PieceType.queen:  _rayMoves(state, sq, _queenDirs, out); break;
        case PieceType.king:   _leaperMoves(state, sq, _kingSteps, out); break;
      }
      for (final m in out) {
        if (_isCapture(state, m)) {
          captures.add(m);
        } else {
          all.add(m);
        }
      }
    });
    // If any capture is available, captures are forced.
    return captures.isNotEmpty ? captures : all;
  }

  @override
  GameState applyMove(GameState state, Move move) {
    final b = state.board;
    final piece = b.at(move.from)!;
    final removed = <Square>[move.from];
    final placed = <Square, Piece>{};

    if (move.enPassantCapture) {
      final dir = piece.color == PieceColor.white ? -1 : 1;
      removed.add(Square(move.to.file, move.to.rank + dir));
    }

    final newType = move.promotion ?? piece.type;
    placed[move.to] = Piece(newType, piece.color, hasMoved: true);
    final newBoard = b.mutate(removed: removed, placed: placed);

    Square? ep;
    if (piece.type == PieceType.pawn && (move.to.rank - move.from.rank).abs() == 2) {
      ep = Square(move.from.file, (move.from.rank + move.to.rank) ~/ 2);
    }

    return state.copyWith(
      board: newBoard,
      sideToMove: state.sideToMove.opposite,
      history: [...state.history, move],
      enPassantTarget: ep,
      clearEnPassant: ep == null,
      halfmoveClock: 0, // not strictly needed; we keep simple draw rules
      fullmoveNumber: state.sideToMove == PieceColor.black
          ? state.fullmoveNumber + 1
          : state.fullmoveNumber,
    );
  }

  @override
  GameResult? terminal(GameState state) {
    // Win if you just have zero pieces left.
    final whiteCount = state.board.pieces.values.where((p) => p.color == PieceColor.white).length;
    final blackCount = state.board.pieces.values.where((p) => p.color == PieceColor.black).length;
    if (whiteCount == 0) return GameResult.whiteWins;
    if (blackCount == 0) return GameResult.blackWins;
    // Or if the side to move has no legal moves at all — that player wins.
    if (legalMoves(state).isEmpty) {
      return state.sideToMove == PieceColor.white ? GameResult.whiteWins : GameResult.blackWins;
    }
    return null;
  }

  // ---------- helpers (no king/check filtering) ----------

  bool _isCapture(GameState state, Move move) {
    if (move.enPassantCapture) return true;
    return state.board.at(move.to) != null;
  }

  static const _bishopDirs = [[1,1],[1,-1],[-1,1],[-1,-1]];
  static const _rookDirs   = [[1,0],[-1,0],[0,1],[0,-1]];
  static const _queenDirs  = [..._bishopDirs, ..._rookDirs];
  static const _knightJumps = [
    [1,2],[2,1],[-1,2],[-2,1],[1,-2],[2,-1],[-1,-2],[-2,-1],
  ];
  static const _kingSteps = _queenDirs;

  void _pawnMoves(GameState state, Square from, List<Move> out) {
    final b = state.board;
    final p = b.at(from)!;
    final dir = p.color == PieceColor.white ? 1 : -1;
    final promoRank = p.color == PieceColor.white ? b.ranks - 1 : 0;
    final startRank = p.color == PieceColor.white ? 1 : b.ranks - 2;

    final one = from.offset(0, dir);
    if (b.inBounds(one) && b.isEmpty(one)) {
      _addPawn(one, from, promoRank, out, isCapture: false);
      final two = from.offset(0, dir * 2);
      if (from.rank == startRank && b.inBounds(two) && b.isEmpty(two)) {
        out.add(Move(from: from, to: two));
      }
    }
    for (final df in const [-1, 1]) {
      final cap = from.offset(df, dir);
      if (!b.inBounds(cap)) continue;
      final target = b.at(cap);
      if (target != null && target.color != p.color) {
        _addPawn(cap, from, promoRank, out, isCapture: true);
      }
      if (state.enPassantTarget == cap && target == null) {
        out.add(Move(from: from, to: cap, enPassantCapture: true));
      }
    }
  }

  void _addPawn(Square to, Square from, int promoRank, List<Move> out, {required bool isCapture}) {
    if (to.rank == promoRank) {
      // Reverse Chess allows promotion to king as well.
      for (final promo in const [
        PieceType.queen, PieceType.rook, PieceType.bishop,
        PieceType.knight, PieceType.king,
      ]) {
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
}
