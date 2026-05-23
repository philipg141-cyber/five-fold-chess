/// Zero-indexed board coordinate.
///
/// `file` is the column (0 = a-file, rightward toward h).
/// `rank` is the row (0 = white's first rank, increasing toward black).
///
/// Long Chess uses ranks 0-15; all other variants use 0-7.
class Square {
  final int file;
  final int rank;

  const Square(this.file, this.rank);

  bool inBounds(int files, int ranks) =>
      file >= 0 && file < files && rank >= 0 && rank < ranks;

  Square offset(int df, int dr) => Square(file + df, rank + dr);

  @override
  bool operator ==(Object other) =>
      other is Square && other.file == file && other.rank == rank;

  @override
  int get hashCode => file * 32 + rank;

  @override
  String toString() {
    final f = String.fromCharCode('a'.codeUnitAt(0) + file);
    return '$f${rank + 1}';
  }
}
