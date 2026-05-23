// lib/presentation/widgets/board_widget.dart
//
// Vector-rendered chess pieces via CustomPainter. No font dependency —
// every piece is drawn with identical shading logic, so pawns and back-row
// pieces share the same 3D look on every device.

import 'package:flutter/material.dart';

import '../../domain/models/board.dart';
import '../../domain/models/piece.dart';
import '../../domain/models/square.dart';

class BoardWidget extends StatelessWidget {
  final Board board;
  final int files;
  final int ranks;
  final Square? selected;
  final Set<Square> legalTargets;
  final void Function(Square)? onTapSquare;

  const BoardWidget({
    super.key,
    required this.board,
    this.files = 8,
    this.ranks = 8,
    this.selected,
    this.legalTargets = const {},
    this.onTapSquare,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final side = constraints.maxWidth < constraints.maxHeight
            ? constraints.maxWidth
            : constraints.maxHeight;
        final squareSize = side / files;

        return SizedBox(
          width: squareSize * files,
          height: squareSize * ranks,
          child: Stack(
            children: [
              for (int r = 0; r < ranks; r++)
                for (int f = 0; f < files; f++)
                  _buildSquare(context, f, r, squareSize),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSquare(BuildContext ctx, int file, int rank, double size) {
    final sq = Square(file: file, rank: rank);
    final isLight = (file + rank).isEven;
    final isSelected = selected == sq;
    final isTarget = legalTargets.contains(sq);

    final base = isLight
        ? const Color(0xFFEFE0C2)
        : const Color(0xFF8B6F47);

    Color squareColor = base;
    if (isSelected) {
      squareColor = Color.alphaBlend(const Color(0x66FFD54F), base);
    } else if (isTarget) {
      squareColor = Color.alphaBlend(const Color(0x5581C784), base);
    }

    final piece = board.at(sq);
    final displayRank = ranks - 1 - rank;

    return Positioned(
      left: file * size,
      top: displayRank * size,
      width: size,
      height: size,
      child: GestureDetector(
        onTap: () => onTapSquare?.call(sq),
        child: Container(
          color: squareColor,
          child: piece == null
              ? const SizedBox.expand()
              : CustomPaint(
                  painter: _PiecePainter(piece),
                  size: Size.square(size),
                ),
        ),
      ),
    );
  }
}

/// Draws a single chess piece centered in its square with 3D shading.
class _PiecePainter extends CustomPainter {
  final Piece piece;
  const _PiecePainter(this.piece);

  @override
  void paint(Canvas canvas, Size size) {
    final isWhite = piece.color == PieceColor.white;
    final bodyTop = isWhite ? const Color(0xFFFAFAFA) : const Color(0xFF2A2A2A);
    final bodyBottom = isWhite ? const Color(0xFFB0B0B0) : const Color(0xFF000000);
    final outline = isWhite ? const Color(0xFF1A1A1A) : const Color(0xFFEAEAEA);

    final cx = size.width / 2;
    final unit = size.width / 10; // drawing unit

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [bodyTop, bodyBottom],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final strokePaint = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.22
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;

    final shadow = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    Path path;
    switch (piece.type) {
      case PieceType.pawn:
        path = _pawnPath(cx, size.height, unit);
        break;
      case PieceType.rook:
        path = _rookPath(cx, size.height, unit);
        break;
      case PieceType.knight:
        path = _knightPath(cx, size.height, unit, isWhite);
        break;
      case PieceType.bishop:
        path = _bishopPath(cx, size.height, unit);
        break;
      case PieceType.queen:
        path = _queenPath(cx, size.height, unit);
        break;
      case PieceType.king:
        path = _kingPath(cx, size.height, unit);
        break;
    }

    // Soft drop shadow for depth
    canvas.save();
    canvas.translate(unit * 0.15, unit * 0.25);
    canvas.drawPath(path, shadow);
    canvas.restore();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);

    // Top highlight for glossy 3D look
    final highlight = Paint()
      ..color = isWhite ? const Color(0x66FFFFFF) : const Color(0x33FFFFFF)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.clipPath(path);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - unit * 0.6, size.height * 0.3),
        width: unit * 2.2,
        height: unit * 1.1,
      ),
      highlight,
    );
    canvas.restore();
  }

  // --- Piece silhouettes ---------------------------------------------------

  Path _pawnPath(double cx, double h, double u) {
    final p = Path();
    final headY = h * 0.22;
    final headR = u * 1.15;
    // Base
    p.moveTo(cx - u * 2.6, h * 0.9);
    p.lineTo(cx + u * 2.6, h * 0.9);
    p.lineTo(cx + u * 2.3, h * 0.82);
    p.lineTo(cx - u * 2.3, h * 0.82);
    p.close();
    // Stem
    p.moveTo(cx - u * 1.5, h * 0.82);
    p.quadraticBezierTo(cx - u * 1.1, h * 0.55, cx - u * 0.9, headY + headR);
    p.lineTo(cx + u * 0.9, headY + headR);
    p.quadraticBezierTo(cx + u * 1.1, h * 0.55, cx + u * 1.5, h * 0.82);
    p.close();
    // Head (circle)
    p.addOval(Rect.fromCircle(center: Offset(cx, headY), radius: headR));
    return p;
  }

  Path _rookPath(double cx, double h, double u) {
    final p = Path();
    // Base
    p.moveTo(cx - u * 2.8, h * 0.92);
    p.lineTo(cx + u * 2.8, h * 0.92);
    p.lineTo(cx + u * 2.4, h * 0.82);
    p.lineTo(cx - u * 2.4, h * 0.82);
    p.close();
    // Body
    p.moveTo(cx - u * 2.0, h * 0.82);
    p.lineTo(cx - u * 2.0, h * 0.32);
    p.lineTo(cx - u * 2.4, h * 0.32);
    p.lineTo(cx - u * 2.4, h * 0.18);
    p.lineTo(cx - u * 1.6, h * 0.18);
    p.lineTo(cx - u * 1.6, h * 0.26);
    p.lineTo(cx - u * 0.6, h * 0.26);
    p.lineTo(cx - u * 0.6, h * 0.18);
    p.lineTo(cx + u * 0.6, h * 0.18);
    p.lineTo(cx + u * 0.6, h * 0.26);
    p.lineTo(cx + u * 1.6, h * 0.26);
    p.lineTo(cx + u * 1.6, h * 0.18);
    p.lineTo(cx + u * 2.4, h * 0.18);
    p.lineTo(cx + u * 2.4, h * 0.32);
    p.lineTo(cx + u * 2.0, h * 0.32);
    p.lineTo(cx + u * 2.0, h * 0.82);
    p.close();
    return p;
  }

  Path _knightPath(double cx, double h, double u, bool isWhite) {
    final p = Path();
    // Base
    p.moveTo(cx - u * 2.8, h * 0.92);
    p.lineTo(cx + u * 2.8, h * 0.92);
    p.lineTo(cx + u * 2.4, h * 0.82);
    p.lineTo(cx - u * 2.4, h * 0.82);
    p.close();
    // Horse silhouette (stylized)
    p.moveTo(cx - u * 2.0, h * 0.82);
    p.quadraticBezierTo(cx - u * 2.6, h * 0.60, cx - u * 1.8, h * 0.45);
    p.quadraticBezierTo(cx - u * 2.4, h * 0.35, cx - u * 1.6, h * 0.22);
    p.quadraticBezierTo(cx - u * 0.4, h * 0.05, cx + u * 1.6, h * 0.15);
    p.quadraticBezierTo(cx + u * 2.4, h * 0.30, cx + u * 2.0, h * 0.55);
    p.quadraticBezierTo(cx + u * 1.2, h * 0.62, cx + u * 0.8, h * 0.82);
    p.close();
    return p;
  }

  Path _bishopPath(double cx, double h, double u) {
    final p = Path();
    // Base
    p.moveTo(cx - u * 2.6, h * 0.92);
    p.lineTo(cx + u * 2.6, h * 0.92);
    p.lineTo(cx + u * 2.2, h * 0.82);
    p.lineTo(cx - u * 2.2, h * 0.82);
    p.close();
    // Body (teardrop mitre)
    p.moveTo(cx, h * 0.10);
    p.quadraticBezierTo(cx + u * 2.0, h * 0.40, cx + u * 1.6, h * 0.70);
    p.lineTo(cx + u * 1.8, h * 0.74);
    p.lineTo(cx - u * 1.8, h * 0.74);
    p.lineTo(cx - u * 1.6, h * 0.70);
    p.quadraticBezierTo(cx - u * 2.0, h * 0.40, cx, h * 0.10);
    p.close();
    // Finial
    p.addOval(Rect.fromCircle(center: Offset(cx, h * 0.08), radius: u * 0.35));
    return p;
  }

  Path _queenPath(double cx, double h, double u) {
    final p = Path();
    // Base
    p.moveTo(cx - u * 2.8, h * 0.92);
    p.lineTo(cx + u * 2.8, h * 0.92);
    p.lineTo(cx + u * 2.4, h * 0.82);
    p.lineTo(cx - u * 2.4, h * 0.82);
    p.close();
    // Body bowl
    p.moveTo(cx - u * 2.2, h * 0.82);
    p.quadraticBezierTo(cx - u * 2.8, h * 0.55, cx - u * 2.0, h * 0.40);
    p.lineTo(cx + u * 2.0, h * 0.40);
    p.quadraticBezierTo(cx + u * 2.8, h * 0.55, cx + u * 2.2, h * 0.82);
    p.close();
    // Crown spikes
    final spikes = [
      Offset(cx - u * 2.3, h * 0.10),
      Offset(cx - u * 1.1, h * 0.15),
      Offset(cx, h * 0.06),
      Offset(cx + u * 1.1, h * 0.15),
      Offset(cx + u * 2.3, h * 0.10),
    ];
    p.moveTo(cx - u * 2.0, h * 0.40);
    for (final s in spikes) {
      p.lineTo(s.dx, s.dy);
    }
    p.lineTo(cx + u * 2.0, h * 0.40);
    p.close();
    for (final s in spikes) {
      p.addOval(Rect.fromCircle(center: s, radius: u * 0.35));
    }
    return p;
  }

  Path _kingPath(double cx, double h, double u) {
    final p = Path();
    // Base
    p.moveTo(cx - u * 2.8, h * 0.92);
    p.lineTo(cx + u * 2.8, h * 0.92);
    p.lineTo(cx + u * 2.4, h * 0.82);
    p.lineTo(cx - u * 2.4, h * 0.82);
    p.close();
    // Body
    p.moveTo(cx - u * 2.2, h * 0.82);
    p.quadraticBezierTo(cx - u * 2.6, h * 0.55, cx - u * 1.6, h * 0.38);
    p.lineTo(cx + u * 1.6, h * 0.38);
    p.quadraticBezierTo(cx + u * 2.6, h * 0.55, cx + u * 2.2, h * 0.82);
    p.close();
    // Cross
    p.addRect(Rect.fromLTWH(cx - u * 0.35, h * 0.04, u * 0.7, u * 2.0));
    p.addRect(Rect.fromLTWH(cx - u * 1.2, h * 0.16, u * 2.4, u * 0.6));
    return p;
  }

  @override
  bool shouldRepaint(covariant _PiecePainter old) => old.piece != piece;
}
