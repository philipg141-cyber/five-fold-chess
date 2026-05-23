/// Basic chess piece types and colors.

enum PieceColor { white, black }

extension PieceColorX on PieceColor {
  PieceColor get opposite => this == PieceColor.white ? PieceColor.black : PieceColor.white;
}

enum PieceType { pawn, knight, bishop, rook, queen, king }

extension PieceTypeX on PieceType {
  /// Whether this piece slides along rays (bishop / rook / queen).
  ///
  /// Barbarian Chess restricts its pass-through capture to sliding pieces.
  bool get isSliding =>
      this == PieceType.bishop || this == PieceType.rook || this == PieceType.queen;

  /// Single-character FEN notation.
  String toFenChar(PieceColor c) {
    const m = {
      PieceType.pawn:   'p', PieceType.knight: 'n', PieceType.bishop: 'b',
      PieceType.rook:   'r', PieceType.queen:  'q', PieceType.king:   'k',
    };
    final ch = m[this]!;
    return c == PieceColor.white ? ch.toUpperCase() : ch;
  }
}

/// Immutable value object for a piece on the board.
class Piece {
  final PieceType type;
  final PieceColor color;
  final bool hasMoved;

  const Piece(this.type, this.color, {this.hasMoved = false});

  Piece copyWith({PieceType? type, PieceColor? color, bool? hasMoved}) =>
      Piece(type ?? this.type, color ?? this.color, hasMoved: hasMoved ?? this.hasMoved);

  @override
  bool operator ==(Object other) =>
      other is Piece && other.type == type && other.color == color && other.hasMoved == hasMoved;

  @override
  int get hashCode => Object.hash(type, color, hasMoved);

  @override
  String toString() => type.toFenChar(color);
}
