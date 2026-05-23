/// Difficulty levels for the single-player computer opponent.
///
/// The numeric value of each level is reused by [AiService] as a search-depth
/// proxy and (for Classic Chess) as a Stockfish "Skill Level" UCI option.
enum AiDifficulty {
  beginner,
  intermediate,
  expert,
  grandMaster,
}

extension AiDifficultyX on AiDifficulty {
  /// Human-readable label shown in the difficulty picker.
  String get label {
    switch (this) {
      case AiDifficulty.beginner:    return 'Beginner';
      case AiDifficulty.intermediate: return 'Intermediate';
      case AiDifficulty.expert:      return 'Expert';
      case AiDifficulty.grandMaster: return 'Grand Master';
    }
  }

  /// One-line description of the level's playing strength.
  String get tagline {
    switch (this) {
      case AiDifficulty.beginner:
        return 'Plays casually, makes mistakes. Good for learning.';
      case AiDifficulty.intermediate:
        return 'Looks a couple moves ahead. Solid club-level play.';
      case AiDifficulty.expert:
        return 'Strong tactical play. Will punish blunders.';
      case AiDifficulty.grandMaster:
        return 'Maximum engine strength. A serious challenge.';
    }
  }

  /// Search depth used by the variant minimax.
  int get variantDepth {
    switch (this) {
      case AiDifficulty.beginner:    return 1;
      case AiDifficulty.intermediate: return 2;
      case AiDifficulty.expert:      return 3;
      case AiDifficulty.grandMaster: return 4;
    }
  }

  /// Probability (0.0–1.0) that the AI deliberately picks a non-best move
  /// to feel more human at lower difficulties.
  double get blunderRate {
    switch (this) {
      case AiDifficulty.beginner:    return 0.30;
      case AiDifficulty.intermediate: return 0.10;
      case AiDifficulty.expert:      return 0.02;
      case AiDifficulty.grandMaster: return 0.00;
    }
  }

  /// Stockfish "Skill Level" UCI option value (0..20).
  /// Used only by Classic Chess; variants don't run Stockfish.
  int get stockfishSkill {
    switch (this) {
      case AiDifficulty.beginner:    return 3;
      case AiDifficulty.intermediate: return 8;
      case AiDifficulty.expert:      return 14;
      case AiDifficulty.grandMaster: return 20;
    }
  }
}
