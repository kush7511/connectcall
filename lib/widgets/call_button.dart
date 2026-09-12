import 'package:flutter/material.dart';

/// Round icon button used for call controls (mute, speaker, camera,
/// switch camera, end call). `active` flips the fill so the user
/// can see at a glance whether mute/camera is currently on.
class CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool danger;

  const CallButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.activeColor,
    this.inactiveColor,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger
        ? Colors.red
        : active
            ? (activeColor ?? Colors.white)
            : (inactiveColor ?? Colors.white24);
    final fg = danger
        ? Colors.white
        : active
            ? Colors.black87
            : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(icon, color: fg, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
