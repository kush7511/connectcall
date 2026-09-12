import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/direct_contact_model.dart';

class DirectContactService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _contactsRef(String uid) {
    return _db
        .collection(FirestoreCollections.users)
        .doc(uid)
        .collection(FirestoreCollections.directContacts);
  }

  Stream<List<DirectContactModel>> contactsStream(String uid) {
    return _contactsRef(uid).orderBy('name').snapshots().map((snap) {
      return snap.docs
          .map((doc) => DirectContactModel.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> addContact({
    required String uid,
    required String name,
    required String phoneNumber,
    String? note,
  }) {
    return _contactsRef(uid).add({
      'name': name.trim(),
      'phoneNumber': phoneNumber.trim(),
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateContact({
    required String uid,
    required String contactId,
    required String name,
    required String phoneNumber,
    String? note,
  }) {
    return _contactsRef(uid).doc(contactId).update({
      'name': name.trim(),
      'phoneNumber': phoneNumber.trim(),
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteContact({
    required String uid,
    required String contactId,
  }) {
    return _contactsRef(uid).doc(contactId).delete();
  }

  List<DirectContactModel> filter(
    List<DirectContactModel> contacts,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return contacts;
    return contacts.where((contact) {
      return contact.name.toLowerCase().contains(q) ||
          contact.phoneNumber.toLowerCase().contains(q) ||
          (contact.note?.toLowerCase().contains(q) ?? false);
    }).toList();
  }
}
