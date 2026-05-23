import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stockfish/stockfish.dart';

import '../models/game_state.dart';
import '../models/move.dart';
import '../models/piece.dart';
import '../models/square.dart';
import 'ai_difficulty.dart';

/// Lazily-started singleton wrapper around the Stockfish engine.
///
/// Only used for Classic Chess. Variants stay on the generic minimax
/// because Stockfish doesn't know our extra rules (Long board, Barbarian
/// pass-through, Reverse antichess, Silent's check-suppression doesn't
/// affect strategy but the others do).
class StockfishAdapter {
  StockfishAdapter._();
  static final StockfishAdapter instance = StockfishAdapter._();

  Stockfish? _engine;
  Future<void>? _readyFuture;

  Future<Stockfish> _ensureReady() async {
    if (_engine != null && _engine!.state.value == StockfishState.ready) {
      return _engine!;
    }
    _engine ??= Stockfish();
    _readyFuture ??= _waitReady();
    await _readyFuture;
    return _engine!;
  }

  Future<void> _waitReady() async {
    final e = _engine!;
    if (e.state.value == StockfishState.ready) return;
    final completer = Completer<void>();
    late VoidCallback listener;
    listener = () {
      if (e.state.value == StockfishState.ready && !completer.isCompleted) {
        e.state.removeListener(listener);
        completer.complete();
      }
    };
    e.state.addListener(listener);
    return completer.future;
  }

  /// Ask Stockfish for the best move from [state] at the given difficulty.
  /// Returns null if Stockfish reports no legal move (i.e. terminal).
  /// May throw [TimeoutException] — caller should fall back to a random move.
  Future<Move?> pickMove(
    GameState state,
    AiDifficulty difficulty, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final engine = await _ensureReady();

    final fen = _toFen(state);
    final completer = Completer<String?>();
    late StreamSubscription<String> sub;
    sub = engine.stdout.listen((line) {
      if (line.startsWith('bestmove ')) {
        final parts = line.split(' ');
        final mv = parts.length > 1 ? parts[1] : null;
        if (!completer.isCompleted) {
          completer.complete((mv == null || mv == '(none)') ? null : mv);
        }
      }
    });

    // Configure skill, set position, search. Reserve ~80% of the timeout
    // for actual search so the IO round-trip can't starve us.
    final searchMs = (timeout.inMilliseconds * 0.8).round();
    engine.stdin = 'setoption name Skill Level value ${difficulty.stockfishSkill}';
    engine.stdin = 'position fen $fen';
    engine.stdin = 'go movetime $searchMs';

    String? uci;
    try {
      uci = await completer.future.timeout(timeout);
    } on TimeoutException {
      // Tell Stockfish to stop searching so the next call starts fresh.
      engine.stdin = 'stop';
      rethrow;
    } finally {
      await sub.cancel();
    }

    if (uci == null) return null;
    return _uciToMove(uci, state);
  }

  /// Releases the Stockfish process. Call from app lifecycle if you want.
  void dispose() {
    _engine?.dispose();
    _engine = null;
    _readyFuture = null;
  }

  // ---------------------------------------------------------------------
  // FEN encoding
  // ---------------------------------------------------------------------

  String _toFen(GameState s) {
    // 8 ranks from rank 7 (top, black's back rank in our coords) down to 0.
    final rankStrs = <String>[];
    for (int r = 7; r >= 0; r--) {
      final buf = StringBuffer();
      int empty = 0;
      for (int f = 0; f < 8; f++) {
        final piece = s.board.at(Square(f, r));
        if (piece == null) {
          empty++;
        } else {
          if (empty > 0) {
            buf.write(empty);
            empty = 0;
          }
          buf.write(piece.type.toFenChar(piece.color));
        }
      }
      if (empty > 0) buf.write(empty);
      rankStrs.add(buf.toString());
    }
    final boardPart = rankStrs.join('/');
    final sideChar = s.sideToMove == PieceColor.white ? 'w' : 'b';

    final castle = StringBuffer();
    if (s.rights.whiteKingside)  castle.write('K');
    if (s.rights.whiteQueenside) castle.write('Q');
    if (s.rights.blackKingside)  castle.write('k');
    if (s.rights.blackQueenside) castle.write('q');
    final castleStr = castle.isEmpty ? '-' : castle.toString();

    final ep = s.enPassantTarget != null
        ? _algebraic(s.enPassantTarget!)
        : '-';

    return '$boardPart $sideChar $castleStr $ep '
           '${s.halfmoveClock} ${s.fullmoveNumber}';
  }

  String _algebraic(Square sq) {
    final fileChar = String.fromCharCode('a'.codeUnitAt(0) + sq.file);
    return '$fileChar${sq.rank + 1}';
  }

  // ---------------------------------------------------------------------
  // UCI move parsing
  // ---------------------------------------------------------------------

  Square _parseSquare(String alg) {
    final f = alg.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final r = int.parse(alg[1]) - 1;
    return Square(f, r);
  }

  /// Parse a UCI move string ("e2e4", "e7e8q", "e1g1") into our Move model.
  /// We need [state] to detect castling (king moving 2 squares) and en
  /// passant (pawn capturing onto an empty square).
  Move _uciToMove(String uci, GameState state) {
    final from = _parseSquare(uci.substring(0, 2));
    final to   = _parseSquare(uci.substring(2, 4));
    PieceType? promo;
    if (uci.length >= 5) {
      switch (uci[4]) {
        case 'q': promo = PieceType.queen;  break;
        case 'r': promo = PieceType.rook;   break;
        case 'b': promo = PieceType.bishop; break;
        case 'n': promo = PieceType.knight; break;
      }
    }

    final piece = state.board.at(from);
    bool castleK = false;
    bool castleQ = false;
    if (piece?.type == PieceType.king && (to.file - from.file).abs() == 2) {
      castleK = (to.file > from.file);
      castleQ = !castleK;
    }

    bool ep = false;
    if (piece?.type == PieceType.pawn &&
        to.file != from.file &&
        state.board.at(to) == null) {
      ep = (state.enPassantTarget == to);
    }

    return Move(
      from: from,
      to: to,
      promotion: promo,
      isCastleKingside: castleK,
      isCastleQueenside: castleQ,
      enPassantCapture: ep,
    );
  }
}

