import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Live list of every user except the current one, for the
  /// Contacts screen. Online users bubble to the top.
  Stream<List<UserModel>> contactsStream(String myUid) {
    return _db.collection(FirestoreCollections.users).snapshots().map(
      (snap) {
        final users = snap.docs
            .where((d) => d.id != myUid)
            .map((d) => UserModel.fromMap(d.data(), d.id))
            .toList();
        users.sort((a, b) {
          if (a.isOnline == b.isOnline) return a.name.compareTo(b.name);
          return a.isOnline ? -1 : 1;
        });
        return users;
      },
    );
  }

  List<UserModel> filter(List<UserModel> users, String query) {
    if (query.trim().isEmpty) return users;
    final q = query.toLowerCase();
    return users.where((u) {
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          (u.phoneNumber?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _db.collection(FirestoreCollections.users).doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  Future<void> updateProfile({
    required String uid,
    String? name,
    String? phoneNumber,
    String? statusMessage,
    String? photoUrl,
  }) {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
    if (statusMessage != null) data['statusMessage'] = statusMessage;
    if (photoUrl != null) data['photoUrl'] = photoUrl;
    return _db
        .collection(FirestoreCollections.users)
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }
}
