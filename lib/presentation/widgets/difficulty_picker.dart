import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/ai/ai_difficulty.dart';

/// Modal bottom sheet asking the user to pick an AI difficulty level.
/// Returns the chosen [AiDifficulty], or null if dismissed.
///
/// Each difficulty is rendered as a tappable card with an escalating
/// chess-piece icon (pawn → knight → rook → king for Beginner →
/// Grand Master), the level name in Cinzel, and the tagline in Inter.
Future<AiDifficulty?> showDifficultyPicker(BuildContext context) {
  return showModalBottomSheet<AiDifficulty>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
    builder: (ctx) => const _DifficultySheet(),
  );
}

class _DifficultySheet extends StatelessWidget {
  const _DifficultySheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Choose your opponent',
              style: GoogleFonts.cinzel(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            for (final d in AiDifficulty.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DifficultyCard(difficulty: d),
              ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF1F3864)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final AiDifficulty difficulty;
  const _DifficultyCard({required this.difficulty});

  /// Glyph that escalates with strength: a pawn is the cannon-fodder
  /// Beginner; the king is the heavyweight Grand Master.
  String get _glyph {
    switch (difficulty) {
      case AiDifficulty.beginner:    return '♟';
      case AiDifficulty.intermediate: return '♞';
      case AiDifficulty.expert:      return '♜';
      case AiDifficulty.grandMaster: return '♚';
    }
  }

  /// Tonal accent — subtle on Beginner, fierce on Grand Master.
  Color get _accentColor {
    switch (difficulty) {
      case AiDifficulty.beginner:    return const Color(0xFFE8F5E9); // mint
      case AiDifficulty.intermediate: return const Color(0xFFE3F2FD); // light blue
      case AiDifficulty.expert:      return const Color(0xFFFFF3E0); // amber
      case AiDifficulty.grandMaster: return const Color(0xFFFFEBEE); // crimson
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _accentColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).pop(difficulty),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  _glyph,
                  style: const TextStyle(
                    fontSize: 36,
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
                  children: [
                    Text(
                      difficulty.label,
                      style: GoogleFonts.cinzel(
                        color: Colors.black,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      difficulty.tagline,
                      style: GoogleFonts.inter(
                        color: Colors.black87,
                        fontSize: 12.5,
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
