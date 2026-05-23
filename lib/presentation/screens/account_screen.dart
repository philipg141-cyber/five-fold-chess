import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/account/account_controller.dart';
import '../../domain/models/user_profile.dart';
import '../widgets/chess_background.dart';

/// Optional argument controlling which form the account screen opens on.
/// Pass [AccountScreenMode.signUp] from a "Create account" entry point so
/// the user lands directly on the sign-up form.
enum AccountScreenMode { signIn, signUp }

class AccountScreen extends ConsumerWidget {
  static const route = '/account';
  final AccountScreenMode initialMode;

  const AccountScreen({super.key, this.initialMode = AccountScreenMode.signIn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountProvider);

    Widget body;
    switch (state.status) {
      case AccountStatus.unknown:
        body = const Center(child: CircularProgressIndicator());
        break;
      case AccountStatus.signedOut:
        body = _AuthForm(error: state.error, initialMode: initialMode);
        break;
      case AccountStatus.signedIn:
        body = _ProfileView(profile: state.profile!);
        break;
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: ChessBackground(
        imageAsset: 'assets/white_piece_background.jpg',
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            // The form/profile widgets inside expect a light surface
            // (Material text fields, dividers, etc). Wrap them in an
            // opaque white card so they stay legible on top of the
            // navy-tinted chess-photo background.
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 4,
              shadowColor: Colors.black54,
              clipBehavior: Clip.antiAlias,
              child: body,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- Sign-in / sign-up form ----------------------------------

class _AuthForm extends ConsumerStatefulWidget {
  final String? error;
  final AccountScreenMode initialMode;
  const _AuthForm({this.error, this.initialMode = AccountScreenMode.signIn});

  @override
  ConsumerState<_AuthForm> createState() => _AuthFormState();
}

enum _Mode { signIn, signUp }

class _AuthFormState extends ConsumerState<_AuthForm> {
  late _Mode _mode = widget.initialMode == AccountScreenMode.signUp
      ? _Mode.signUp
      : _Mode.signIn;
  final _emailCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _userCtl = TextEditingController();
  bool _busy = false;
  String? _localError;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passCtl.dispose();
    _userCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() { _busy = true; _localError = null; });
    final ctl = ref.read(accountProvider.notifier);
    String? err;
    if (_mode == _Mode.signIn) {
      err = await ctl.signInEmail(
        email: _emailCtl.text.trim(),
        password: _passCtl.text,
      );
    } else {
      err = await ctl.signUpEmail(
        email: _emailCtl.text.trim(),
        password: _passCtl.text,
        username: _userCtl.text.trim(),
      );
    }
    if (!mounted) return;
    setState(() { _busy = false; _localError = err; });
  }

  Future<void> _continueAsGuest() async {
    setState(() { _busy = true; _localError = null; });
    final err = await ref.read(accountProvider.notifier).signInAnonymously();
    if (!mounted) return;
    setState(() { _busy = false; _localError = err; });
  }

  Future<void> _resetPassword() async {
    if (_emailCtl.text.trim().isEmpty) {
      setState(() => _localError = 'Enter your email first to reset.');
      return;
    }
    final err = await ref.read(accountProvider.notifier)
        .sendPasswordReset(_emailCtl.text.trim());
    if (!mounted) return;
    setState(() => _localError = err ?? 'Password reset email sent.');
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _mode == _Mode.signUp;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isSignUp ? 'Create your account' : 'Sign in to your account',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: const Color(0xFF1F3864),
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (isSignUp)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _userCtl,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
            ),
          TextField(
            controller: _emailCtl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passCtl,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          const SizedBox(height: 16),
          if (widget.error != null || _localError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _localError ?? widget.error!,
                style: const TextStyle(color: Color(0xFFD32F2F)),
                textAlign: TextAlign.center,
              ),
            ),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                _busy ? '...' : (isSignUp ? 'Create account' : 'Sign in'),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!isSignUp)
            TextButton(
              onPressed: _busy ? null : _resetPassword,
              child: const Text('Forgot password?'),
            ),
          TextButton(
            onPressed: _busy ? null : () => setState(() {
              _mode = isSignUp ? _Mode.signIn : _Mode.signUp;
              _localError = null;
            }),
            child: Text(isSignUp
                ? 'Have an account? Sign in'
                : 'New here? Create an account'),
          ),
          const Divider(height: 32),
          OutlinedButton(
            onPressed: _busy ? null : _continueAsGuest,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Continue as guest'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Profile view ---------------------------------------------

class _ProfileView extends ConsumerStatefulWidget {
  final UserProfile profile;
  const _ProfileView({required this.profile});

  @override
  ConsumerState<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<_ProfileView> {
  late final TextEditingController _nameCtl =
      TextEditingController(text: widget.profile.username);
  bool _editing = false;
  String? _msg;

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
    final newName = _nameCtl.text.trim();
    if (newName.isEmpty) return;
    final err = await ref.read(accountProvider.notifier).updateUsername(newName);
    if (!mounted) return;
    setState(() {
      _editing = false;
      _msg = err ?? 'Username updated.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 8),
        const Center(
          child: CircleAvatar(
            radius: 40,
            child: Icon(Icons.person, size: 40),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: _editing
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nameCtl,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: _saveUsername,
                      ),
                    ],
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      p.username,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: const Color(0xFF1F3864),
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: () => setState(() => _editing = true),
                    ),
                  ],
                ),
        ),
        if (p.email.isNotEmpty)
          Center(child: Text(p.email,
              style: TextStyle(color: Colors.grey.shade600))),
        if (_msg != null) ...[
          const SizedBox(height: 8),
          Center(child: Text(_msg!,
              style: const TextStyle(color: Colors.green))),
        ],
        const SizedBox(height: 24),
        const Divider(),
        const ListTile(
          dense: true,
          title: Text('Ratings', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        _eloRow('Classic',  p.eloClassic),
        _eloRow('Long',     p.eloLong),
        _eloRow('Silent',   p.eloSilent),
        _eloRow('Reverse',  p.eloReverse),
        _eloRow('Barbarian', p.eloBarbarian),
        const Divider(),
        ListTile(
          title: const Text('Games played'),
          trailing: Text('${p.gamesPlayed}'),
        ),
        ListTile(
          title: const Text('Member since'),
          trailing: Text(_fmtDate(p.createdAt)),
        ),
        const SizedBox(height: 32),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(accountProvider.notifier).signOut();
            if (mounted) Navigator.of(context).pop();
          },
          icon: const Icon(Icons.logout),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text('Sign out'),
          ),
        ),
      ],
    );
  }

  Widget _eloRow(String label, int rating) => ListTile(
    dense: true,
    title: Text(label),
    trailing: Text('$rating', style: const TextStyle(fontFamily: 'monospace')),
  );

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
