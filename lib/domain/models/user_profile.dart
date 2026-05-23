/// Profile attached to a signed-in user.
///
/// Stored at `/users/{uid}` in Firestore. The schema is intentionally tiny so
/// that the field set can grow without migrations.
class UserProfile {
  final String uid;
  final String username;
  final String email;
  final int eloClassic;
  final int eloLong;
  final int eloSilent;
  final int eloReverse;
  final int eloBarbarian;
  final int gamesPlayed;
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    required this.username,
    required this.email,
    this.eloClassic = 1200,
    this.eloLong = 1200,
    this.eloSilent = 1200,
    this.eloReverse = 1200,
    this.eloBarbarian = 1200,
    this.gamesPlayed = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'username': username,
    'email': email,
    'eloClassic': eloClassic,
    'eloLong': eloLong,
    'eloSilent': eloSilent,
    'eloReverse': eloReverse,
    'eloBarbarian': eloBarbarian,
    'gamesPlayed': gamesPlayed,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    uid: j['uid'] as String,
    username: j['username'] as String? ?? '',
    email: j['email'] as String? ?? '',
    eloClassic: (j['eloClassic'] as num?)?.toInt() ?? 1200,
    eloLong: (j['eloLong'] as num?)?.toInt() ?? 1200,
    eloSilent: (j['eloSilent'] as num?)?.toInt() ?? 1200,
    eloReverse: (j['eloReverse'] as num?)?.toInt() ?? 1200,
    eloBarbarian: (j['eloBarbarian'] as num?)?.toInt() ?? 1200,
    gamesPlayed: (j['gamesPlayed'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  UserProfile copyWith({
    String? username,
    int? eloClassic, int? eloLong, int? eloSilent,
    int? eloReverse, int? eloBarbarian,
    int? gamesPlayed,
  }) => UserProfile(
    uid: uid,
    username: username ?? this.username,
    email: email,
    eloClassic: eloClassic ?? this.eloClassic,
    eloLong: eloLong ?? this.eloLong,
    eloSilent: eloSilent ?? this.eloSilent,
    eloReverse: eloReverse ?? this.eloReverse,
    eloBarbarian: eloBarbarian ?? this.eloBarbarian,
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    createdAt: createdAt,
  );
}
