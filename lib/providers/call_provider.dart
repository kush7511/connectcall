import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../core/constants/app_constants.dart';
import '../services/calling_service.dart';

/// Drives the audio/video call screens: owns the CallingService,
/// exposes the current call status and local/remote streams as
/// observable state, and tracks call duration.
class CallProvider extends ChangeNotifier {
  final CallingService callingService;

  MediaStream? localStream;
  MediaStream? remoteStream;
  String status = CallStatus.calling;
  bool isMuted = false;
  bool isCameraOn = true;
  bool isSpeakerOn = true;
  int durationSeconds = 0;

  /// [service] should be the *same* CallingService instance that
  /// already created/answered the call (via ContactsScreen or
  /// IncomingCallScreen) - never a fresh one, or the peer
  /// connection state will be lost.
  CallProvider(CallingService service) : callingService = service {
    callingService.onLocalStream = (s) {
      localStream = s;
      notifyListeners();
    };
    callingService.onRemoteStream = (s) {
      remoteStream = s;
      notifyListeners();
    };
    callingService.onCallStatusChanged = (s) {
      status = s;
      notifyListeners();
    };
  }

  void tickDuration() {
    durationSeconds++;
    notifyListeners();
  }

  Future<void> toggleMute() async {
    isMuted = !isMuted;
    await callingService.toggleMute(isMuted);
    notifyListeners();
  }

  Future<void> toggleCamera() async {
    isCameraOn = !isCameraOn;
    await callingService.toggleCamera(isCameraOn);
    notifyListeners();
  }

  Future<void> switchCamera() async {
    await callingService.switchCamera();
  }

  void toggleSpeaker() {
    isSpeakerOn = !isSpeakerOn;
    Helper.setSpeakerphoneOn(isSpeakerOn);
    notifyListeners();
  }

  Future<void> endCall() async {
    await callingService.hangUp(durationSeconds: durationSeconds);
  }

  String get formattedDuration {
    final m = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
