import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../data/ads/admob_service.dart';
import '../../data/firebase/firebase_service.dart';
import '../../data/sounds/sound_service.dart';
import '../../domain/ai/ai_difficulty.dart';
import '../../domain/ai/ai_service.dart';
import '../../domain/engines/classic_engine.dart';
import '../../domain/engines/engines.dart';
import '../../domain/engines/rule_engine.dart';
import '../../domain/models/game_state.dart';
import '../../domain/models/move.dart';
import '../../domain/models/piece.dart';
import '../../domain/models/square.dart';
import '../../domain/models/variant.dart';
import '../../domain/utils/capture_tracker.dart';
import '../../domain/utils/move_notation.dart';
import '../widgets/board_widget.dart';
import '../widgets/captured_pieces_strip.dart';
import '../widgets/chess_background.dart';
import '../widgets/move_history_sheet.dart';

class GameScreenArgs {
  final Variant variant;
  /// If non-null, single-player vs AI mode. The human plays white;
  /// the AI plays black at the given difficulty.
  final AiDifficulty? aiDifficulty;
  /// If non-null, this is an online match. The local user plays
  /// [localPlaysWhite] ? white : black, and moves are synced via
  /// Firestore document `/games/{onlineGameId}`.
  final String? onlineGameId;
  final bool localPlaysWhite;

  const GameScreenArgs({
    required this.variant,
    this.aiDifficulty,
    this.onlineGameId,
    this.localPlaysWhite = true,
  });
}

class GameScreen extends StatefulWidget {
  static const route = '/game';
  final GameScreenArgs args;
  const GameScreen({super.key, required this.args});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late RuleEngine _engine;
  late GameState _state;
  Square? _selected;
  List<Move> _legalFromSelection = const [];
  bool _aiThinking = false;
  final AiService _ai = AiService();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _onlineSub;

  // ---- Lone-king 21-move stalemate rule -------------------------------
  // When one side has only their king remaining, they must be checkmated
  // within [_kLoneKingMoveBudget] of their own moves or the game is a
  // draw. Doesn't apply to Reverse Chess (where losing your pieces is
  // the goal).

  static const int _kLoneKingMoveBudget = 21;

  /// Which side currently has only its king on the board (or null).
  PieceColor? _loneKingSide;

  /// Moves remaining for [_loneKingSide] before the auto-draw triggers.
  /// null when the rule isn't active.
  int? _loneKingMovesLeft;

  /// Whether the lone-king rule applies in the current variant.
  bool get _loneKingRuleEnabled =>
      widget.args.variant != Variant.reverse;

  @override
  void initState() {
    super.initState();
    _engine = engineFor(widget.args.variant);
    _state = _engine.initialState();
    if (_isOnline) {
      _subscribeOnline();
    }
  }

  @override
  void dispose() {
    _onlineSub?.cancel();
    super.dispose();
  }

  /// Whether this game is a single-player session against the computer.
  bool get _vsAi => widget.args.aiDifficulty != null;

  /// The color the AI plays. The human always plays white in v1.
  PieceColor get _aiColor => PieceColor.black;

  /// Whether this game is an online match synced via Firestore.
  bool get _isOnline => widget.args.onlineGameId != null;

  /// In an online match, the color the local user plays.
  PieceColor get _localColor =>
      widget.args.localPlaysWhite ? PieceColor.white : PieceColor.black;

  void _subscribeOnline() {
    _onlineSub = FirebaseService.instance
        .gameStream(widget.args.onlineGameId!)
        .listen(_onRemoteUpdate);
  }

