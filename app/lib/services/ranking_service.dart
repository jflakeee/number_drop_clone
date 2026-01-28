import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/ranking_entry.dart';
import 'auth_service.dart';
import 'offline_queue_service.dart';

/// Ranking types for different time periods
enum RankingType {
  all,
  daily,
  weekly,
}

/// Ranking service singleton for Firestore operations
class RankingService {
  RankingService._();
  static final RankingService instance = RankingService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get rankings collection reference
  CollectionReference<Map<String, dynamic>> get _rankingsRef =>
      _firestore.collection('rankings');

  /// Submit score to ranking
  /// Returns true if score was submitted successfully
  /// [gameSeed] - Optional seed for game verification
  Future<bool> submitScore({
    required int score,
    required int highestBlock,
    int? gameSeed,
  }) async {
    final auth = AuthService.instance;
    if (!auth.isSignedIn) {
      debugPrint('Cannot submit score: not signed in');
      return false;
    }

    try {
      final userId = auth.userId!;
      final displayName = await auth.getCurrentDisplayName();
      final photoUrl = auth.photoUrl;

      final entry = RankingEntry(
        userId: userId,
        displayName: displayName,
        photoUrl: photoUrl,
        score: score,
        highestBlock: highestBlock,
        gameSeed: gameSeed,
        updatedAt: DateTime.now(),
        platform: kIsWeb ? 'web' : 'mobile',
      );

      // Check if existing score is higher
      final existingDoc = await _rankingsRef.doc(userId).get();
      if (existingDoc.exists) {
        final existingScore = existingDoc.data()?['score'] ?? 0;
        if (existingScore >= score) {
          debugPrint(
              'Score not submitted: existing score ($existingScore) >= new score ($score)');
          return false;
        }
      }

      // Submit new high score
      await _rankingsRef.doc(userId).set(entry.toFirestore());
      debugPrint('Score submitted successfully: $score');
      return true;
    } catch (e) {
      debugPrint('Submit score error: $e');
      // Queue for offline submission
      await OfflineQueueService.instance.queueScore(
        score: score,
        highestBlock: highestBlock,
      );
      return false;
    }
  }

  /// Get rankings stream for real-time updates
  Stream<List<RankingEntry>> getRankingsStream({
    RankingType type = RankingType.all,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> query;

    // Apply time filter for daily/weekly (filter must come before orderBy for range queries)
    if (type == RankingType.daily) {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      query = _rankingsRef
          .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .orderBy('updatedAt', descending: true)
          .orderBy('score', descending: true)
          .limit(limit);
    } else if (type == RankingType.weekly) {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekDay =
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      query = _rankingsRef
          .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeekDay))
          .orderBy('updatedAt', descending: true)
          .orderBy('score', descending: true)
          .limit(limit);
    } else {
      // All time - no filter needed
      query = _rankingsRef.orderBy('score', descending: true).limit(limit);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => RankingEntry.fromFirestore(doc)).toList();
    });
  }

  /// Get rankings once (not real-time)
  Future<List<RankingEntry>> getRankings({
    RankingType type = RankingType.all,
    int limit = 100,
  }) async {
    try {
      Query<Map<String, dynamic>> query;

      // Apply time filter for daily/weekly (filter must come before orderBy for range queries)
      if (type == RankingType.daily) {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        query = _rankingsRef
            .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .orderBy('updatedAt', descending: true)
            .orderBy('score', descending: true)
            .limit(limit);
      } else if (type == RankingType.weekly) {
        final now = DateTime.now();
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeekDay =
            DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        query = _rankingsRef
            .where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeekDay))
            .orderBy('updatedAt', descending: true)
            .orderBy('score', descending: true)
            .limit(limit);
      } else {
        // All time - no filter needed
        query = _rankingsRef.orderBy('score', descending: true).limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => RankingEntry.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Get rankings error: $e');
      return [];
    }
  }

  /// Get current user's ranking entry
  Future<RankingEntry?> getMyRanking() async {
    final auth = AuthService.instance;
    if (!auth.isSignedIn) return null;

    try {
      final doc = await _rankingsRef.doc(auth.userId).get();
      if (doc.exists) {
        return RankingEntry.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Get my ranking error: $e');
      return null;
    }
  }

  /// Get current user's rank position (1-based)
  Future<int?> getMyRankPosition({RankingType type = RankingType.all}) async {
    final auth = AuthService.instance;
    if (!auth.isSignedIn) return null;

    try {
      final myRanking = await getMyRanking();
      if (myRanking == null) return null;

      if (type == RankingType.all) {
        // For all-time: simple count query (single field)
        final snapshot = await _rankingsRef
            .where('score', isGreaterThan: myRanking.score)
            .count()
            .get();
        return (snapshot.count ?? 0) + 1;
      } else {
        // For daily/weekly: fetch rankings and find position client-side
        // This avoids the multi-field inequality filter issue
        final rankings = await getRankings(type: type, limit: 1000);
        int position = 1;
        for (final entry in rankings) {
          if (entry.score > myRanking.score) {
            position++;
          }
        }
        // Check if user is in the time-filtered rankings
        final isInRankings = rankings.any((e) => e.odiserId == auth.userId);
        return isInRankings ? position : null;
      }
    } catch (e) {
      debugPrint('Get my rank position error: $e');
      return null;
    }
  }

  /// Check if user has a ranking entry
  Future<bool> hasRanking() async {
    final auth = AuthService.instance;
    if (!auth.isSignedIn) return false;

    try {
      final doc = await _rankingsRef.doc(auth.userId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Has ranking error: $e');
      return false;
    }
  }
}
