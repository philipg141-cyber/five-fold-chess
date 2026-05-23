import 'package:flutter/material.dart';

import '../../domain/models/piece.dart';
import '../../domain/utils/capture_tracker.dart';

/// Horizontal strip showing one side's captured/lost pieces, sorted
/// Q→R→B→N→P (descending value, the standard chess scoresheet order).
///
/// When enough pieces are captured to overflow a single line, the strip
/// wraps to a second row automatically (uses [Wrap], not [Row]).
///
/// The [capturingSide] parameter names the side WHOSE captures are
/// being displayed. Pieces captured BY white (black pieces taken) get
/// [PieceColor.black] glyphs; pieces captured BY black (white pieces
/// taken) get outline-style white glyphs.
class CapturedPiecesStrip extends StatelessWidget {
  final PieceColor capturingSide;
  final CaptureLog log;

  const CapturedPiecesStrip({
    super.key,
    required this.capturingSide,
    required this.log,
  });

  @override
  Widget build(BuildContext context) {
    final taken = capturingSide == PieceColor.white
        ? log.takenByWhite
        : log.takenByBlack;
    final groups = CaptureLog.byTypeSorted(taken);

    // Material badge — only show when this side is ahead.
    final diff = log.materialDiffForWhite *
        (capturingSide == PieceColor.white ? 1 : -1);

    final pieceColour = capturingSide == PieceColor.white
        ? PieceColor.black
        : PieceColor.white;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 28),
      child: Wrap(
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 2,
        spacing: 0,
        children: [
          for (final entry in groups)
            _GroupGlyph(
              type: entry.key,
              count: entry.value,
              colour: pieceColour,
            ),
          if (diff > 0) ...[
            const SizedBox(width: 8),
            _MaterialBadge(diff: diff),
          ],
        ],
      ),
    );
  }
}

class _GroupGlyph extends StatelessWidget {
  final PieceType type;
  final int count;
  final PieceColor colour;
  const _GroupGlyph({
    required this.type,
    required this.count,
    required this.colour,
  });

  // Solid (filled) glyphs — render naturally as filled silhouettes.
  static const _solid = <PieceType, String>{
    PieceType.king:   '♚',
    PieceType.queen:  '♛',
    PieceType.rook:   '♜',
    PieceType.bishop: '♝',
    PieceType.knight: '♞',
    PieceType.pawn:   '♟',
  };

  // Outline glyphs — render naturally as outlined shapes. We use these
  // for white pieces so they read as "white" without relying on the
  // unreliable `color: Colors.white` recolouring trick (which Android's
  // emoji fallback ignores on some devices).
  static const _outline = <PieceType, String>{
    PieceType.king:   '♔',
    PieceType.queen:  '♕',
    PieceType.rook:   '♖',
    PieceType.bishop: '♗',
    PieceType.knight: '♘',
    PieceType.pawn:   '♙',
  };

  @override
  Widget build(BuildContext context) {
    final isWhite = colour == PieceColor.white;
    final glyph = (isWhite ? _outline[type]! : _solid[type]!);
    final glyphs = glyph * count;

    // Both colours render in their own native ink, with a contrasting
    // drop shadow so they stay visible on any background.
    final fill = isWhite ? Colors.white : Colors.black;
    final shadow = isWhite ? Colors.black87 : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(right: 1),
      child: Text(
        glyphs,
        style: TextStyle(
          fontSize: 22,
          height: 1.0,
          color: fill,
          shadows: [
            Shadow(color: shadow, blurRadius: 1.5),
            Shadow(color: shadow, blurRadius: 0.5),
          ],
        ),
      ),
    );
  }
}

class _MaterialBadge extends StatelessWidget {
  final int diff;
  const _MaterialBadge({required this.diff});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xCCFFFFFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '+$diff',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
