import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/variant.dart';
import '../firebase/firebase_service.dart';

/// Result of a successful match. Contains the Firestore document id of the
/// shared `/games/{gameId}` document, which color the local user plays, and
/// the variant being played.
class MatchedGame {
  final String gameId;
  final bool localPlaysWhite;
  final Variant variant;
  const MatchedGame({
    required this.gameId,
    required this.localPlaysWhite,
    required this.variant,
  });
}

/// Simple two-player matchmaking over Firestore.
///
/// Algorithm:
///   * The user signs into a queue document at `/queue/{variant}/waiting/{uid}`.
///   * If another waiter already exists for this variant, atomically create
///     `/games/{gameId}` with both players, delete both queue entries, and
///     return the [MatchedGame].
///   * Otherwise, sit in the queue and listen for a game doc that names this
///     uid. When matched, return.
///
/// This client-side approach is fine for v1; production should run the
/// pairing in a Cloud Function so timing-attack races can't double-pair.
class MatchmakingService {
  MatchmakingService._();
  static final instance = MatchmakingService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Future<MatchedGame> joinQueue({
    required String uid,
    required String username,
    required Variant variant,
  }) async {
    await FirebaseService.instance.ensureInitialized();
    final variantKey = variant.name;
    final queueCol = _db.collection('queue').doc(variantKey).collection('waiting');

    // Try to pair with the oldest existing waiter (other than self).
    final existing = await queueCol
        .where(FieldPath.documentId, isNotEqualTo: uid)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final other = existing.docs.first;
      final otherUid = other.id;
      final otherName = (other.data()['username'] as String?) ?? 'Opponent';

      // Randomize colors and create the game doc.
      final whiteIsLocal = Random().nextBool();
      final gameRef = _db.collection('games').doc();
      await _db.runTransaction((tx) async {
        // Re-read the other waiter inside the transaction; bail if vanished.
        final stillThere = await tx.get(other.reference);
        if (!stillThere.exists) {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            message: 'Opponent left the queue. Try again.',
          );
        }
        tx.set(gameRef, {
          'variant': variantKey,
          'whiteUid': whiteIsLocal ? uid : otherUid,
          'blackUid': whiteIsLocal ? otherUid : uid,
          'whiteName': whiteIsLocal ? username : otherName,
          'blackName': whiteIsLocal ? otherName : username,
          'createdAt': FieldValue.serverTimestamp(),
          'history': <Map<String, dynamic>>[],
          'sideToMove': 'white',
          'result': null, // null until terminal
        });
        tx.delete(other.reference);
        // Make sure we're not also lingering as a waiter from a prior attempt.
        tx.delete(queueCol.doc(uid));
      });
      return MatchedGame(
        gameId: gameRef.id,
        localPlaysWhite: whiteIsLocal,
        variant: variant,
      );
    }

    // No one to pair with — register self as a waiter, then listen for a
    // game where this uid appears.
    await queueCol.doc(uid).set({
      'username': username,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final completer = Completer<MatchedGame>();
    late StreamSubscription sub;
    sub = _db.collection('games')
        .where('whiteUid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty) return;
      sub.cancel();
      completer.complete(MatchedGame(
        gameId: snap.docs.first.id,
        localPlaysWhite: true,
        variant: variant,
      ));
    });
    // Mirror listener for the black-seat case.
    final sub2 = _db.collection('games')
        .where('blackUid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty) return;
      if (completer.isCompleted) return;
      sub.cancel();
      completer.complete(MatchedGame(
        gameId: snap.docs.first.id,
        localPlaysWhite: false,
        variant: variant,
      ));
    });

    return completer.future.whenComplete(() async {
      await sub.cancel();
      await sub2.cancel();
    });
  }

  Future<void> leaveQueue({required String uid, required Variant variant}) async {
    final queueCol =
        _db.collection('queue').doc(variant.name).collection('waiting');
    await queueCol.doc(uid).delete().catchError((_) {});
  }
}
