// lib/presentation/widgets/board_widget.dart
//
// Renders a chess board with sliding-piece animations.
//
// Each piece on the board carries a stable internal ID across builds, so
// when the board state changes (a move was applied) the piece widget at
// the old square is reconciled to the new square via its ValueKey, and
// AnimatedPositioned interpolates the position over ~250ms. Captures,
// castling, en-passant and Barbarian pass-throughs all hand off IDs
// correctly so animations stay smooth in every variant.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/models/board.dart';
import '../../domain/models/move.dart';
import '../../domain/models/piece.dart';
import '../../domain/models/square.dart';

class BoardWidget extends StatefulWidget {
  final Board board;
  /// Most-recent move applied to the board; used to reconcile piece IDs
  /// so animations target the correct widget. Pass null on a brand-new
  /// game (the widget will assign fresh IDs to all starting pieces).
  final Move? lastMove;
  final Square? selected;
  final List<Move> legalMovesFromSelection;
  final void Function(Square)? onTap;

  const BoardWidget({
    super.key,
    required this.board,
    this.lastMove,
    this.selected,
    this.legalMovesFromSelection = const [],
    this.onTap,
  });

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends State<BoardWidget> {
  /// Maps each square that holds a piece to a stable ID. The ID survives
  /// across moves — when a piece slides from A to B, the entry at A is
  /// removed and the same ID is placed at B, so the piece widget at B
  /// has the same ValueKey as the one at A had last frame.
  final Map<Square, String> _ids = {};
  int _nextId = 0;
  Move? _lastSeenMove;
  Board? _lastSeenBoard;

  static const _animDuration = Duration(milliseconds: 250);
  static const _animCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    _assignFreshIds(widget.board);
    _lastSeenBoard = widget.board;
    _lastSeenMove = widget.lastMove;
  }

  @override
  void didUpdateWidget(covariant BoardWidget old) {
    super.didUpdateWidget(old);
    final move = widget.lastMove;
    if (move != null && move != _lastSeenMove) {
      _applyMoveToIds(move);
      _lastSeenMove = move;
    } else if (widget.board.pieces.length != _ids.length ||
               !_idsCoverBoard(widget.board)) {
      // Board changed without a fresh move (rematch, online replay, etc.).
      // Reassign IDs from scratch to keep them in sync.
      _assignFreshIds(widget.board);
    }
    _lastSeenBoard = widget.board;
  }

  bool _idsCoverBoard(Board b) {
    for (final sq in b.pieces.keys) {
      if (!_ids.containsKey(sq)) return false;
    }
    return true;
  }

  void _assignFreshIds(Board board) {
    _ids.clear();
    for (final sq in board.pieces.keys) {
      _ids[sq] = 'p${_nextId++}';
    }
  }

