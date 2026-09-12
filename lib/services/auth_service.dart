import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';

/// Wraps Firebase Authentication and keeps the matching Firestore
/// `users/{uid}` document (profile + online status) in sync.
///
/// Swap this file out if you'd rather use Supabase or a custom
/// REST backend - nothing else in the app talks to Firebase Auth
/// directly, they all go through this service.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim();

    final cred = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    final user = cred.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-null',
        message: 'Account creation failed. Please try again.',
      );
    }

    try {
      await user.updateDisplayName(cleanName);
      await user.reload();
    } catch (e) {
      debugPrint('Display name update failed: $e');
    }

    await _upsertProfile(
      uid: user.uid,
      name: cleanName,
      email: cleanEmail,
      phoneNumber: phoneNumber,
      statusMessage: 'Available',
      online: true,
    );

    return cred;
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = cred.user;
    if (user != null) {
      await _upsertProfile(
        uid: user.uid,
        name: user.displayName ??
            user.email?.split('@').first ??
            'ConnectCall User',
        email: user.email ?? email.trim(),
        phoneNumber: user.phoneNumber,
        online: true,
      );
    }

    return cred;
  }

  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await _setOnline(uid, false);
      } catch (e) {
        debugPrint('Warning: Could not update offline status: $e');
      }
    }
    await _auth.signOut();
  }

  Future<void> _upsertProfile({
    required String uid,
    required String name,
    required String email,
    String? phoneNumber,
    String? statusMessage,
    required bool online,
  }) async {
    try {
      final data = <String, dynamic>{
        'name': name,
        'email': email,
        'isOnline': online,
        'lastSeen': FieldValue.serverTimestamp(),
      };

      final cleanPhone = phoneNumber?.trim();
      if (cleanPhone != null && cleanPhone.isNotEmpty) {
        data['phoneNumber'] = cleanPhone;
      }

      final cleanStatus = statusMessage?.trim();
      if (cleanStatus != null && cleanStatus.isNotEmpty) {
        data['statusMessage'] = cleanStatus;
      }

      final photoUrl = _auth.currentUser?.photoURL;
      if (photoUrl != null && photoUrl.isNotEmpty) {
        data['photoUrl'] = photoUrl;
      }

      await _db
          .collection(FirestoreCollections.users)
          .doc(uid)
          .set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Warning: Could not sync user profile: $e');
    }
  }

  Future<void> _setOnline(String uid, bool online) {
    return _db.collection(FirestoreCollections.users).doc(uid).set({
      'isOnline': online,
      'lastSeen': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Maps FirebaseAuthException codes to friendly, user-facing copy
  /// (Error Handling requirement).
  String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No account found with that email.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'That email is already registered.';
        case 'weak-password':
          return 'Password should be at least 6 characters.';
        case 'invalid-email':
          return 'That email address looks invalid.';
        case 'network-request-failed':
          return 'No internet connection. Please try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        default:
          return e.message ?? 'Something went wrong. Please try again.';
      }
    }
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'Your account is signed in, but the app could not sync your profile. Check Firestore rules and try again.';
        case 'unavailable':
          return 'Firebase is temporarily unavailable. Please try again.';
        default:
          return e.message ?? 'Firebase could not complete that request.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
