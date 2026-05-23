import '../models/board.dart';
import '../models/game_state.dart';
import '../models/move.dart';
import '../models/piece.dart';
import '../models/square.dart';

/// Abstract contract every variant implements.
///
/// The UI, the AI, and the Firebase move validator all speak to this
/// interface so that variants are fully interchangeable at the call site.
abstract class RuleEngine {
  /// Create the starting game state for this variant.
  GameState initialState();

  /// All legal moves for the side to move in [state].
  List<Move> legalMoves(GameState state);

  /// Apply [move] and return the resulting state. Move must be legal.
  GameState applyMove(GameState state, Move move);

  /// If the game is over, return the result; otherwise null.
  GameResult? terminal(GameState state);

  /// Whether the UI should surface check indicators. False for Silent & Reverse.
  bool get announcesCheck;

  /// Whether captures are compulsory (Reverse Chess).
  bool get forcedCaptures;

  int get files;
  int get ranks;

  // ---------- shared helpers ----------

  /// Build a standard 8-wide starting position, parametrized by the number
  /// of empty ranks inserted in the middle (0 for Classic, 8 for Long).
  ///
  /// This is used by Classic, Silent, Reverse, Barbarian (extraMiddle=0)
  /// and Long (extraMiddle=8).
  static Board standardStartingBoard({int extraMiddle = 0}) {
    final totalRanks = 8 + extraMiddle;
    final pieces = <Square, Piece>{};
    const back = [
      PieceType.rook, PieceType.knight, PieceType.bishop, PieceType.queen,
      PieceType.king, PieceType.bishop, PieceType.knight, PieceType.rook,
    ];
    for (var f = 0; f < 8; f++) {
      pieces[Square(f, 0)] = Piece(back[f], PieceColor.white);
      pieces[Square(f, 1)] = const Piece(PieceType.pawn, PieceColor.white);
      pieces[Square(f, totalRanks - 2)] = const Piece(PieceType.pawn, PieceColor.black);
      pieces[Square(f, totalRanks - 1)] = Piece(back[f], PieceColor.black);
    }
    return Board(files: 8, ranks: totalRanks, pieces: Map.unmodifiable(pieces));
  }
}
