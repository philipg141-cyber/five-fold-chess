import 'piece.dart';

/// Tracks which sides can still castle in which direction.
///
/// Not used in Reverse Chess (antichess has no castling).
class CastlingRights {
  final bool whiteKingside;
  final bool whiteQueenside;
  final bool blackKingside;
  final bool blackQueenside;

  const CastlingRights({
    this.whiteKingside = true,
    this.whiteQueenside = true,
    this.blackKingside = true,
    this.blackQueenside = true,
  });

  static const none = CastlingRights(
    whiteKingside: false, whiteQueenside: false,
    blackKingside: false, blackQueenside: false,
  );

  bool kingside(PieceColor c) => c == PieceColor.white ? whiteKingside : blackKingside;
  bool queenside(PieceColor c) => c == PieceColor.white ? whiteQueenside : blackQueenside;

  CastlingRights copyWith({bool? wk, bool? wq, bool? bk, bool? bq}) => CastlingRights(
    whiteKingside:  wk ?? whiteKingside,
    whiteQueenside: wq ?? whiteQueenside,
    blackKingside:  bk ?? blackKingside,
    blackQueenside: bq ?? blackQueenside,
  );
}
