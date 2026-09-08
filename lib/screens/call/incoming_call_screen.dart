import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/call_model.dart';
import '../../services/calling_service.dart';
import 'audio_call_screen.dart';
import 'video_call_screen.dart';

/// Full-screen incoming-call UI, per the assignment mock-up:
/// caller photo/name, call-type label, Decline / Accept.
class IncomingCallScreen extends StatefulWidget {
  final CallModel call;
  const IncomingCallScreen({super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final _callingService = CallingService();
  bool _responding = false;

  Future<void> _decline() async {
    setState(() => _responding = true);
    await _callingService.rejectCall(widget.call.callId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _accept() async {
    final video = widget.call.type == CallType.video;
    final statuses = await [
      Permission.microphone,
      if (video) Permission.camera,
    ].request();

    if (statuses.values.any((s) => !s.isGranted)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Permission denied - cannot accept the call.')),
      );
      await _callingService.rejectCall(widget.call.callId);
      Navigator.of(context).pop();
      return;
    }

    setState(() => _responding = true);
    try {
      await _callingService.answerCall(widget.call.callId, widget.call.type);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => video
              ? VideoCallScreen(
                  callId: widget.call.callId,
                  callingService: _callingService,
                  isCaller: false,
                  peerName: widget.call.callerName,
                  peerPhotoUrl: widget.call.callerPhotoUrl,
                )
              : AudioCallScreen(
                  callId: widget.call.callId,
                  callingService: _callingService,
                  isCaller: false,
                  peerName: widget.call.callerName,
                  peerPhotoUrl: widget.call.callerPhotoUrl,
                ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to answer: $e')));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.call.type == CallType.video;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
            child: Column(
              children: [
                Text(
                  video ? 'Incoming Video Call' : 'Incoming Audio Call',
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const Spacer(),
                CircleAvatar(
                  radius: 64,
                  backgroundColor: Colors.white24,
                  backgroundImage: widget.call.callerPhotoUrl != null
                      ? NetworkImage(widget.call.callerPhotoUrl!)
                      : null,
                  child: widget.call.callerPhotoUrl == null
                      ? Text(
                          widget.call.callerName.isNotEmpty
                              ? widget.call.callerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 40, color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(height: 20),
                Text(
                  widget.call.callerName,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 26, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  video ? 'Video Call' : 'Audio Call',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RoundActionButton(
                      color: AppColors.danger,
                      icon: Icons.call_end,
                      label: 'Decline',
                      onTap: _responding ? null : _decline,
                    ),
                    _RoundActionButton(
                      color: AppColors.accent,
                      icon: video ? Icons.videocam : Icons.call,
                      label: 'Accept',
                      onTap: _responding ? null : _accept,
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

class _RoundActionButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _RoundActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
