import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/models/variant.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/chess_background.dart';
import '../widgets/difficulty_picker.dart';
import 'game_screen.dart';

/// What kind of game to start once a variant is picked.
enum PlayMode { vsComputer, passAndPlay }

class VariantPickerArgs {
  final PlayMode mode;
  const VariantPickerArgs({required this.mode});
}

class VariantPickerScreen extends StatelessWidget {
  static const route = '/variants';
  final VariantPickerArgs args;

  const VariantPickerScreen({
    super.key,
    this.args = const VariantPickerArgs(mode: PlayMode.passAndPlay),
  });

  @override
  Widget build(BuildContext context) {
    final modeLabel = args.mode == PlayMode.vsComputer
        ? 'vs Computer'
        : 'Pass & Play';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Select Game Variant'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ChessBackground(
        imageAsset: 'assets/black_piece_background.jpg',
        child: SafeArea(
          child: Column(
            children: [
              // Mode subtitle on its own line — keeps the AppBar title
              // short enough to never wrap or truncate.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 0.6,
                      ),
                    ),
                    child: Text(
                      modeLabel,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: Variant.values.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final v = Variant.values[i];
                    return _VariantCard(
                      variant: v,
                      onTap: () => _onPick(context, v),
                    );
                  },
                ),
              ),
              const Center(child: AdBanner()),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onPick(BuildContext context, Variant v) async {
    if (args.mode == PlayMode.vsComputer) {
      final difficulty = await showDifficultyPicker(context);
      if (difficulty == null || !context.mounted) return;
      Navigator.pushNamed(
        context,
        GameScreen.route,
        arguments: GameScreenArgs(variant: v, aiDifficulty: difficulty),
      );
    } else {
      Navigator.pushNamed(
        context,
        GameScreen.route,
        arguments: GameScreenArgs(variant: v),
      );
    }
  }
}

class _VariantCard extends StatelessWidget {
  final Variant variant;
  final VoidCallback onTap;
  const _VariantCard({required this.variant, required this.onTap});

  /// One distinct chess glyph per variant. Picked for thematic resonance:
  /// king for the standard game, rook for the long board, bishop for the
  /// silent assassin, pawn for the antichess underdog, queen for the
  /// piece that gets the most use out of Barbarian pass-throughs.
  String get _glyph {
    switch (variant) {
      case Variant.classic:   return '♔';
      case Variant.long:      return '♖';
      case Variant.silent:    return '♗';
      case Variant.reverse:   return '♙';
      case Variant.barbarian: return '♕';
    }
  }

  /// Soft accent colour per variant — adds subtle visual differentiation
  /// while staying legible against the dark navy overlay.
  Color get _accent {
    switch (variant) {
      case Variant.classic:   return const Color(0xFFFFF8E1); // warm cream
      case Variant.long:      return const Color(0xFFE8F5E9); // mint
      case Variant.silent:    return const Color(0xFFE3F2FD); // pale blue
      case Variant.reverse:   return const Color(0xFFFCE4EC); // rose
      case Variant.barbarian: return const Color(0xFFE1BEE7); // lavender — wild, regal, distinct from rose
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _accent,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      shadowColor: Colors.black54,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  _glyph,
                  style: const TextStyle(
                    fontSize: 32,
                    color: Colors.black,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      variant.displayName,
                      style: GoogleFonts.cinzel(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      variant.tagline,
                      style: GoogleFonts.inter(
                        color: Colors.black87,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
