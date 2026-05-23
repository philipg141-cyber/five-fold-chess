import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';

import '../../domain/models/variant.dart';
import '../widgets/chess_background.dart';
import 'home_screen.dart';

/// First-launch walkthrough. Shows once per install: cycles through the
/// five variants, each with a glyph, tagline, and a paragraph
/// explaining the rule twist that makes that variant unique.
///
/// Sets the `onboarding_done` flag in the Hive `app` box on completion
/// (or skip), so subsequent launches go straight to the home screen.
class OnboardingScreen extends StatefulWidget {
  static const route = '/onboarding';
  const OnboardingScreen({super.key});

  /// Called by app.dart to decide whether the first frame should show
  /// onboarding or the home screen.
  static bool shouldShow() {
    final box = Hive.box<dynamic>('app');
    return !(box.get('onboarding_done', defaultValue: false) as bool);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await Hive.box<dynamic>('app').put('onboarding_done', true);
    if (!mounted) return;
    final nav = Navigator.of(context);
    // If we got here from somewhere (e.g. the home screen's How to Play
    // button), pop back to that. On first launch the onboarding screen
    // is the root, so push-replacement to home instead.
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacementNamed(HomeScreen.route);
    }
  }

  void _next() {
    _ctl.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    _ctl.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    const variants = Variant.values;
    final isLast = _page == variants.length - 1;

    return Scaffold(
      body: ChessBackground(
        imageAsset: 'assets/black_piece_background.jpg',
        // Slightly heavier overlay than the menu screens so body text in
        // the description card remains the visual focus.
        topAlpha: 0.65,
        bottomAlpha: 0.92,
        child: SafeArea(
          child: Column(
            children: [
              // Skip button (top-right). Skipping sets the same flag so
              // the user isn't re-shown the walkthrough next launch.
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4),
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _ctl,
                  itemCount: variants.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) =>
                      _VariantPage(variant: variants[i]),
                ),
              ),
              // Page indicator dots
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < variants.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _page ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: i == _page
                              ? Colors.white
                              : Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
              // Nav buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Row(
                  children: [
                    TextButton(
                      onPressed: _page > 0 ? _back : null,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        disabledForegroundColor: Colors.white24,
                      ),
                      child: const Text('Back'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: isLast ? _finish : _next,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 28),
                        child: Text(
                          isLast ? 'Get Started' : 'Next',
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single page of the walkthrough — one variant per page.
class _VariantPage extends StatelessWidget {
  final Variant variant;
  const _VariantPage({required this.variant});

  String get _glyph {
    switch (variant) {
      case Variant.classic:   return '♔';
      case Variant.long:      return '♖';
      case Variant.silent:    return '♗';
      case Variant.reverse:   return '♙';
      case Variant.barbarian: return '♕';
    }
  }

  Color get _accent {
    switch (variant) {
      case Variant.classic:   return const Color(0xFFFFF8E1);
      case Variant.long:      return const Color(0xFFE8F5E9);
      case Variant.silent:    return const Color(0xFFE3F2FD);
      case Variant.reverse:   return const Color(0xFFFCE4EC);
      case Variant.barbarian: return const Color(0xFFE1BEE7);
    }
  }

  String get _description {
    switch (variant) {
      case Variant.classic:
        return "The timeless game. Capture the king, force checkmate, win.\n\n"
               "All standard FIDE rules apply: pawns promote on the back "
               "rank, kings castle, en passant captures, fifty-move draws. "
               "If you've ever played chess, you already know how this one "
               "works — Stockfish powers the AI here, so even Grand Master "
               "is genuinely tough.";
      case Variant.long:
        return "Same pieces, same rules — but the board is twice as tall.\n\n"
               "Sixteen ranks of empty space sit between the two armies. "
               "Memorised opening theory goes out the window and pawns "
               "become essential travelers. A real test of strategy "
               "without the comfort of a familiar starting position.";
      case Variant.silent:
        return "Standard FIDE rules — but the board never warns you.\n\n"
               "No 'CHECK' alert, no visual cue when your king is under "
               "attack. You have to spot threats yourself. The engine "
               "still enforces legality, so you can't blunder your king "
               "into capture, but the moment of insight is on you.";
      case Variant.reverse:
        return "Antichess. Lose all your pieces and you win.\n\n"
               "Captures are forced — if you can take, you must. Even your "
               "king is a regular piece with no special protection, and "
               "pawns can promote to a king if you'd like one back. "
               "Simple, deep, and weirdly addictive.";
      case Variant.barbarian:
        return "Bishops, rooks, and queens get a special move:\n"
               "charge through any one piece (yours or the enemy's) "
               "to capture another piece beyond it.\n\n"
               "Both pieces are removed; your slider lands on the target. "
               "Pawns, knights, and kings don't get this — only sliding "
               "pieces. Opens up wild tactical possibilities.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          // Hero glyph in accent-coloured circle.
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: _accent,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: Text(
                _glyph,
                style: const TextStyle(
                  fontSize: 86,
                  color: Colors.black,
                  height: 1.0,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Title — Cinzel, white, shadowed.
          Text(
            variant.displayName,
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 8),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Tagline — Inter italic, semi-transparent white.
          Text(
            variant.tagline,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              fontStyle: FontStyle.italic,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 20),
          // Description in a translucent white card so body text stays
          // legible against the busy chess-photo background.
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.94),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 10),
              ],
            ),
            child: Text(
              _description,
              textAlign: TextAlign.left,
              style: GoogleFonts.inter(
                color: Colors.black87,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
