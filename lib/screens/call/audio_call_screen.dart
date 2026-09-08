import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/call_provider.dart';
import '../../services/calling_service.dart';
import '../../widgets/call_button.dart';

/// Functional audio-call UI: caller name/photo, live duration,
/// connection status, and Mute / Speaker / End controls.
class AudioCallScreen extends StatefulWidget {
  final String callId;
  final CallingService callingService;
  final bool isCaller;
  final String peerName;
  final String? peerPhotoUrl;

  const AudioCallScreen({
    super.key,
    required this.callId,
    required this.callingService,
    required this.isCaller,
    required this.peerName,
    this.peerPhotoUrl,
  });

  @override
  State<AudioCallScreen> createState() => _AudioCallScreenState();
}

class _AudioCallScreenState extends State<AudioCallScreen> {
  late CallProvider _call;
  Timer? _timer;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _call = CallProvider(widget.callingService);
    _call.status = widget.isCaller ? CallStatus.calling : CallStatus.connected;
    _call.addListener(_onCallChanged);
  }

  void _onCallChanged() {
    if (!mounted) return;
    if (_call.status == CallStatus.connected && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _call.tickDuration());
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
    _call.removeListener(_onCallChanged);
    super.dispose();
  }

  String get _statusLabel {
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _endCall();
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              children: [
                const Spacer(),
                CircleAvatar(
                  radius: 70,
                  backgroundColor: Colors.white24,
                  backgroundImage: widget.peerPhotoUrl != null
                      ? NetworkImage(widget.peerPhotoUrl!)
                      : null,
                  child: widget.peerPhotoUrl == null
                      ? Text(
                          widget.peerName.isNotEmpty
                              ? widget.peerName[0].toUpperCase()
                              : '?',
                          style:
                              const TextStyle(fontSize: 44, color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(height: 24),
                Text(
                  widget.peerName,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(_statusLabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 16)),
                const Spacer(),
                Row(
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
                      icon: _call.isSpeakerOn
                          ? Icons.volume_up
                          : Icons.hearing,
                      label: 'Speaker',
                      active: _call.isSpeakerOn,
                      activeColor: Colors.white,
                      onTap: () => _call.toggleSpeaker(),
                    ),
                    CallButton(
                      icon: Icons.call_end,
                      label: 'End',
                      danger: true,
                      onTap: _endCall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