  /// Replay the remote `history` array on top of the initial state. Pure
  /// engine.applyMove guarantees that both clients converge.
  void _onRemoteUpdate(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) return;
    final history = (data['history'] as List?) ?? const [];
    GameState s = _engine.initialState();
    final moves = <Move>[];
    for (final raw in history) {
      try {
        final mv = Move.fromJson(Map<String, dynamic>.from(raw as Map));
        s = _engine.applyMove(s, mv);
        moves.add(mv);
      } catch (_) {
        // If a remote move is malformed we just stop replay; the next
        // snapshot will retry from scratch.
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _state = s;
      _selected = null;
      _legalFromSelection = const [];
      _recomputeLoneKingFromHistory(s, moves);
    });
    _maybeEndGame();
  }

  /// In online games, writes the terminal result to the game document.
  /// The `finalizeGame` Cloud Function listens for this transition and
  /// updates both players' ELO + games-played counters.
  Future<void> _writeRemoteResult(GameResult r) async {
    final id = widget.args.onlineGameId;
    if (id == null) return;
    final code = switch (r) {
      GameResult.whiteWins => 'white',
      GameResult.blackWins => 'black',
      GameResult.draw      => 'draw',
    };
    try {
      await FirebaseFirestore.instance
          .collection('games')
          .doc(id)
          .update({'result': code});
    } catch (_) {
      // Non-fatal: the game-over UI still shows. Worst case the
      // finalizeGame trigger doesn't fire and ELO doesn't update.
    }
  }

  Future<void> _pushRemoteMove(Move m) async {
    final id = widget.args.onlineGameId!;
    final nextSide =
        _state.sideToMove == PieceColor.white ? 'black' : 'white';
    // Prefer the Cloud Function (server validation + atomic update). If
    // it's not deployed yet, FirebaseService falls back to a direct
    // arrayUnion so development on the Spark plan keeps working.
    await FirebaseService.instance.submitMoveOrDirect(
      gameId: id,
      moveJson: m.toJson(),
      nextSideToMove: nextSide,
    );
  }

  bool get _inCheck {
    if (!_engine.announcesCheck) return false;
    final classic = _engine as ClassicEngine?;
    return classic?.inCheck(_state, _state.sideToMove) ?? false;
  }

  /// Cached capture log for the current state. Replays history each call,
  /// which is fine for typical game lengths (<100 moves) on a phone.
  CaptureLog _captureLog() => deriveCaptures(_engine, _state);

  /// Apply a move via the engine and update the lone-king tracking. All
  /// move-application paths (human, AI, online replay, rematch) should go
  /// through this helper so the counter stays consistent.
  GameState _applyMoveWithRules(GameState before, Move move) {
    final mover = before.sideToMove;
    final after = _engine.applyMove(before, move);
    if (_loneKingRuleEnabled) {
      _updateLoneKingTracking(after, mover);
    }
    return after;
  }

  /// Re-derive lone-king state from the current board, then advance the
  /// counter if the player who just moved is the lone-king side.
  void _updateLoneKingTracking(GameState after, PieceColor mover) {
    final newSide = _detectLoneKing(after);
    if (newSide == null) {
      _loneKingSide = null;
      _loneKingMovesLeft = null;
      return;
    }
    if (_loneKingSide != newSide) {
      // Just transitioned into lone-king state for this side.
      _loneKingSide = newSide;
      _loneKingMovesLeft = _kLoneKingMoveBudget;
      return;
    }
    if (mover == newSide) {
      // The lone-king side just used one of their moves.
      _loneKingMovesLeft = (_loneKingMovesLeft ?? _kLoneKingMoveBudget) - 1;
      if (_loneKingMovesLeft! < 0) _loneKingMovesLeft = 0;
    }
  }

  /// Returns the color whose only remaining piece is its king, or null if
  /// neither (or both) sides are in that state.
  static PieceColor? _detectLoneKing(GameState s) {
    int w = 0, b = 0;
    s.board.pieces.forEach((_, p) {
      if (p.color == PieceColor.white) w++; else b++;
    });
    if (w == 1 && b > 1) return PieceColor.white;
    if (b == 1 && w > 1) return PieceColor.black;
    return null;
  }

  /// Reset the lone-king tracking from scratch by walking the current
  /// state's history. Used when a remote update lands and we don't know
  /// how many moves the lone king has burned.
  void _recomputeLoneKingFromHistory(GameState finalState, List<Move> moves) {
    _loneKingSide = null;
    _loneKingMovesLeft = null;
    if (!_loneKingRuleEnabled) return;
    GameState s = _engine.initialState();
    for (final m in moves) {
      final mover = s.sideToMove;
      s = _engine.applyMove(s, m);
      _updateLoneKingTracking(s, mover);
    }
  }

  void _onTap(Square s) {
    // Lock the board while the AI is computing its reply.
    if (_aiThinking) return;
    // In a vs-AI game it's never the human's turn when the AI is to move.
    if (_vsAi && _state.sideToMove == _aiColor) return;
    // Online: only the side whose turn it is may move, and only the local
    // user's color is controllable from this device.
    if (_isOnline && _state.sideToMove != _localColor) return;
    // If a piece of the side to move is tapped, select it.
    final piece = _state.board.at(s);
    if (_selected == null) {
      if (piece != null && piece.color == _state.sideToMove) {
        final all = _engine.legalMoves(_state);
        setState(() {
          _selected = s;
          _legalFromSelection = all.where((m) => m.from == s).toList();
        });
        SoundService.instance.piecePickedUp();
      }
      return;
    }
    // If the tapped square is a legal target, play the move.
    Move? chosen;
    for (final m in _legalFromSelection) {
      if (m.to == s) { chosen = m; break; }
    }
    if (chosen != null) {
      // If a promotion move was chosen, default to queen for v1 scaffold.
      // The production UI should show a picker.
      Move toPlay = chosen;
      if (chosen.promotion != null && chosen.promotion != PieceType.queen) {
        toPlay = Move(
          from: chosen.from, to: chosen.to,
          promotion: PieceType.queen,
          isCastleKingside: chosen.isCastleKingside,
          isCastleQueenside: chosen.isCastleQueenside,
          enPassantCapture: chosen.enPassantCapture,
          barbarianPassThrough: chosen.barbarianPassThrough,
        );
      }
      // Determine capture for SFX before we mutate state.
      final wasCapture = _state.board.at(toPlay.to) != null
          || toPlay.enPassantCapture
          || toPlay.barbarianPassThrough != null;
      setState(() {
        _state = _applyMoveWithRules(_state, toPlay);
        _selected = null;
        _legalFromSelection = const [];
      });
      SoundService.instance.moveLanded(isCapture: wasCapture);
      if (_isOnline) {
        // Don't await — let it fire and forget; the snapshot listener will
        // reconcile when Firestore confirms the write.
        _pushRemoteMove(toPlay);
      }
      _afterAnyMove();
      return;
    }
    // Otherwise deselect (or re-select another friendly piece).
    if (piece != null && piece.color == _state.sideToMove) {
      final all = _engine.legalMoves(_state);
      setState(() {
        _selected = s;
        _legalFromSelection = all.where((m) => m.from == s).toList();
      });
    } else {
      setState(() {
        _selected = null;
        _legalFromSelection = const [];
      });
    }
  }

  /// Called after any move (human OR AI) lands. Ends the game if terminal
  /// (classical rules OR the lone-king 21-move rule), otherwise schedules
  /// the AI's reply if it's the AI's turn.
  void _afterAnyMove() {
    // Classical termination (checkmate, stalemate, 50-move rule, variant
    // rules baked into the engine).
    if (_engine.terminal(_state) != null) {
      _maybeEndGame();
      return;
    }
    // Lone-king 21-move stalemate rule (handled outside the engine).
    if (_loneKingRuleEnabled &&
        _loneKingMovesLeft != null &&
        _loneKingMovesLeft! <= 0) {
      _maybeEndGame();
      return;
    }
    // Check sound: announce when the side to move just got put in check
    // (and the variant announces check at all).
    if (_inCheck) {
      SoundService.instance.check();
    }
    // Game continues — let the AI move if it's its turn.
    if (_vsAi && _state.sideToMove == _aiColor) {
      _scheduleAiMove();
    }
  }

  void _scheduleAiMove() {
    setState(() => _aiThinking = true);
    // Yield to the frame so the "X to move" text and lock state paint first,
    // then the actual search runs on a background isolate via compute().
    Future<void>.delayed(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      Move? move;
      try {
        move = await _ai.pickMove(_engine, _state, widget.args.aiDifficulty!);
      } catch (_) {
        move = null;
      }
      if (!mounted) return;
      if (move == null) {
        setState(() => _aiThinking = false);
        _maybeEndGame();
        return;
      }
      final aiCapture = _state.board.at(move!.to) != null
          || move.enPassantCapture
          || move.barbarianPassThrough != null;
      setState(() {
        _state = _applyMoveWithRules(_state, move!);
        _aiThinking = false;
      });
      SoundService.instance.moveLanded(isCapture: aiCapture);
      _afterAnyMove();
    });
  }

  void _maybeEndGame() {
    GameResult? result = _engine.terminal(_state);

    // Lone-king 21-move rule: if the lone-king side has used up their
    // move budget without being mated, the game is a draw.
    String? customMessage;
    if (result == null &&
        _loneKingRuleEnabled &&
        _loneKingMovesLeft != null &&
        _loneKingMovesLeft! <= 0) {
      result = GameResult.draw;
      customMessage = 'Draw — lone king survived $_kLoneKingMoveBudget moves.';
    }

    if (result == null) return;

    // For online games, write the terminal result to Firestore so the
    // finalizeGame Cloud Function fires and updates both players' ELO.
    if (_isOnline) {
      _writeRemoteResult(result);
    }

    SoundService.instance.gameOver();

    // Fire post-game interstitial (respects our frequency cap).
    AdMobService.instance.maybeShowPostGameInterstitial();

    final message = customMessage ?? switch (result) {
      GameResult.whiteWins => 'White wins',
      GameResult.blackWins => 'Black wins',
      GameResult.draw => 'Draw',
    };

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      // Position the dialog at the top of the screen so the user can still
      // see the final board position underneath while the dialog is open.
      builder: (_) => Dialog(
        alignment: Alignment.topCenter,
        insetPadding: const EdgeInsets.only(top: 80, left: 32, right: 32),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Game over',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Home',
                      style: TextStyle(
                        color: Color(0xFF1F3864),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _state = _engine.initialState();
                        _selected = null;
                        _legalFromSelection = const [];
                        _aiThinking = false;
                        _loneKingSide = null;
                        _loneKingMovesLeft = null;
                      });
                      _afterAnyMove();
                    },
                    child: const Text('Rematch'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          widget.args.variant.displayName,
          style: const TextStyle(
            color: Colors.white,
            shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          if (_vsAi)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Text(
                  'vs ${widget.args.aiDifficulty!.label}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Move history',
            icon: const Icon(Icons.history),
            onPressed: () {
              final notations = describeGame(_engine, _state);
              showMoveHistorySheet(context, notations);
            },
          ),
        ],
      ),
      body: ChessBackground(
        imageAsset: 'assets/white_piece_background.jpg',
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 4),
                    Text(
                      _aiThinking
                          ? 'Computer thinking…'
                          : '${_state.sideToMove == PieceColor.white ? "White" : "Black"} to move',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                      ),
                    ),
                    const Spacer(),
                    if (_loneKingMovesLeft != null)
                      _MovesLeftChip(
                        movesLeft: _loneKingMovesLeft!,
                        sideLabel: _loneKingSide == PieceColor.white
                            ? 'White'
                            : 'Black',
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
                const SizedBox(height: 12),
                // Always reserves space so the board doesn't shift when
                // check appears or resolves — only the card's visibility
                // toggles, not the column layout.
                Visibility(
                  visible: _inCheck,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: const _CheckCard(),
                ),
                const SizedBox(height: 12),
                // Strip ABOVE the board: pieces white has captured.
                // Black sits at the top of the board, so the pieces black
                // has lost (= pieces white captured) are shown on black's
                // own end — the "graveyard" convention.
                CapturedPiecesStrip(
                  capturingSide: PieceColor.white,
                  log: _captureLog(),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Center(
                    child: _BoardFrame(
                      child: BoardWidget(
                        board: _state.board,
                        lastMove: _state.history.isEmpty
                            ? null
                            : _state.history.last,
                        selected: _selected,
                        legalMovesFromSelection: _legalFromSelection,
                        onTap: _onTap,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // Strip BELOW the board: pieces black has captured.
                // White sits at the bottom, so white's lost pieces (=
                // pieces black captured) show on white's own end.
                CapturedPiecesStrip(
                  capturingSide: PieceColor.black,
                  log: _captureLog(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps the chess board in a wood-toned frame with a heavy drop shadow,
/// so the board reads as a physical object floating above the chess-photo
/// background rather than UI flush against the screen.
class _BoardFrame extends StatelessWidget {
  final Widget child;
  const _BoardFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        // Dark wood-toned frame.
        color: const Color(0xFF3E2723),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF1B0E08),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: child,
      ),
    );
  }
}

/// Tan rounded card with bold red "CHECK" text, shown above the board when
/// the side to move is in check.
class _CheckCard extends StatelessWidget {
  const _CheckCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE0C2), // tan, matches the light-square color
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Text(
        'CHECK',
        style: TextStyle(
          color: Color(0xFFD32F2F),
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
        ),
      ),
    );
  }
}

/// Pill-shaped chip showing how many moves the lone-king side has left
/// before the 21-move stalemate rule auto-draws the game. Only visible
/// while one side has just their king on the board.
class _MovesLeftChip extends StatelessWidget {
  final int movesLeft;
  final String sideLabel;
  const _MovesLeftChip({required this.movesLeft, required this.sideLabel});

  @override
  Widget build(BuildContext context) {
    // Color shifts from neutral → amber → red as the budget shrinks so
    // the player can feel urgency at a glance.
    final Color bg;
    if (movesLeft > 10) {
      bg = const Color(0xFFE0E0E0);
    } else if (movesLeft > 5) {
      bg = const Color(0xFFFFE0B2);
    } else {
      bg = const Color(0xFFFFCDD2);
    }
    // Always-dark text; doesn't get flipped by dark-mode theming.
    const textColor = Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF999999), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Moves Remaining: ',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          Text(
            '$movesLeft',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($sideLabel)',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
