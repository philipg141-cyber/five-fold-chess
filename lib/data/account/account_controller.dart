import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/user_profile.dart';
import '../firebase/firebase_service.dart';

/// Auth states the UI cares about.
enum AccountStatus { unknown, signedOut, signedIn }

/// Snapshot of the current account state.
class AccountState {
  final AccountStatus status;
  final UserProfile? profile;
  final String? error;

  const AccountState({
    required this.status,
    this.profile,
    this.error,
  });

  factory AccountState.unknown() => const AccountState(status: AccountStatus.unknown);
  factory AccountState.signedOut({String? error}) =>
      AccountState(status: AccountStatus.signedOut, error: error);
  factory AccountState.signedIn(UserProfile p) =>
      AccountState(status: AccountStatus.signedIn, profile: p);
}

/// Owns Firebase Auth + Firestore profile reads/writes.
///
/// Returns user-friendly error strings instead of throwing so the UI can
/// surface a snackbar / dialog without try/catch in widgets.
class AccountController extends StateNotifier<AccountState> {
  AccountController() : super(AccountState.unknown()) {
    _watch();
  }

  StreamSubscription<User?>? _authSub;

  void _watch() {
    // ensureInitialized() is called lazily on first auth-touching action.
    // We still need to subscribe to FirebaseAuth's user stream as soon as
    // possible so cold-launch shows the right state.
    Future<void>.microtask(() async {
      try {
        await FirebaseService.instance.ensureInitialized();
      } catch (e) {
        // ensureInitialized only fails if firebase_options.dart is
        // missing or refers to a project that no longer exists.
        state = AccountState.signedOut(
          error: 'Could not connect to Firebase. '
              'Check your internet connection and try again. '
              '(Error: $e)',
        );
        return;
      }
      _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuth);
    });
  }

  Future<void> _onAuth(User? u) async {
    if (u == null) {
      state = AccountState.signedOut();
      return;
    }
    final profile = await _loadOrCreateProfile(u);
    state = AccountState.signedIn(profile);
  }

  Future<UserProfile> _loadOrCreateProfile(User u) async {
    final ref = FirebaseFirestore.instance.collection('users').doc(u.uid);
    final snap = await ref.get();
    if (snap.exists && snap.data() != null) {
      return UserProfile.fromJson(snap.data()!);
    }
    // Auto-create on first sign-in.
    final fallbackName = u.email?.split('@').first ?? 'Player_${u.uid.substring(0, 6)}';
    final profile = UserProfile(
      uid: u.uid,
      username: u.displayName ?? fallbackName,
      email: u.email ?? '',
      createdAt: DateTime.now(),
    );
    await ref.set(profile.toJson());
    return profile;
  }

  Future<String?> signUpEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      await FirebaseService.instance.ensureInitialized();
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      await cred.user?.updateDisplayName(username);
      // _onAuth will fire and create the Firestore profile.
      return null;
    } on FirebaseAuthException catch (e) {
      return _humanize(e);
    } catch (e) {
      return 'Could not sign up. ($e)';
    }
  }

  Future<String?> signInEmail({
    required String email,
    required String password,
  }) async {
    try {
      await FirebaseService.instance.ensureInitialized();
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _humanize(e);
    } catch (e) {
      return 'Could not sign in. ($e)';
    }
  }

  Future<String?> signInAnonymously() async {
    try {
      await FirebaseService.instance.ensureInitialized();
      await FirebaseAuth.instance.signInAnonymously();
      return null;
    } on FirebaseAuthException catch (e) {
      // The most common failure here is that Anonymous sign-in hasn't been
      // enabled for the project. Spell it out so the fix is one click away.
      if (e.code == 'admin-restricted-operation' ||
          e.message?.contains('CONFIGURATION_NOT_FOUND') == true) {
        return 'Anonymous sign-in is disabled for this Firebase project. '
            'Enable it in the Firebase Console: '
            'Authentication → Sign-in method → Anonymous → Enable.';
      }
      return _humanize(e);
    } catch (e) {
      return 'Could not sign in as guest. ($e)';
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    try {
      await FirebaseService.instance.ensureInitialized();
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _humanize(e);
    } catch (e) {
      return 'Could not send reset email. ($e)';
    }
  }

  Future<void> signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      // even if Firebase isn't initialized, force-clear local state
      state = AccountState.signedOut();
    }
  }

  Future<String?> updateUsername(String newUsername) async {
    final p = state.profile;
    if (p == null) return 'Not signed in';
    try {
      final updated = p.copyWith(username: newUsername);
      await FirebaseFirestore.instance
          .collection('users').doc(p.uid)
          .update({'username': newUsername});
      state = AccountState.signedIn(updated);
      return null;
    } catch (e) {
      return 'Could not update username. ($e)';
    }
  }

  String _humanize(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':         return 'That email address looks invalid.';
      case 'user-disabled':         return 'This account has been disabled.';
      case 'user-not-found':        return 'No account found for that email.';
      case 'wrong-password':        return 'Wrong password.';
      case 'email-already-in-use':  return 'An account already exists for that email.';
      case 'weak-password':         return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed': return 'Network error. Check your connection.';
      default:                      return e.message ?? 'Authentication error (${e.code}).';
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

/// Riverpod provider exposing the current [AccountState] to the UI.
final accountProvider =
    StateNotifierProvider<AccountController, AccountState>((ref) {
  return AccountController();
});
