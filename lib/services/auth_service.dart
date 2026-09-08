import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user?.updateDisplayName(name);

    await _db.collection(FirestoreCollections.users).doc(cred.user!.uid).set({
      'name': name,
      'email': email.trim(),
      'photoUrl': null,
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });

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
    await _setOnline(cred.user!.uid, true);
    return cred;
  }

  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) await _setOnline(uid, false);
    await _auth.signOut();
  }

  Future<void> _setOnline(String uid, bool online) {
    return _db.collection(FirestoreCollections.users).doc(uid).update({
      'isOnline': online,
      'lastSeen': FieldValue.serverTimestamp(),
    });
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
        default:
          return e.message ?? 'Something went wrong. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