  /// Update the ID map to reflect a single applied move. Handles all the
  /// special move types so animations stay coherent.
  void _applyMoveToIds(Move m) {
    final movedId = _ids.remove(m.from);

    // En passant: the captured pawn lived at (to.file, from.rank).
    if (m.enPassantCapture) {
      _ids.remove(Square(m.to.file, m.from.rank));
    }
    // Barbarian pass-through: the pass-through piece is removed too.
    if (m.barbarianPassThrough != null) {
      _ids.remove(m.barbarianPassThrough);
    }
    // Regular capture: any ID at the destination is overwritten below.
    _ids[m.to] = movedId ?? 'p${_nextId++}';

    // Castling: the rook moves alongside the king. Hand off its ID too.
    if (m.isCastleKingside || m.isCastleQueenside) {
      final rank = m.from.rank;
      final files = widget.board.files;
      final Square rookFrom;
      final Square rookTo;
      if (m.isCastleKingside) {
        rookFrom = Square(files - 1, rank);
        rookTo = Square(m.to.file - 1, rank);
      } else {
        rookFrom = Square(0, rank);
        rookTo = Square(m.to.file + 1, rank);
      }
      final rookId = _ids.remove(rookFrom);
      if (rookId != null) _ids[rookTo] = rookId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = widget.board.files;
    final ranks = widget.board.ranks;

    return LayoutBuilder(
      builder: (ctx, constraints) {
        // Pick a square size that fits both dimensions, so non-square boards
        // (e.g. Long Chess at 8x16) don't overflow the screen vertically.
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight;
        final double squareSize = maxH.isFinite
            ? ((maxW / files) < (maxH / ranks)
                ? (maxW / files)
                : (maxH / ranks))
            : (maxW / files);

        return SizedBox(
          width: squareSize * files,
          height: squareSize * ranks,
          child: Stack(
            children: [
              // Layer 1: square backgrounds + tap detectors + move-target
              // overlays + pass-through X markers.
              for (int r = 0; r < ranks; r++)
                for (int f = 0; f < files; f++)
                  _buildSquare(context, f, r, squareSize, ranks),

              // Layer 2: pieces, each as an AnimatedPositioned keyed by
              // its stable ID so movement interpolates smoothly.
              ..._buildPieces(squareSize, ranks),
            ],
          ),
        );
      },
    );
  }

  // -------- Square layer (background + overlays + tap target) ----------

  static const _lightSquare = Color(0xFFEFE0C2);
  static const _darkSquare  = Color(0xFF8B6F47);

  Widget _buildSquare(
      BuildContext ctx, int file, int rank, double size, int ranks) {
    final sq = Square(file, rank);
    final isLight = (file + rank).isEven;
    final isSelected = widget.selected == sq;

    bool isTarget = false;
    bool isPassThrough = false;
    for (final m in widget.legalMovesFromSelection) {
      if (m.to == sq) {
        isTarget = true;
      }
      if (m.barbarianPassThrough == sq) {
        isPassThrough = true;
      }
    }

    final base = isLight ? _lightSquare : _darkSquare;
    final squareColor = isSelected
        ? Color.alphaBlend(const Color(0x66FFD54F), base)
        : base;

    final piece = widget.board.at(sq);
    final displayRank = ranks - 1 - rank;

    // Coordinate labels: file letter (a-h) on the bottom row's
    // bottom-right corner; rank number (1..ranks) on the leftmost
    // column's top-left corner. Labels use the OPPOSING square colour
    // so they stay legible on both light and dark squares.
    final labelColor = isLight ? _darkSquare : _lightSquare;
    final labelStyle = GoogleFonts.cinzel(
      fontSize: size * 0.18,
      fontWeight: FontWeight.w700,
      color: labelColor,
      height: 1.0,
    );
    final showFileLabel = rank == 0;          // bottom row in display
    final showRankLabel = file == 0;          // leftmost column

    return Positioned(
      left: file * size,
      top: displayRank * size,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => widget.onTap?.call(sq),
        child: Container(
          color: squareColor,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Subtle wood-grain texture, painted once per square per
              // size — Flutter caches painters that don't repaint.
              CustomPaint(
                painter: _WoodGrainPainter(
                  seed: file * 31 + rank,
                  isLight: isLight,
                ),
                isComplex: true,
                willChange: false,
              ),
              if (showRankLabel)
                Positioned(
                  top: size * 0.05,
                  left: size * 0.07,
                  child: Text('${rank + 1}', style: labelStyle),
                ),
              if (showFileLabel)
                Positioned(
                  bottom: size * 0.05,
                  right: size * 0.07,
                  child: Text(
                    String.fromCharCode('a'.codeUnitAt(0) + file),
                    style: labelStyle,
                  ),
                ),
              if (isTarget)
                CustomPaint(
                  painter: _MoveTargetPainter(isCapture: piece != null),
                ),
              if (isPassThrough)
                CustomPaint(painter: _RedXPainter()),
            ],
          ),
        ),
      ),
    );
  }

  // -------- Piece layer (animated) -------------------------------------

  List<Widget> _buildPieces(double size, int ranks) {
    final widgets = <Widget>[];
    widget.board.pieces.forEach((sq, piece) {
      final id = _ids[sq];
      if (id == null) return; // shouldn't happen; safety net
      final displayRank = ranks - 1 - sq.rank;
      widgets.add(AnimatedPositioned(
        key: ValueKey(id),
        duration: _animDuration,
        curve: _animCurve,
        left: sq.file * size,
        top: displayRank * size,
        width: size,
        height: size,
        // Pieces don't intercept taps; the square layer below handles them.
        child: IgnorePointer(
          child: _PieceImage(piece: piece, size: size),
        ),
      ));
    });
    return widgets;
  }
}

/// Paints a subtle wood-grain texture across a square. Each square seeds
/// its own pattern from (file * 31 + rank) so adjacent squares don't
/// duplicate the same grain. The pattern is 4 to 6 sine-wave streaks
/// at low opacity — enough to feel like a wooden surface without
/// competing with pieces or move-target overlays.
class _WoodGrainPainter extends CustomPainter {
  final int seed;
  final bool isLight;
  const _WoodGrainPainter({required this.seed, required this.isLight});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    // Light squares get a slightly darker grain; dark squares get a
    // slightly darker-still grain (we want the texture to read as
    // wood, never as a highlight).
    final color = isLight
        ? const Color(0x18000000) // ~9% black on tan
        : const Color(0x22000000); // ~13% black on brown — slightly stronger
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..isAntiAlias = true;

