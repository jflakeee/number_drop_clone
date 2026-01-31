import 'package:cloud_firestore/cloud_firestore.dart';

/// Battle status enum
enum BattleStatus {
  waiting,  // Waiting for opponent
  ready,    // Both players ready
  playing,  // Game in progress
  finished, // Game finished
}

/// Player data in a battle
class BattlePlayer {
  final String userId;
  final String displayName;
  final String? photoUrl;
  final int score;
  final int highestBlock;
  final bool isReady;
  final bool isFinished;
  final DateTime? finishedAt;

  const BattlePlayer({
    required this.userId,
    required this.displayName,
    this.photoUrl,
    this.score = 0,
    this.highestBlock = 0,
    this.isReady = false,
    this.isFinished = false,
    this.finishedAt,
  });

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'score': score,
        'highestBlock': highestBlock,
        'isReady': isReady,
        'isFinished': isFinished,
        'finishedAt': finishedAt?.toIso8601String(),
      };

  factory BattlePlayer.fromJson(Map<String, dynamic> json) => BattlePlayer(
        userId: json['userId'] as String,
        displayName: json['displayName'] as String? ?? 'Unknown',
        photoUrl: json['photoUrl'] as String?,
        score: json['score'] as int? ?? 0,
        highestBlock: json['highestBlock'] as int? ?? 0,
        isReady: json['isReady'] as bool? ?? false,
        isFinished: json['isFinished'] as bool? ?? false,
        finishedAt: json['finishedAt'] != null
            ? DateTime.parse(json['finishedAt'] as String)
            : null,
      );

  BattlePlayer copyWith({
    String? userId,
    String? displayName,
    String? photoUrl,
    int? score,
    int? highestBlock,
    bool? isReady,
    bool? isFinished,
    DateTime? finishedAt,
  }) =>
      BattlePlayer(
        userId: userId ?? this.userId,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
        score: score ?? this.score,
        highestBlock: highestBlock ?? this.highestBlock,
        isReady: isReady ?? this.isReady,
        isFinished: isFinished ?? this.isFinished,
        finishedAt: finishedAt ?? this.finishedAt,
      );
}

/// Battle model for 1v1 matches
class Battle {
  final String id;
  final int seed;
  final BattleStatus status;
  final Map<String, BattlePlayer> players;
  final String? winnerId;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  const Battle({
    required this.id,
    required this.seed,
    required this.status,
    required this.players,
    this.winnerId,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
  });

  /// Get player count
  int get playerCount => players.length;

  /// Check if battle is full (2 players)
  bool get isFull => players.length >= 2;

  /// Check if all players are ready
  bool get allPlayersReady =>
      players.length == 2 && players.values.every((p) => p.isReady);

  /// Check if all players finished
  bool get allPlayersFinished =>
      players.length == 2 && players.values.every((p) => p.isFinished);

  /// Get winner (player with highest score)
  BattlePlayer? get winner {
    if (!allPlayersFinished) return null;
    final playerList = players.values.toList();
    if (playerList[0].score > playerList[1].score) return playerList[0];
    if (playerList[1].score > playerList[0].score) return playerList[1];
    return null; // Draw
  }

  /// Check if it's a draw
  bool get isDraw {
    if (!allPlayersFinished) return false;
    final playerList = players.values.toList();
    return playerList[0].score == playerList[1].score;
  }

  /// Get opponent for a given player
  BattlePlayer? getOpponent(String userId) {
    for (final player in players.values) {
      if (player.userId != userId) return player;
    }
    return null;
  }

  /// Get player by ID
  BattlePlayer? getPlayer(String userId) => players[userId];

  Map<String, dynamic> toFirestore() => {
        'seed': seed,
        'status': status.name,
        'players': players.map((k, v) => MapEntry(k, v.toJson())),
        'winnerId': winnerId,
        'createdAt': FieldValue.serverTimestamp(),
        'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
        'finishedAt':
            finishedAt != null ? Timestamp.fromDate(finishedAt!) : null,
      };

  factory Battle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final playersData = data['players'] as Map<String, dynamic>? ?? {};

    return Battle(
      id: doc.id,
      seed: data['seed'] as int? ?? 0,
      status: BattleStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => BattleStatus.waiting,
      ),
      players: playersData.map(
        (k, v) => MapEntry(k, BattlePlayer.fromJson(v as Map<String, dynamic>)),
      ),
      winnerId: data['winnerId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      finishedAt: (data['finishedAt'] as Timestamp?)?.toDate(),
    );
  }

  Battle copyWith({
    String? id,
    int? seed,
    BattleStatus? status,
    Map<String, BattlePlayer>? players,
    String? winnerId,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) =>
      Battle(
        id: id ?? this.id,
        seed: seed ?? this.seed,
        status: status ?? this.status,
        players: players ?? this.players,
        winnerId: winnerId ?? this.winnerId,
        createdAt: createdAt ?? this.createdAt,
        startedAt: startedAt ?? this.startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
      );
}
