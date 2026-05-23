import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../engines/engines.dart';
import '../engines/rule_engine.dart';
import '../models/game_state.dart';
import '../models/move.dart';
import '../models/piece.dart';
import '../models/variant.dart';
import 'ai_difficulty.dart';
import 'stockfish_adapter.dart';

/// Maximum wall-clock time the AI is allowed to spend on one move before
/// we abandon the search and fall back to a random legal move. Keeps the
/// game playable if a position is pathologically expensive to search.
const _aiTimeout = Duration(seconds: 6);

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Picks a move for the computer opponent on a background isolate.
///
/// The search runs in a Flutter `compute()` worker so the main thread stays
/// responsive. If the search exceeds [_aiTimeout] (e.g. on a very crowded
/// Barbarian position), we fall back to a random legal move so the game
/// can keep moving.
class AiService {
  final Random _rng;

  AiService({Random? random}) : _rng = random ?? Random();

  Future<Move?> pickMove(
    RuleEngine engine,
    GameState state,
    AiDifficulty difficulty,
  ) async {
    final legal = engine.legalMoves(state);
    if (legal.isEmpty) return null;

    // Beginner-tier randomness: sometimes pick a non-best move on purpose.
    if (_rng.nextDouble() < difficulty.blunderRate) {
      return legal[_rng.nextInt(legal.length)];
    }

    // Classic Chess routes through real Stockfish for vastly stronger play
    // and proper skill-level scaling. Variants stay on minimax because
    // Stockfish doesn't know their rules.
    if (state.variant == Variant.classic) {
      final stockfishMove = await _pickWithStockfish(state, difficulty, legal);
      if (stockfishMove != null) return stockfishMove;
      // If Stockfish failed for any reason, fall through to minimax.
    }

    return _pickWithMinimax(state, difficulty, legal);
  }

  /// Run the Stockfish adapter with a timeout. Returns null if the engine
  /// didn't produce a usable move (timeout, parse failure, illegal move).
  Future<Move?> _pickWithStockfish(
    GameState state,
    AiDifficulty difficulty,
    List<Move> legal,
  ) async {
    try {
      final move = await StockfishAdapter.instance
          .pickMove(state, difficulty, timeout: _aiTimeout);
      if (move == null) return null;
      // Sanity check: confirm the returned move matches one in our legal
      // list. Compare on (from, to, promotion) since Stockfish doesn't
      // populate our internal castle/ep flags the same way.
      final matched = legal.firstWhere(
        (m) => m.from == move.from &&
               m.to == move.to &&
               m.promotion == move.promotion,
        orElse: () => move,
      );
      return matched;
    } catch (_) {
      return null;
    }
  }

  /// Generic minimax fallback (used for variants and as a Stockfish backup).
  Future<Move?> _pickWithMinimax(
    GameState state,
    AiDifficulty difficulty,
    List<Move> legal,
  ) async {
    final req = _AiRequest(
      variant: state.variant,
      history: state.history.map((m) => m.toJson()).toList(growable: false),
      depth: difficulty.variantDepth,
      seed: _rng.nextInt(0x7fffffff),
    );

    try {
      final pickJson = await compute(_pickMoveOnIsolate, req)
          .timeout(_aiTimeout, onTimeout: () => null);
      if (pickJson == null) {
        return legal[_rng.nextInt(legal.length)];
      }
      return Move.fromJson(pickJson);
    } catch (_) {
      return legal[_rng.nextInt(legal.length)];
    }
  }
}

// ---------------------------------------------------------------------------
// Isolate-side implementation
// ---------------------------------------------------------------------------

/// Sendable request: just the variant, the move history, and the search
/// parameters. Reconstructing the engine + state on the worker side is
/// cheap and keeps the payload to plain JSON-able types.
class _AiRequest {
  final Variant variant;
  final List<Map<String, dynamic>> history;
  final int depth;
  final int seed;
  const _AiRequest({
    required this.variant,
    required this.history,
    required this.depth,
    required this.seed,
  });
}

/// Top-level entry point for `compute()`. Replays the move history on a
/// fresh engine, runs minimax + alpha-beta to [depth], and returns the
/// chosen move's JSON form.
Map<String, dynamic>? _pickMoveOnIsolate(_AiRequest req) {
  final engine = engineFor(req.variant);
  GameState state = engine.initialState();
  for (final h in req.history) {
    state = engine.applyMove(state, Move.fromJson(h));
  }

  final legal = engine.legalMoves(state);
  if (legal.isEmpty) return null;

  final rng = Random(req.seed);
  final maximizing = state.sideToMove == PieceColor.white;

  Move? best;
  double bestScore = maximizing ? -double.infinity : double.infinity;
  // Light shuffle so equal-scoring moves don't always pick the same move.
  final shuffled = [...legal]..shuffle(rng);

  for (final m in shuffled) {
    final next = engine.applyMove(state, m);
    final score = _minimax(
      engine: engine,
      state: next,
      depth: req.depth - 1,
      alpha: -double.infinity,
      beta: double.infinity,
      maximizing: !maximizing,
    );
    if (maximizing) {
      if (score > bestScore) { bestScore = score; best = m; }
    } else {
      if (score < bestScore) { bestScore = score; best = m; }
    }
  }
  return (best ?? legal.first).toJson();
}

double _minimax({
  required RuleEngine engine,
  required GameState state,
  required int depth,
  required double alpha,
  required double beta,
  required bool maximizing,
}) {
  final terminal = engine.terminal(state);
  if (terminal != null) {
    switch (terminal) {
      case GameResult.whiteWins: return  100000.0;
      case GameResult.blackWins: return -100000.0;
      case GameResult.draw:      return 0.0;
    }
  }
  if (depth <= 0) return _evaluate(state);

  final moves = engine.legalMoves(state);
  if (moves.isEmpty) return _evaluate(state);

  if (maximizing) {
    double value = -double.infinity;
    for (final m in moves) {
      final next = engine.applyMove(state, m);
      final score = _minimax(
        engine: engine, state: next,
        depth: depth - 1, alpha: alpha, beta: beta, maximizing: false,
      );
      if (score > value) value = score;
      if (value > alpha) alpha = value;
      if (alpha >= beta) break;
    }
    return value;
  } else {
    double value = double.infinity;
    for (final m in moves) {
      final next = engine.applyMove(state, m);
      final score = _minimax(
        engine: engine, state: next,
        depth: depth - 1, alpha: alpha, beta: beta, maximizing: true,
      );
      if (score < value) value = score;
      if (value < beta) beta = value;
      if (alpha >= beta) break;
    }
    return value;
  }
}

/// Material count from white's perspective. Positive = white better.
double _evaluate(GameState s) {
  double score = 0;
  s.board.pieces.forEach((_, p) {
    final v = _pieceValue(p.type);
    score += p.color == PieceColor.white ? v : -v;
  });
  return score;
}

double _pieceValue(PieceType t) {
  switch (t) {
    case PieceType.pawn:   return 1.0;
    case PieceType.knight: return 3.0;
    case PieceType.bishop: return 3.1;
    case PieceType.rook:   return 5.0;
    case PieceType.queen:  return 9.0;
    case PieceType.king:   return 200.0;
  }
}
