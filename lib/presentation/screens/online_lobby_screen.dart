import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/account/account_controller.dart';
import '../../data/online/matchmaking_service.dart';
import '../../domain/models/variant.dart';
import '../widgets/chess_background.dart';
import 'account_screen.dart';

/// Lets a signed-in user pick a variant and join the matchmaking queue.
/// Shows a "waiting for opponent" state until paired, then pops with the
/// matched [MatchedGame] for the caller to navigate into a game screen.
class OnlineLobbyScreen extends ConsumerStatefulWidget {
  static const route = '/online';
  const OnlineLobbyScreen({super.key});

  @override
  ConsumerState<OnlineLobbyScreen> createState() => _OnlineLobbyScreenState();
}

class _OnlineLobbyScreenState extends ConsumerState<OnlineLobbyScreen> {
  Variant? _waitingFor;
  String? _error;

  Future<void> _join(Variant v) async {
    final account = ref.read(accountProvider);
    if (account.status != AccountStatus.signedIn) {
      Navigator.of(context).pushNamed(AccountScreen.route);
      return;
    }
    final profile = account.profile!;
    setState(() { _waitingFor = v; _error = null; });
    try {
      final match = await MatchmakingService.instance.joinQueue(
        uid: profile.uid,
        username: profile.username,
        variant: v,
      );
      if (!mounted) return;
      Navigator.of(context).pop(match);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _waitingFor = null;
        _error = 'Could not join queue: $e';
      });
    }
  }

  Future<void> _cancel() async {
    final account = ref.read(accountProvider);
    final waiting = _waitingFor;
    if (account.profile != null && waiting != null) {
      await MatchmakingService.instance.leaveQueue(
        uid: account.profile!.uid,
        variant: waiting,
      );
    }
    if (!mounted) return;
    setState(() { _waitingFor = null; });
  }

  // ---- View builders ----

  Widget _signedOutView(AccountState account) {
    return _CenteredCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sign in to play online',
            style: GoogleFonts.cinzel(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'You need an account to join the matchmaking queue.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black87),
          ),
          if (account.error != null) ...[
            const SizedBox(height: 12),
            Text(
              account.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFD32F2F)),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pushNamed(
              AccountScreen.route,
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              child: Text('Go to account'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitingView() {
    return _CenteredCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'Finding an opponent',
            style: GoogleFonts.cinzel(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Waiting in ${_waitingFor!.displayName}…',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black87, fontSize: 14),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: _cancel,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10, horizontal: 22),
              child: Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _variantList() {
    return Column(
      children: [
        if (_error != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _error!,
              style: const TextStyle(color: Color(0xFFD32F2F)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                'Pick a variant — we\'ll match you with another player',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
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
              return _OnlineVariantCard(
                variant: v,
                onTap: () => _join(v),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);

    Widget body;
    String title;
    if (account.status == AccountStatus.unknown) {
      body = const Center(child: CircularProgressIndicator());
      title = 'Play online';
    } else if (account.status == AccountStatus.signedOut) {
      body = _signedOutView(account);
      title = 'Play online';
    } else if (_waitingFor != null) {
      body = _waitingView();
      title = 'Finding opponent…';
    } else {
      body = _variantList();
      title = 'Play online';
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ChessBackground(
        imageAsset: 'assets/black_piece_background.jpg',
        child: SafeArea(child: body),
      ),
    );
  }
}

/// Translucent white card used for the signed-out and waiting states.
class _CenteredCard extends StatelessWidget {
  final Widget child;
  const _CenteredCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            elevation: 4,
            shadowColor: Colors.black54,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact variant card matching the offline picker's visual treatment.
class _OnlineVariantCard extends StatelessWidget {
  final Variant variant;
  final VoidCallback onTap;
  const _OnlineVariantCard({required this.variant, required this.onTap});

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
                Icons.public,
                color: Colors.black54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
