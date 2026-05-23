import 'piece.dart';
import 'square.dart';

/// Immutable rectangular board. Dimensions vary per variant:
/// 8×8 for Classic / Silent / Reverse / Barbarian, 8×16 for Long Chess.
class Board {
  final int files;
  final int ranks;
  final Map<Square, Piece> pieces;

  const Board({required this.files, required this.ranks, required this.pieces});

  Piece? at(Square s) => pieces[s];
  bool isEmpty(Square s) => !pieces.containsKey(s);
  bool inBounds(Square s) => s.inBounds(files, ranks);

  Board withPieces(Map<Square, Piece> next) =>
      Board(files: files, ranks: ranks, pieces: Map.unmodifiable(next));

  /// Creates a copy with the given mutations applied. `removed` squares
  /// are cleared first, then `placed` entries set.
  Board mutate({Iterable<Square> removed = const [], Map<Square, Piece> placed = const {}}) {
    final next = Map<Square, Piece>.from(pieces);
    for (final s in removed) {
      next.remove(s);
    }
    next.addAll(placed);
    return withPieces(next);
  }

  /// Finds the (unique) king of a given color, or null if none.
  Square? kingSquare(PieceColor color) {
    for (final entry in pieces.entries) {
      if (entry.value.type == PieceType.king && entry.value.color == color) {
        return entry.key;
      }
    }
    return null;
  }
}
