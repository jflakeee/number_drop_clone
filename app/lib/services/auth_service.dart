import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

/// Authentication service singleton for anonymous and Google Sign-In
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  String? get userId => currentUser?.uid;
  String? get displayName => currentUser?.displayName;
  String? get photoUrl => currentUser?.photoURL;

  /// Check if user is signed in with Google (not anonymous)
  bool get isGoogleSignedIn =>
      currentUser != null && !currentUser!.isAnonymous;

  /// Check if user is anonymous
  bool get isAnonymous => currentUser?.isAnonymous ?? true;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Initialize authentication - sign in anonymously if not signed in
  Future<void> init() async {
    if (currentUser == null) {
      await signInAnonymously();
    }
  }

  /// Sign in anonymously
  Future<User?> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      final user = userCredential.user;

      if (user != null) {
        await _createOrUpdateProfile(user, isAnonymous: true);
      }

      debugPrint('Signed in anonymously: ${user?.uid}');
      return user;
    } catch (e) {
      debugPrint('Anonymous sign-in error: $e');
      return null;
    }
  }

  /// Sign in with Google (links to existing anonymous account if present)
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null; // User cancelled
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      User? user;
      final currentAnonymousUser = currentUser;

      // If currently signed in anonymously, link the Google credential
      if (currentAnonymousUser != null && currentAnonymousUser.isAnonymous) {
        try {
          final userCredential =
              await currentAnonymousUser.linkWithCredential(credential);
          user = userCredential.user;
          debugPrint('Linked Google account to anonymous user');

          // Migrate anonymous data to Google account
          if (user != null) {
            await _migrateAnonymousData(currentAnonymousUser.uid, user.uid);
          }
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            // Google account already exists, sign in directly
            debugPrint('Google account already exists, signing in directly');

            // Get the old anonymous user ID before signing out
            final oldAnonymousId = currentAnonymousUser.uid;

            // Sign out anonymous and sign in with Google
            await _auth.signOut();
            final userCredential =
                await _auth.signInWithCredential(credential);
            user = userCredential.user;

            // Migrate anonymous ranking data if it exists
            if (user != null) {
              await _migrateAnonymousData(oldAnonymousId, user.uid);
            }
          } else {
            rethrow;
          }
        }
      } else {
        // Not anonymous, just sign in with Google
        final userCredential = await _auth.signInWithCredential(credential);
        user = userCredential.user;
      }

      if (user != null) {
        await _createOrUpdateProfile(user, isAnonymous: false);
      }

      return user;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return null;
    }
  }

  /// Sign out (reverts to anonymous)
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      // Sign in anonymously again
      await signInAnonymously();
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  /// Migrate anonymous user data to Google account
  Future<void> _migrateAnonymousData(
      String anonymousId, String googleId) async {
    try {
      // Check if anonymous user has ranking data
      final anonymousRanking =
          await _firestore.collection('rankings').doc(anonymousId).get();

      if (anonymousRanking.exists) {
        final anonymousData = anonymousRanking.data()!;
        final anonymousScore = anonymousData['score'] ?? 0;

        // Check if Google account has ranking data
        final googleRanking =
            await _firestore.collection('rankings').doc(googleId).get();

        if (googleRanking.exists) {
          final googleScore = googleRanking.data()?['score'] ?? 0;

          // Only migrate if anonymous score is higher
          if (anonymousScore > googleScore) {
            await _firestore.collection('rankings').doc(googleId).set({
              ...anonymousData,
              'userId': googleId,
              'updatedAt': FieldValue.serverTimestamp(),
            });
            debugPrint(
                'Migrated anonymous ranking (higher score): $anonymousScore');
          }
        } else {
          // No Google ranking exists, migrate anonymous data
          await _firestore.collection('rankings').doc(googleId).set({
            ...anonymousData,
            'userId': googleId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('Migrated anonymous ranking: $anonymousScore');
        }

        // Delete anonymous ranking after migration
        await _firestore.collection('rankings').doc(anonymousId).delete();
      }

      // Migrate user profile if exists
      final anonymousProfile =
          await _firestore.collection('users').doc(anonymousId).get();
      if (anonymousProfile.exists) {
        await _firestore.collection('users').doc(anonymousId).delete();
      }
    } catch (e) {
      debugPrint('Migration error: $e');
    }
  }

  /// Create or update user profile
  Future<void> _createOrUpdateProfile(User user,
      {required bool isAnonymous}) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      String defaultName;
      if (isAnonymous) {
        // Generate a random guest name
        final shortId = user.uid.substring(0, 6).toUpperCase();
        defaultName = 'Guest_$shortId';
      } else {
        defaultName = user.displayName ?? 'Player';
      }

      final profile = UserProfile(
        userId: user.uid,
        displayName: defaultName,
        photoUrl: user.photoURL,
        createdAt: DateTime.now(),
      );
      await docRef.set(profile.toFirestore());
    } else if (!isAnonymous) {
      // Update photo URL if signed in with Google
      await docRef.update({
        'photoUrl': user.photoURL,
      });
    }
  }

  /// Get user profile from Firestore
  Future<UserProfile?> getUserProfile() async {
    if (!isSignedIn) return null;

    try {
      final doc =
          await _firestore.collection('users').doc(currentUser!.uid).get();
      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Get user profile error: $e');
      return null;
    }
  }

  /// Update display name (custom nickname)
  /// Only allowed for Google-signed-in users
  Future<bool> updateDisplayName(String newName) async {
    if (!isSignedIn) return false;
    if (isAnonymous) {
      debugPrint('Cannot update display name: user is anonymous');
      return false;
    }

    try {
      await _firestore.collection('users').doc(currentUser!.uid).update({
        'displayName': newName,
      });

      // Also update rankings displayName if exists
      final rankingDoc =
          await _firestore.collection('rankings').doc(currentUser!.uid).get();
      if (rankingDoc.exists) {
        await _firestore.collection('rankings').doc(currentUser!.uid).update({
          'displayName': newName,
        });
      }

      return true;
    } catch (e) {
      debugPrint('Update display name error: $e');
      return false;
    }
  }

  /// Get current display name (from profile or generated)
  Future<String> getCurrentDisplayName() async {
    final profile = await getUserProfile();
    if (profile != null) {
      return profile.displayName;
    }

    if (isAnonymous && userId != null) {
      final shortId = userId!.substring(0, 6).toUpperCase();
      return 'Guest_$shortId';
    }

    return displayName ?? 'Player';
  }
}
