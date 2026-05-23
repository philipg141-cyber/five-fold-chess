import '../models/castling_rights.dart';
import '../models/game_state.dart';
import '../models/piece.dart';
import '../models/variant.dart';
import 'classic_engine.dart';
import 'rule_engine.dart';

/// Long Chess: identical FIDE rules, but the board is 8 wide by 16 tall.
///
/// Both armies are placed on the two ends exactly as in classic — back
/// rank on rank 0 / 15 and pawns on rank 1 / 14. Ranks 2 through 13
/// start empty, creating a long neutral middle.
///
/// Pawn first-move double advance, en passant, promotion on rank 15
/// (white) / 0 (black), and castling all work identically to classic.
class LongEngine extends ClassicEngine {
  @override
  int get ranks => 16;

  @override
  GameState initialState() => GameState(
    variant: Variant.long,
    board: RuleEngine.standardStartingBoard(extraMiddle: 8),
    sideToMove: PieceColor.white,
    history: const [],
    rights: const CastlingRights(),
    enPassantTarget: null,
    halfmoveClock: 0,
    fullmoveNumber: 1,
  );
}
