/// The five game modes supported by Fivefold Chess.
///
/// Each variant maps one-to-one to a concrete [RuleEngine] implementation
/// in the `engines/` folder.
enum Variant {
  classic,
  long,
  silent,
  reverse,
  barbarian;

  String get displayName {
    switch (this) {
      case Variant.classic: return 'Classic Chess';
      case Variant.long:    return 'Long Chess';
      case Variant.silent:  return 'Silent Chess';
      case Variant.reverse: return 'Reverse Chess';
      case Variant.barbarian: return 'Barbarian Chess';
    }
  }

  String get tagline {
    switch (this) {
      case Variant.classic:
        return 'Standard FIDE rules — the timeless game.';
      case Variant.long:
        return '8×16 board. Armies on each end, empty middle.';
      case Variant.silent:
        return 'No check warnings — spot the threat yourself.';
      case Variant.reverse:
        return 'Lose every piece to win. Captures are forced.';
      case Variant.barbarian:
        return 'Bishops, rooks & queens crash through a piece to strike another.';
    }
  }
}