    // 4–6 streaks per square, evenly distributed vertically with random
    // jitter, sine-wave phase/frequency for organic wobble.
    final streakCount = 4 + rng.nextInt(3);
    for (int i = 0; i < streakCount; i++) {
      final yBase = ((i + 0.5) / streakCount) * size.height
          + (rng.nextDouble() - 0.5) * size.height * 0.08;
      final amplitude = 0.6 + rng.nextDouble() * 1.4;
      final freq = 0.04 + rng.nextDouble() * 0.06;
      final phase = rng.nextDouble() * 2 * pi;

      final path = Path()..moveTo(0, yBase);
      for (double x = 1; x <= size.width; x += 2) {
        final y = yBase + sin(x * freq + phase) * amplitude;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }

    // A handful of short knots / accent flecks add visual noise without
    // dominating. ~3 per square, 1-3 px each.
    final fleckPaint = Paint()..color = color.withOpacity(color.opacity * 1.6);
    for (int i = 0; i < 3; i++) {
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final r = 0.5 + rng.nextDouble() * 1.0;
      canvas.drawCircle(Offset(cx, cy), r, fleckPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WoodGrainPainter old) =>
      old.seed != seed || old.isLight != isLight;
}

/// Paints a green indicator on a legal move-target square.
/// Empty target -> filled circle in the center.
/// Capture target -> hollow ring around the piece.
class _MoveTargetPainter extends CustomPainter {
  final bool isCapture;
  const _MoveTargetPainter({required this.isCapture});

  static const _green = Color(0xCC2E7D32);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    if (isCapture) {
      // Hollow ring hugging the square edge so it surrounds the piece.
      final stroke = Paint()
        ..color = _green
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.08;
      final radius = size.width * 0.45;
      canvas.drawCircle(center, radius, stroke);
    } else {
      // Filled dot in the middle, ~30% of square width.
      final fill = Paint()..color = _green;
      canvas.drawCircle(center, size.width * 0.15, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _MoveTargetPainter old) =>
      old.isCapture != isCapture;
}

/// Paints a bold red X across a square (used for Barbarian pass-through pieces).
class _RedXPainter extends CustomPainter {
  static const _red = Color(0xFFD32F2F);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _red
      ..strokeWidth = size.width * 0.12
      ..strokeCap = StrokeCap.round;
    final m = size.width * 0.20;
    canvas.drawLine(Offset(m, m), Offset(size.width - m, size.height - m), paint);
    canvas.drawLine(Offset(size.width - m, m), Offset(m, size.height - m), paint);
  }

  @override
  bool shouldRepaint(covariant _RedXPainter old) => false;
}

/// Renders a piece via the Unicode chess glyphs with a gradient body,
/// outline stroke, and drop shadow.
class _PieceImage extends StatelessWidget {
  final Piece piece;
  final double size;
  const _PieceImage({required this.piece, required this.size});

  @override
  Widget build(BuildContext context) {
    return _PieceGlyph(piece: piece, fontSize: size * 0.85);
  }
}

class _PieceGlyph extends StatelessWidget {
  final Piece piece;
  final double fontSize;
  const _PieceGlyph({required this.piece, required this.fontSize});

  static const _solidGlyph = <PieceType, String>{
    PieceType.king:   '♚',
    PieceType.queen:  '♛',
    PieceType.rook:   '♜',
    PieceType.bishop: '♝',
    PieceType.knight: '♞',
    PieceType.pawn:   '♟',
  };

  @override
  Widget build(BuildContext context) {
    final glyph = _solidGlyph[piece.type]!;
    final isWhite = piece.color == PieceColor.white;

    final base = TextStyle(
      fontSize: fontSize,
      height: 1.0,
      fontWeight: FontWeight.w900,
    );

    final fillColors = isWhite
        ? const [Color(0xFFFAFAFA), Color(0xFFB0B0B0)]
        : const [Color(0xFF2A2A2A), Color(0xFF000000)];
    final outlineColor = isWhite ? Colors.black87 : Colors.white;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Drop shadow
          Transform.translate(
            offset: Offset(fontSize * 0.04, fontSize * 0.05),
            child: Text(glyph, style: base.copyWith(color: Colors.black38)),
          ),
          // Outline stroke
          Text(
            glyph,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = fontSize * 0.04
                ..color = outlineColor,
            ),
          ),
          // Gradient body via ShaderMask
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: fillColors,
            ).createShader(rect),
            child: Text(glyph, style: base.copyWith(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
