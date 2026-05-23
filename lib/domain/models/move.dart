import 'piece.dart';
import 'square.dart';

/// A single move in any variant.
///
/// Normal moves use only [from] and [to]. Specialized move kinds set
/// additional fields:
///   * [promotion] — pawn promotion target piece type.
///   * [isCastleKingside] / [isCastleQueenside] — castling flags.
///   * [enPassantCapture] — set when this move captures en passant.
///   * [barbarianPassThrough] — Barbarian Chess: the square of the
///     piece that the attacker passes through (and which is removed).
class Move {
  final Square from;
  final Square to;
  final PieceType? promotion;
  final bool isCastleKingside;
  final bool isCastleQueenside;
  final bool enPassantCapture;

  /// If non-null, this is a Barbarian Chess move and [barbarianPassThrough]
  /// is the square occupied by the piece (own or opponent's) that the
  /// attacker passes through en route to [to]. That piece is removed.
  final Square? barbarianPassThrough;

  const Move({
    required this.from,
    required this.to,
    this.promotion,
    this.isCastleKingside = false,
    this.isCastleQueenside = false,
    this.enPassantCapture = false,
    this.barbarianPassThrough,
  });

  bool get isBarbarian => barbarianPassThrough != null;

  // ---------- JSON (for Firestore sync) ----------

  Map<String, dynamic> toJson() => {
    'from': [from.file, from.rank],
    'to':   [to.file, to.rank],
    if (promotion != null) 'promotion': promotion!.index,
    if (isCastleKingside)  'castleK': true,
    if (isCastleQueenside) 'castleQ': true,
    if (enPassantCapture)  'ep': true,
    if (barbarianPassThrough != null)
      'pass': [barbarianPassThrough!.file, barbarianPassThrough!.rank],
  };

  factory Move.fromJson(Map<String, dynamic> j) {
    final from = (j['from'] as List).cast<num>();
    final to   = (j['to']   as List).cast<num>();
    Square? pass;
    if (j['pass'] != null) {
      final p = (j['pass'] as List).cast<num>();
      pass = Square(p[0].toInt(), p[1].toInt());
    }
    return Move(
      from: Square(from[0].toInt(), from[1].toInt()),
      to:   Square(to[0].toInt(),   to[1].toInt()),
      promotion: j['promotion'] != null
          ? PieceType.values[(j['promotion'] as num).toInt()]
          : null,
      isCastleKingside:  j['castleK'] == true,
      isCastleQueenside: j['castleQ'] == true,
      enPassantCapture:  j['ep'] == true,
      barbarianPassThrough: pass,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Move &&
      other.from == from &&
      other.to == to &&
      other.promotion == promotion &&
      other.isCastleKingside == isCastleKingside &&
      other.isCastleQueenside == isCastleQueenside &&
      other.enPassantCapture == enPassantCapture &&
      other.barbarianPassThrough == barbarianPassThrough;

  @override
  int get hashCode => Object.hash(
    from, to, promotion, isCastleKingside, isCastleQueenside,
    enPassantCapture, barbarianPassThrough,
  );

  @override
  String toString() {
    final suffix = promotion != null ? '=${promotion!.toFenChar(PieceColor.white)}' : '';
    final bar = isBarbarian ? ' (via $barbarianPassThrough)' : '';
    return '$from-$to$suffix$bar';
  }
}
