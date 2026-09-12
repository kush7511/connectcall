import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_constants.dart';
import '../models/call_model.dart';

/// The heart of the app: sets up a peer-to-peer WebRTC connection
/// between two users, using Firestore purely as a signaling
/// channel (it never sees the actual audio/video, only the small
/// SDP/ICE handshake messages needed to open the P2P link).
///
/// Firestore layout used for signaling:
///   calls/{callId}
///     - callerId, calleeId, type, status, offer, answer...
///     calls/{callId}/callerCandidates/{autoId}
///     calls/{callId}/calleeCandidates/{autoId}
///
/// Flow:
///  1. Caller: createCall() creates an SDP offer, writes it + a
///     'ringing' status to Firestore.
///  2. Callee: listens for docs where calleeId == me && status ==
///     ringing -> shows IncomingCallScreen.
///  3. Callee accepts: answerCall() creates an SDP answer, writes it.
///  4. Both sides stream their local ICE candidates into their own
///     subcollection and listen to the other side's subcollection,
///     feeding candidates into the RTCPeerConnection as they arrive.
///  5. Either side can hangUp() which sets status = 'ended' and
///     tears down local resources; the other side's listener reacts.
///
/// STUN-only config is used below (Google's public STUN server).
/// For calls across restrictive NATs/firewalls you would add a TURN
/// server (e.g. via Twilio, Xirsys, or your own coturn) to the
/// `iceServers` list.
class CallingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  RTCPeerConnection? _peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  StreamSubscription? _callDocSub;
  StreamSubscription? _remoteCandidatesSub;
  String? _activeCallId;
  bool _isCaller = false;

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {
        'urls': [
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ]
      },
    ]
  };

  // ---- Callbacks the UI layer hooks into ----
  void Function(MediaStream stream)? onLocalStream;
  void Function(MediaStream stream)? onRemoteStream;
  void Function(String status)? onCallStatusChanged;

  /// Grabs mic (+ camera for video calls) and returns the local stream.
  Future<MediaStream> _getUserMedia(bool video) async {
    final constraints = {
      'audio': true,
      'video': video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640},
              'height': {'ideal': 480},
            }
          : false,
    };
    final stream = await navigator.mediaDevices.getUserMedia(constraints);
    localStream = stream;
    onLocalStream?.call(stream);
    return stream;
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final pc = await createPeerConnection(_iceServers);

    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        onRemoteStream?.call(remoteStream!);
      }
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onCallStatusChanged?.call(CallStatus.connected);
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        onCallStatusChanged?.call(CallStatus.failed);
      }
    };

    return pc;
  }

  /// CALLER SIDE: starts a new call, creates the SDP offer and
  /// writes everything the callee needs into Firestore.
  Future<String> createCall({
    required String callerId,
    required String callerName,
    String? callerPhotoUrl,
    required String calleeId,
    required String calleeName,
    String? calleePhotoUrl,
    required String type, // CallType.audio | CallType.video
  }) async {
    _isCaller = true;
    final callId = _uuid.v4();
    _activeCallId = callId;

    await _getUserMedia(type == CallType.video);
    _peerConnection = await _createPeerConnection();
    for (final track in localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, localStream!);
    }

    final callDoc = _db.collection(FirestoreCollections.calls).doc(callId);

    // Stream our ICE candidates as they're discovered.
    _peerConnection!.onIceCandidate = (candidate) {
      callDoc.collection('callerCandidates').add(candidate.toMap());
    };

    final offer = await _peerConnection!.createOffer(
      type == CallType.video
          ? {'offerToReceiveAudio': true, 'offerToReceiveVideo': true}
          : {'offerToReceiveAudio': true, 'offerToReceiveVideo': false},
    );
    await _peerConnection!.setLocalDescription(offer);

    final model = CallModel(
      callId: callId,
      callerId: callerId,
      callerName: callerName,
      callerPhotoUrl: callerPhotoUrl,
      calleeId: calleeId,
      calleeName: calleeName,
      calleePhotoUrl: calleePhotoUrl,
      type: type,
      status: CallStatus.ringing,
      createdAt: DateTime.now(),
    );

    await callDoc.set({
      ...model.toMap(),
      'offer': {'type': offer.type, 'sdp': offer.sdp},
    });

    _listenForRemoteAnswerAndCandidates(callDoc, isCaller: true);
    _autoTimeoutIfUnanswered(callDoc);
    return callId;
  }

  /// CALLEE SIDE: called once the user taps Accept on the
  /// IncomingCallScreen. Builds the answer and streams our ICE
  /// candidates in reply.
  Future<void> answerCall(String callId, String type) async {
    _isCaller = false;
    _activeCallId = callId;

    await _getUserMedia(type == CallType.video);
    _peerConnection = await _createPeerConnection();
    for (final track in localStream!.getTracks()) {
      await _peerConnection!.addTrack(track, localStream!);
    }

    final callDoc = _db.collection(FirestoreCollections.calls).doc(callId);
    final snap = await callDoc.get();
    final data = snap.data();
    if (data == null || data['offer'] == null) {
      throw Exception('Call offer not found - it may have been cancelled.');
    }

    _peerConnection!.onIceCandidate = (candidate) {
      callDoc.collection('calleeCandidates').add(candidate.toMap());
    };

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(data['offer']['sdp'], data['offer']['type']),
    );

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await callDoc.update({
      'answer': {'type': answer.type, 'sdp': answer.sdp},
      'status': CallStatus.connected,
    });

    _listenForRemoteAnswerAndCandidates(callDoc, isCaller: false);
  }

  Future<void> rejectCall(String callId) {
    return _db
        .collection(FirestoreCollections.calls)
        .doc(callId)
        .update({'status': CallStatus.rejected});
  }

  /// Watches the call document for the answer (caller side) and
  /// listens to the other party's ICE candidate subcollection,
  /// feeding both into the local RTCPeerConnection.
  void _listenForRemoteAnswerAndCandidates(
    DocumentReference<Map<String, dynamic>> callDoc, {
    required bool isCaller,
  }) {
    _callDocSub = callDoc.snapshots().listen((snap) async {
      final data = snap.data();
      if (data == null) return;

      if (isCaller &&
          data['answer'] != null &&
          _peerConnection?.getRemoteDescription() == null) {
        final answer = data['answer'];
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']),
        );
      }

      final status = data['status'] as String?;
      if (status != null) {
        onCallStatusChanged?.call(status);
        if ([
          CallStatus.ended,
          CallStatus.rejected,
          CallStatus.missed,
          CallStatus.busy,
          CallStatus.failed,
        ].contains(status)) {
          _cleanupLocal();
        }
      }
    });

    final remoteCandidatesField =
        isCaller ? 'calleeCandidates' : 'callerCandidates';
    _remoteCandidatesSub =
        callDoc.collection(remoteCandidatesField).snapshots().listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final c = change.doc.data()!;
          _peerConnection?.addCandidate(
            RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']),
          );
        }
      }
    });
  }

  /// If nobody answers within 30s, mark the call as missed.
  void _autoTimeoutIfUnanswered(
      DocumentReference<Map<String, dynamic>> callDoc) {
    Future.delayed(const Duration(seconds: 30), () async {
      final snap = await callDoc.get();
      if (snap.data()?['status'] == CallStatus.ringing) {
        await callDoc.update({'status': CallStatus.missed});
      }
    });
  }

  Future<void> toggleMute(bool mute) async {
    localStream?.getAudioTracks().forEach((t) => t.enabled = !mute);
  }

  Future<void> toggleCamera(bool enabled) async {
    localStream?.getVideoTracks().forEach((t) => t.enabled = enabled);
  }

  Future<void> switchCamera() async {
    final videoTrack = localStream?.getVideoTracks().firstOrNull;
    if (videoTrack != null) {
      await Helper.switchCamera(videoTrack);
    }
  }

  /// Ends the call for both parties and persists a call-history
  /// record with the final duration.
  Future<void> hangUp({int durationSeconds = 0}) async {
    if (_activeCallId != null) {
      final callDoc =
          _db.collection(FirestoreCollections.calls).doc(_activeCallId);
      await callDoc.update({
        'status': CallStatus.ended,
        'durationSeconds': durationSeconds,
      });
    }
    _cleanupLocal();
  }

  void _cleanupLocal() {
    _callDocSub?.cancel();
    _remoteCandidatesSub?.cancel();
    localStream?.getTracks().forEach((t) => t.stop());
    localStream?.dispose();
    _peerConnection?.close();
    _peerConnection = null;
    localStream = null;
    remoteStream = null;
    _activeCallId = null;
  }

  /// Live stream of incoming calls for [myUid] - the Home/root
  /// screen listens to this to pop up the IncomingCallScreen.
  Stream<CallModel?> incomingCallStream(String myUid) {
    return _db
        .collection(FirestoreCollections.calls)
        .where('calleeId', isEqualTo: myUid)
        .where('status', isEqualTo: CallStatus.ringing)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return CallModel.fromMap(doc.data(), doc.id);
    });
  }

  bool get isCaller => _isCaller;
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
