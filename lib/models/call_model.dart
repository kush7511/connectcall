import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants/app_constants.dart';

class CallModel {
  final String callId;
  final String callerId;
  final String callerName;
  final String? callerPhotoUrl;
  final String calleeId;
  final String calleeName;
  final String? calleePhotoUrl;
  final String type; // CallType.audio | CallType.video
  final String status; // CallStatus.*
  final DateTime createdAt;
  final int durationSeconds;

  CallModel({
    required this.callId,
    required this.callerId,
    required this.callerName,
    this.callerPhotoUrl,
    required this.calleeId,
    required this.calleeName,
    this.calleePhotoUrl,
    required this.type,
    required this.status,
    required this.createdAt,
    this.durationSeconds = 0,
  });

  factory CallModel.fromMap(Map<String, dynamic> map, String id) {
    return CallModel(
      callId: id,
      callerId: map['callerId'] ?? '',
      callerName: map['callerName'] ?? '',
      callerPhotoUrl: map['callerPhotoUrl'],
      calleeId: map['calleeId'] ?? '',
      calleeName: map['calleeName'] ?? '',
      calleePhotoUrl: map['calleePhotoUrl'],
      type: map['type'] ?? CallType.audio,
      status: map['status'] ?? CallStatus.calling,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      durationSeconds: map['durationSeconds'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'callerId': callerId,
      'callerName': callerName,
      'callerPhotoUrl': callerPhotoUrl,
      'calleeId': calleeId,
      'calleeName': calleeName,
      'calleePhotoUrl': calleePhotoUrl,
      'type': type,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'durationSeconds': durationSeconds,
    };
  }

  /// Helper for the Call History screen: is this call incoming
  /// or outgoing relative to [myUid]?
  bool isOutgoing(String myUid) => callerId == myUid;

  bool get isMissed => status == CallStatus.missed;
}
