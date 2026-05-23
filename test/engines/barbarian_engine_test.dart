import 'package:flutter_test/flutter_test.dart';

import 'package:fivefold_chess/domain/engines/barbarian_engine.dart';
import 'package:fivefold_chess/domain/models/board.dart';
import 'package:fivefold_chess/domain/models/castling_rights.dart';
import 'package:fivefold_chess/domain/models/game_state.dart';
import 'package:fivefold_chess/domain/models/piece.dart';
import 'package:fivefold_chess/domain/models/square.dart';
import 'package:fivefold_chess/domain/models/variant.dart';

/// Tiny helper to build a board from a sparse {Square: Piece} map.
Board _board(Map<Square, Piece> pieces) =>
    Board(files: 8, ranks: 8, pieces: Map.unmodifiable(pieces));

GameState _state(Map<Square, Piece> pieces, PieceColor side) => GameState(
      variant: Variant.barbarian,
      board: _board(pieces),
      sideToMove: side,
      history: const [],
      rights: CastlingRights.none,
      enPassantTarget: null,
      halfmoveClock: 0,
      fullmoveNumber: 1,
    );

void main() {
  group('Barbarian rule engine', () {
    test('Rook can pass through an enemy piece to capture another enemy piece', () {
      // White rook a1, Black pawn a4 (pass-through), Black knight a7 (target).
      // Kings required so that check-filtering logic has something to check.
      final s = _state({
        const Square(0, 0): const Piece(PieceType.rook, PieceColor.white),
        const Square(0, 3): const Piece(PieceType.pawn, PieceColor.black),
        const Square(0, 6): const Piece(PieceType.knight, PieceColor.black),
        const Square(4, 0): const Piece(PieceType.king, PieceColor.white),
        const Square(4, 7): const Piece(PieceType.king, PieceColor.black),
      }, PieceColor.white);

      final engine = BarbarianEngine();
      final moves = engine.legalMoves(s);
      final barbarian = moves.where((m) => m.isBarbarian).toList();

      expect(
        barbarian.any((m) =>
            m.from == const Square(0, 0) &&
            m.to == const Square(0, 6) &&
            m.barbarianPassThrough == const Square(0, 3)),
        isTrue,
        reason: 'Rook should generate a barbarian move a1 -> a7 through a4',
      );
    });

    test('Knight cannot perform a barbarian move', () {
      final s = _state({
        const Square(1, 0): const Piece(PieceType.knight, PieceColor.white),
        const Square(2, 2): const Piece(PieceType.pawn, PieceColor.black),
        const Square(3, 4): const Piece(PieceType.queen, PieceColor.black),
        const Square(4, 0): const Piece(PieceType.king, PieceColor.white),
        const Square(4, 7): const Piece(PieceType.king, PieceColor.black),
      }, PieceColor.white);
      final engine = BarbarianEngine();
      final moves = engine.legalMoves(s);
      expect(moves.any((m) => m.isBarbarian), isFalse);
    });

    test('Bishop can sacrifice its own pawn as the pass-through piece', () {
      // White bishop f1, own pawn d3 (pass-through), black rook a6 (target).
      final s = _state({
        const Square(5, 0): const Piece(PieceType.bishop, PieceColor.white),
        const Square(3, 2): const Piece(PieceType.pawn, PieceColor.white),
        const Square(0, 5): const Piece(PieceType.rook, PieceColor.black),
        const Square(4, 0): const Piece(PieceType.king, PieceColor.white),
        const Square(4, 7): const Piece(PieceType.king, PieceColor.black),
      }, PieceColor.white);
      final engine = BarbarianEngine();
      final moves = engine.legalMoves(s);
      final barbarian = moves.where((m) => m.isBarbarian).toList();
      expect(
        barbarian.any((m) =>
            m.from == const Square(5, 0) &&
            m.to == const Square(0, 5) &&
            m.barbarianPassThrough == const Square(3, 2)),
        isTrue,
      );
    });

    test('Two pieces between attacker and target is not a barbarian move', () {
      final s = _state({
        const Square(0, 0): const Piece(PieceType.rook, PieceColor.white),
        const Square(0, 2): const Piece(PieceType.pawn, PieceColor.black),
        const Square(0, 4): const Piece(PieceType.pawn, PieceColor.black),
        const Square(0, 6): const Piece(PieceType.knight, PieceColor.black),
        const Square(4, 0): const Piece(PieceType.king, PieceColor.white),
        const Square(4, 7): const Piece(PieceType.king, PieceColor.black),
      }, PieceColor.white);
      final engine = BarbarianEngine();
      final moves = engine.legalMoves(s);
      // The barbarian move generated should stop at the first target
      // after the first pass-through — namely a5 (rank 4). It should
      // NOT produce a move to a7.
      final toA7 = moves.where((m) => m.isBarbarian && m.to == const Square(0, 6));
      expect(toA7, isEmpty);
    });

    test('applyMove removes BOTH pass-through and target piece', () {
      final s = _state({
        const Square(0, 0): const Piece(PieceType.rook, PieceColor.white),
        const Square(0, 3): const Piece(PieceType.pawn, PieceColor.black),
        const Square(0, 6): const Piece(PieceType.knight, PieceColor.black),
        const Square(4, 0): const Piece(PieceType.king, PieceColor.white),
        const Square(4, 7): const Piece(PieceType.king, PieceColor.black),
      }, PieceColor.white);
      final engine = BarbarianEngine();
      final m = engine.legalMoves(s).firstWhere(
            (m) => m.isBarbarian && m.to == const Square(0, 6),
          );
      final next = engine.applyMove(s, m);
      expect(next.board.at(const Square(0, 3)), isNull); // pass-through gone
      expect(next.board.at(const Square(0, 6))?.type, PieceType.rook); // attacker landed
      expect(next.board.at(const Square(0, 0)), isNull); // attacker left a1
    });
  });
}
