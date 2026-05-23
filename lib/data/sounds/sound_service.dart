import 'dart:developer' as dev;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

/// Plays chess SFX and triggers haptic feedback.
///
/// Each SFX uses its own AudioPlayer instance (with PlayerMode.lowLatency)
/// so quick successive sounds — like several captures in a row — don't
/// step on each other. Sounds are bundled at assets/sounds/{name}.mp3.
///
/// Mute state persists across app launches via the existing Hive 'app' box.
class SoundService {
  SoundService._();
  static final instance = SoundService._();

  Box<dynamic> get _box => Hive.box<dynamic>('app');

  bool get muted =>
      _box.get('sounds_muted', defaultValue: false) as bool;

  Future<void> setMuted(bool value) async {
    await _box.put('sounds_muted', value);
  }

  // One AudioPlayer per SFX so they can overlap.
  final _players = <_Sfx, AudioPlayer>{};

  /// Pre-create the AudioPlayers; not strictly required (the first play
  /// would create them lazily) but it shaves a tiny stutter off the first
  /// click of a session.
  Future<void> init() async {
    for (final s in _Sfx.values) {
      try {
        final p = AudioPlayer()
          ..setReleaseMode(ReleaseMode.stop)
          ..setPlayerMode(PlayerMode.lowLatency);
        // Pre-warm by setting the source. Don't actually play.
        await p.setSource(AssetSource(s.assetPath));
        _players[s] = p;
      } catch (e) {
        dev.log('Failed to preload ${s.name}: $e', name: 'sounds');
      }
    }
  }

  // ---------------- public hooks the game screen calls ----------------

  Future<void> piecePickedUp() async {
    HapticFeedback.selectionClick();
    await _play(_Sfx.click);
  }

  Future<void> moveLanded({required bool isCapture}) async {
    HapticFeedback.lightImpact();
    await _play(isCapture ? _Sfx.capture : _Sfx.move);
  }

  Future<void> check() async {
    HapticFeedback.heavyImpact();
    await _play(_Sfx.check);
  }

  Future<void> gameOver() async {
    // Game-over is haptic-only; no SFX wired up.
    HapticFeedback.heavyImpact();
  }

  Future<void> _play(_Sfx sfx) async {
    if (muted) return;
    final p = _players[sfx];
    if (p == null) return;
    try {
      // Stop any currently-playing instance first so rapid moves don't
      // queue up; we want the freshest sound to win.
      await p.stop();
      await p.play(AssetSource(sfx.assetPath));
    } catch (e) {
      dev.log('Failed to play ${sfx.name}: $e', name: 'sounds');
    }
  }

  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
  }
}

enum _Sfx {
  click('sounds/click.mp3'),
  move('sounds/move.mp3'),
  capture('sounds/capture.mp3'),
  check('sounds/check.mp3');

  final String assetPath;
  const _Sfx(this.assetPath);
}
