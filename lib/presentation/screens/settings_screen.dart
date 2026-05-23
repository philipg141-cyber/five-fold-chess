import 'package:flutter/material.dart';

import '../../data/sounds/sound_service.dart';
import '../widgets/chess_background.dart';

class SettingsScreen extends StatefulWidget {
  static const route = '/settings';
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late bool _muted = SoundService.instance.muted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ChessBackground(
        imageAsset: 'assets/black_piece_background.jpg',
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              _SettingsCard(
                children: [
                  const _SettingsTile(
                    icon: Icons.palette_outlined,
                    title: 'Board theme',
                    subtitle: 'Coming in v1.0 — wood, marble, neon',
                  ),
                  const _CardDivider(),
                  _SoundTile(
                    muted: _muted,
                    onChanged: (on) async {
                      await SoundService.instance.setMuted(!on);
                      if (!mounted) return;
                      setState(() => _muted = !on);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsCard(
                children: const [
                  _SettingsTile(
                    icon: Icons.account_circle_outlined,
                    title: 'Account',
                    subtitle: 'Sign in to sync saved games (online MP)',
                  ),
                  _CardDivider(),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy & data',
                    subtitle: 'Ad preferences, consent, data export',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Translucent white card that groups related settings rows. Sits cleanly
/// over the chess-photo background.
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.92),
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      shadowColor: Colors.black54,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();
  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 0.5,
      indent: 56,
      color: Color(0x33000000),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: Colors.black54),
      ),
      onTap: onTap,
    );
  }
}

class _SoundTile extends StatelessWidget {
  final bool muted;
  final ValueChanged<bool> onChanged;
  const _SoundTile({required this.muted, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(
        muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
        color: Colors.black87,
      ),
      title: const Text(
        'Sound effects',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        muted
            ? 'Off — chess plays in silence'
            : 'On — clicks, captures, check, game-over',
        style: const TextStyle(color: Colors.black54),
      ),
      value: !muted,
      onChanged: onChanged,
    );
  }
}
