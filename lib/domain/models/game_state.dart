import 'board.dart';
import 'castling_rights.dart';
import 'move.dart';
import 'piece.dart';
import 'square.dart';
import 'variant.dart';

/// Terminal outcome of a game (if any).
enum GameResult { whiteWins, blackWins, draw }

/// Full state of a game at one point in time. Immutable.
class GameState {
  final Variant variant;
  final Board board;
  final PieceColor sideToMove;
  final List<Move> history;
  final CastlingRights rights;
  final Square? enPassantTarget;
  final int halfmoveClock; // plies since last pawn move or capture
  final int fullmoveNumber;

  const GameState({
    required this.variant,
    required this.board,
    required this.sideToMove,
    required this.history,
    required this.rights,
    required this.enPassantTarget,
    required this.halfmoveClock,
    required this.fullmoveNumber,
  });

  GameState copyWith({
    Board? board,
    PieceColor? sideToMove,
    List<Move>? history,
    CastlingRights? rights,
    Square? enPassantTarget,
    bool clearEnPassant = false,
    int? halfmoveClock,
    int? fullmoveNumber,
  }) => GameState(
    variant: variant,
    board: board ?? this.board,
    sideToMove: sideToMove ?? this.sideToMove,
    history: history ?? this.history,
    rights: rights ?? this.rights,
    enPassantTarget: clearEnPassant ? null : (enPassantTarget ?? this.enPassantTarget),
    halfmoveClock: halfmoveClock ?? this.halfmoveClock,
    fullmoveNumber: fullmoveNumber ?? this.fullmoveNumber,
  );
}
