import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';
import '../models/call_model.dart';

/// Reads finished calls back out of the `calls` collection for the
/// Call History screen. We reuse the same `calls` collection rather
/// than duplicating into a second one - each document already has
/// caller/callee/type/status/duration, which is all History needs.
class CallHistoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<CallModel>> historyStream(String myUid) {
    return _db
        .collection(FirestoreCollections.calls)
        .where('callerId', isEqualTo: myUid)
        .snapshots()
        .asyncMap((callerSnap) async {
      final calleeSnap = await _db
          .collection(FirestoreCollections.calls)
          .where('calleeId', isEqualTo: myUid)
          .get();

      final all = [...callerSnap.docs, ...calleeSnap.docs]
          .map((d) => CallModel.fromMap(d.data(), d.id))
          .where((c) => c.status != CallStatus.calling && c.status != CallStatus.ringing)
          .toList();

      // De-dupe (a doc could theoretically show up in both queries
      // if callerId == calleeId, which shouldn't happen, but be safe).
      final byId = {for (final c in all) c.callId: c};
      final list = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }
}
