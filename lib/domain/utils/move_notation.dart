import '../engines/rule_engine.dart';
import '../models/game_state.dart';
import '../models/move.dart';
import '../models/piece.dart';
import '../models/square.dart';

/// Compact, unambiguous notation for one move. Format:
///
///   - Castling: "O-O" (kingside) / "O-O-O" (queenside)
///   - Pawn move: "e2-e4" or "e4-e3" (no piece prefix for pawns)
///   - Pawn capture: "e2xd3" (still no piece prefix)
///   - Piece move: "Nb1-c3"
///   - Piece capture: "Nb1xc3"
///   - En passant: same as a regular pawn capture, plus " e.p."
///   - Promotion: appended as "=Q" / "=R" / "=B" / "=N" / "=K"
///   - Barbarian pass-through: appended as "(thru d3)" naming the pass-
///     through square; the main "from x to" always names the attacker
///     and target.
///
/// Coordinate notation (vs short algebraic) is used because it's
/// unambiguous on Long Chess (16 ranks) and easy for a casual player
/// to read.
String describeMove(Move m, GameState before) {
  if (m.isCastleKingside) return 'O-O';
  if (m.isCastleQueenside) return 'O-O-O';

  final piece = before.board.at(m.from);
  final isCapture = before.board.at(m.to) != null
      || m.enPassantCapture
      || m.barbarianPassThrough != null;

  final piecePrefix = piece == null
      ? ''
      : (piece.type == PieceType.pawn ? '' : _pieceLetter(piece.type));

  final separator = isCapture ? 'x' : '-';
  final main = '$piecePrefix${_alg(m.from)}$separator${_alg(m.to)}';

  final extras = <String>[];
  if (m.promotion != null) extras.add('=${_pieceLetter(m.promotion!)}');
  if (m.enPassantCapture) extras.add('e.p.');
  if (m.barbarianPassThrough != null) {
    extras.add('(thru ${_alg(m.barbarianPassThrough!)})');
  }

  return extras.isEmpty ? main : '$main ${extras.join(' ')}';
}

String _alg(Square s) {
  final fileChar = String.fromCharCode('a'.codeUnitAt(0) + s.file);
  return '$fileChar${s.rank + 1}';
}

String _pieceLetter(PieceType t) {
  switch (t) {
    case PieceType.king:   return 'K';
    case PieceType.queen:  return 'Q';
    case PieceType.rook:   return 'R';
    case PieceType.bishop: return 'B';
    case PieceType.knight: return 'N';
    case PieceType.pawn:   return '';
  }
}

/// Produces the full list of move notations for a game. Replays history
/// to feed each move its "before" state so the piece prefix is correct.
List<String> describeGame(RuleEngine engine, GameState state) {
  final out = <String>[];
  GameState s = engine.initialState();
  for (final m in state.history) {
    out.add(describeMove(m, s));
    s = engine.applyMove(s, m);
  }
  return out;
}
