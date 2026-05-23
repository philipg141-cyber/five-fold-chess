import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/account/account_controller.dart';
import '../../data/online/matchmaking_service.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/chess_background.dart';
import 'account_screen.dart';
import 'game_screen.dart';
import 'onboarding_screen.dart';
import 'online_lobby_screen.dart';
import 'settings_screen.dart';
import 'variant_picker_screen.dart';

class HomeScreen extends ConsumerWidget {
  static const route = '/';
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    final signedIn = account.status == AccountStatus.signedIn;
    final username = account.profile?.username;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Fivefold Chess',
          style: GoogleFonts.cinzel(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            shadows: const [
              Shadow(color: Colors.black54, blurRadius: 6),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: signedIn ? 'Account ($username)' : 'Sign in',
            icon: Icon(signedIn ? Icons.person : Icons.person_outline),
            onPressed: () =>
                Navigator.pushNamed(context, AccountScreen.route),
          ),
        ],
      ),
      body: ChessBackground(
        imageAsset: 'assets/white_piece_background.jpg',
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Image.asset(
                    'assets/fivefold_chess_logo.png',
                    fit: BoxFit.contain,
                    height: 130,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Five ways to play',
                textAlign: TextAlign.center,
                style: GoogleFonts.cinzel(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Three primary play options as cards.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _PlayCard(
                      icon: Icons.smart_toy_outlined,
                      title: 'Play vs Computer',
                      subtitle: 'Match wits with the engine',
                      onTap: () => Navigator.pushNamed(
                        context,
                        VariantPickerScreen.route,
                        arguments: const VariantPickerArgs(
                            mode: PlayMode.vsComputer),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _PlayCard(
                      icon: Icons.people_outline,
                      title: 'Pass & Play',
                      subtitle: 'Hand the phone back and forth',
                      onTap: () => Navigator.pushNamed(
                        context,
                        VariantPickerScreen.route,
                        arguments: const VariantPickerArgs(
                            mode: PlayMode.passAndPlay),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _PlayCard(
                      icon: Icons.public,
                      title: 'Play Online',
                      subtitle: 'Find a real opponent',
                      onTap: () async {
                        final match = await Navigator.pushNamed(
                          context,
                          OnlineLobbyScreen.route,
                        );
                        if (match is MatchedGame && context.mounted) {
                          Navigator.pushNamed(
                            context,
                            GameScreen.route,
                            arguments: GameScreenArgs(
                              variant: match.variant,
                              onlineGameId: match.gameId,
                              localPlaysWhite: match.localPlaysWhite,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 1),
              // Utility row — quieter, secondary actions.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _UtilButton(
                      icon: Icons.school_outlined,
                      label: 'How to Play',
                      onTap: () => Navigator.pushNamed(
                          context, OnboardingScreen.route),
                    ),
                    _UtilButton(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () => Navigator.pushNamed(
                          context, SettingsScreen.route),
                    ),
                    if (!signedIn)
                      _UtilButton(
                        icon: Icons.person_add_outlined,
                        label: 'Sign Up',
                        onTap: () => Navigator.pushNamed(
                          context,
                          AccountScreen.route,
                          arguments: AccountScreenMode.signUp,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Center(child: AdBanner()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Primary action card on the home screen — translucent white background,
/// icon in a navy circle on the left, Cinzel title, Inter subtitle, chevron
/// on the right. Three of these are stacked vertically for the play modes.
class _PlayCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _PlayCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.94),
      borderRadius: BorderRadius.circular(14),
      elevation: 4,
      shadowColor: Colors.black54,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF1F3864),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cinzel(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: Colors.black54,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Color(0xFF1F3864),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact utility-row button — icon on top, small label underneath, a
/// translucent outline so the chess-photo background still shows through.
/// Used for secondary actions: How to Play, Settings, Sign Up.
class _UtilButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _UtilButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.10),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 0.6,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
