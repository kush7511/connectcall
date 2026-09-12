import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../screens/call/audio_call_screen.dart';
import '../screens/call/video_call_screen.dart';
import 'calling_service.dart';
import 'package:provider/provider.dart';

/// Single place that knows how to start a call: request the right
/// permissions, create the Firestore/WebRTC call, and push the
/// correct call screen.
///
/// Every screen that can start a call - Contacts, the Home
/// dashboard's search/quick-call row, and "call back" from Call
/// History - now goes through this one method instead of each
/// re-implementing its own permission/navigation logic. That was
/// the "small change in making calls": previously only
/// ContactsScreen had this logic, so calling from anywhere else
/// wasn't possible/consistent.
class CallLauncher {
  CallLauncher._();

  static String cleanPhoneNumber(String value) {
    return value.replaceAll(RegExp(r'[^\d+]'), '');
  }

  static Future<void> callPhoneNumber(
    BuildContext context, {
    required String phoneNumber,
  }) async {
    final cleaned = cleanPhoneNumber(phoneNumber);
    if (cleaned.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid phone number.')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: cleaned);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No phone app is available on this device.')),
      );
    }
  }

  static Future<bool> _ensurePermissions(
      BuildContext context, bool video) async {
    final statuses = await [
      Permission.microphone,
      if (video) Permission.camera,
    ].request();

    final allGranted = statuses.values.every((s) => s.isGranted);
    if (allGranted) return true;

    final permanentlyDenied = statuses.values.any((s) => s.isPermanentlyDenied);
    if (!context.mounted) return false;

    if (permanentlyDenied) {
      final goToSettings = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Permission required'),
          content: Text(
              '${video ? "Camera and microphone" : "Microphone"} access is permanently denied. Enable it in Settings to make calls.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings')),
          ],
        ),
      );
      if (goToSettings == true) await openAppSettings();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '${video ? "Camera/microphone" : "Microphone"} permission is required to place a call.')),
      );
    }
    return false;
  }

  /// Starts a call to [other]. Safe to call from any screen -
  /// handles permissions, offline callees, and navigation.
  static Future<void> call(
    BuildContext context, {
    required UserModel other,
    required String type, // CallType.audio | CallType.video
  }) async {
    final video = type == CallType.video;
    final granted = await _ensurePermissions(context, video);
    if (!granted || !context.mounted) return;

    final auth = context.read<AuthProvider>();
    final me = auth.user;
    if (me == null) return;

    if (!other.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${other.name} is offline right now.')),
      );
      return;
    }

    final callingService = CallingService();
    try {
      final callId = await callingService.createCall(
        callerId: me.uid,
        callerName: me.displayName ?? 'Unknown',
        callerPhotoUrl: me.photoURL,
        calleeId: other.uid,
        calleeName: other.name,
        calleePhotoUrl: other.photoUrl,
        type: type,
      );
      if (!context.mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => video
              ? VideoCallScreen(
                  callId: callId,
                  callingService: callingService,
                  isCaller: true,
                  peerName: other.name,
                  peerPhotoUrl: other.photoUrl,
                )
              : AudioCallScreen(
                  callId: callId,
                  callingService: callingService,
                  isCaller: true,
                  peerName: other.name,
                  peerPhotoUrl: other.photoUrl,
                ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start call: $e')),
      );
    }
  }

  /// Bottom sheet with audio/video call buttons for [user] - used
  /// by Home dashboard search results and "call back" from history,
  /// so the user picks the call type from one consistent UI.
  static void showQuickCallSheet(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                backgroundImage:
                    user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?')
                    : null,
              ),
              const SizedBox(height: 12),
              Text(user.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600)),
              Text(user.isOnline ? 'Online' : 'Offline',
                  style: TextStyle(
                      color: user.isOnline
                          ? AppColors.online
                          : AppColors.offline)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _sheetAction(
                    sheetContext,
                    icon: Icons.call,
                    label: 'Audio Call',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      call(context, other: user, type: CallType.audio);
                    },
                  ),
                  _sheetAction(
                    sheetContext,
                    icon: Icons.videocam,
                    label: 'Video Call',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      call(context, other: user, type: CallType.video);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _sheetAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        Material(
          color: AppColors.primary.withValues(alpha: 0.1),
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Icon(icon, color: AppColors.primary, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label),
      ],
    );
  }
}
