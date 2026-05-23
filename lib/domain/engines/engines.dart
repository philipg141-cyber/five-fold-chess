import '../models/variant.dart';
import 'barbarian_engine.dart';
import 'classic_engine.dart';
import 'long_engine.dart';
import 'reverse_engine.dart';
import 'rule_engine.dart';
import 'silent_engine.dart';

/// Factory that returns the correct rule engine for a variant.
RuleEngine engineFor(Variant v) {
  switch (v) {
    case Variant.classic:   return ClassicEngine();
    case Variant.long:      return LongEngine();
    case Variant.silent:    return SilentEngine();
    case Variant.reverse:   return ReverseEngine();
    case Variant.barbarian: return BarbarianEngine();
  }
}
