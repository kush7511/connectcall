import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/call_provider.dart';
import '../../services/calling_service.dart';
import '../../widgets/call_button.dart';

/// Functional video-call UI: full-screen remote video, a draggable
/// local camera preview, caller info overlay, and Mute / Camera /
/// Switch Camera / End controls.
class VideoCallScreen extends StatefulWidget {
  final String callId;
  final CallingService callingService;
  final bool isCaller;
  final String peerName;
  final String? peerPhotoUrl;

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.callingService,
    required this.isCaller,
    required this.peerName,
    this.peerPhotoUrl,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late CallProvider _call;
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  Timer? _timer;
  bool _ended = false;
  bool _renderersReady = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    _call = CallProvider(widget.callingService);
    _call.status = widget.isCaller ? CallStatus.calling : CallStatus.connected;

    if (_call.localStream != null) {
      _localRenderer.srcObject = _call.localStream;
    }
    if (_call.remoteStream != null) {
      _remoteRenderer.srcObject = _call.remoteStream;
    }

    _call.addListener(_onCallChanged);
    if (mounted) setState(() => _renderersReady = true);
  }

  void _onCallChanged() {
    if (!mounted) return;
    _localRenderer.srcObject = _call.localStream;
    _remoteRenderer.srcObject = _call.remoteStream;

    if (_call.status == CallStatus.connected && _timer == null) {
      _timer = Timer.periodic(
          const Duration(seconds: 1), (_) => _call.tickDuration());
    }
    if ([
          CallStatus.ended,
          CallStatus.rejected,
          CallStatus.missed,
          CallStatus.failed,
          CallStatus.busy,
        ].contains(_call.status) &&
        !_ended) {
      _ended = true;
      _timer?.cancel();
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
    }
    setState(() {});
  }

  Future<void> _endCall() async {
    if (_ended) return;
    _ended = true;
    _timer?.cancel();
    await _call.endCall();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_renderersReady) _call.removeListener(_onCallChanged);
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  String get _statusLabel {
    if (!_renderersReady) return 'Setting up...';
    switch (_call.status) {
      case CallStatus.calling:
        return widget.isCaller ? 'Calling...' : 'Connecting...';
      case CallStatus.connected:
        return _call.formattedDuration;
      case CallStatus.rejected:
        return 'Call declined';
      case CallStatus.missed:
        return 'No answer';
      case CallStatus.failed:
        return 'Call failed';
      case CallStatus.ended:
        return 'Call ended';
      default:
        return _call.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_renderersReady) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final hasRemoteVideo = _call.remoteStream != null &&
        _call.remoteStream!.getVideoTracks().isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _endCall();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Remote video (full screen), or peer avatar while
            // connecting.
            Positioned.fill(
              child: hasRemoteVideo
                  ? RTCVideoView(_remoteRenderer, mirror: false)
                  : Container(
                      color: AppColors.primaryDark,
                      child: Center(
                        child: CircleAvatar(
                          radius: 64,
                          backgroundColor: Colors.white24,
                          backgroundImage: widget.peerPhotoUrl != null
                              ? NetworkImage(widget.peerPhotoUrl!)
                              : null,
                          child: widget.peerPhotoUrl == null
                              ? Text(
                                  widget.peerName.isNotEmpty
                                      ? widget.peerName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      fontSize: 40, color: Colors.white),
                                )
                              : null,
                        ),
                      ),
                    ),
            ),

            // Top gradient + caller info.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.peerName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_statusLabel,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ),

            // Local camera preview (draggable-feel box, top right).
            if (_call.isCameraOn)
              Positioned(
                top: 60,
                right: 16,
                child: Container(
                  width: 110,
                  height: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: RTCVideoView(_localRenderer, mirror: true),
                ),
              ),

            // Bottom controls.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    CallButton(
                      icon: _call.isMuted ? Icons.mic_off : Icons.mic,
                      label: 'Mute',
                      active: _call.isMuted,
                      activeColor: Colors.white,
                      onTap: () => _call.toggleMute(),
                    ),
                    CallButton(
                      icon: _call.isCameraOn
                          ? Icons.videocam
                          : Icons.videocam_off,
                      label: 'Camera',
                      active: !_call.isCameraOn,
                      activeColor: Colors.white,
                      onTap: () => _call.toggleCamera(),
                    ),
                    CallButton(
                      icon: Icons.cameraswitch,
                      label: 'Switch',
                      onTap: () => _call.switchCamera(),
                    ),
                    CallButton(
                      icon: Icons.call_end,
                      label: 'End',
                      danger: true,
                      onTap: _endCall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
