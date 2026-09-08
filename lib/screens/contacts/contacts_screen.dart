import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/calling_service.dart';
import '../../services/user_service.dart';
import '../../widgets/user_tile.dart';
import '../call/audio_call_screen.dart';
import '../call/video_call_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _userService = UserService();
  final _callingService = CallingService();
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Requests mic (and camera, for video) permission before
  /// starting a call, and gracefully handles denial / permanent
  /// denial (Permissions requirement).
  Future<bool> _ensurePermissions(bool video) async {
    final statuses = await [
      Permission.microphone,
      if (video) Permission.camera,
    ].request();

    final denied = statuses.values.any((s) => !s.isGranted);
    if (!denied) return true;

    final permanentlyDenied =
        statuses.values.any((s) => s.isPermanentlyDenied);

    if (!mounted) return false;
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

  Future<void> _startCall(UserModel other, String type) async {
    final video = type == CallType.video;
    final granted = await _ensurePermissions(video);
    if (!granted || !mounted) return;

    final auth = context.read<AuthProvider>();
    final me = auth.user;
    if (me == null) return;

    if (!other.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${other.name} is offline right now.')),
      );
      return;
    }

    try {
      final callId = await _callingService.createCall(
        callerId: me.uid,
        callerName: me.displayName ?? 'Unknown',
        callerPhotoUrl: me.photoURL,
        calleeId: other.uid,
        calleeName: other.name,
        calleePhotoUrl: other.photoUrl,
        type: type,
      );
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => video
              ? VideoCallScreen(
                  callId: callId,
                  callingService: _callingService,
                  isCaller: true,
                  peerName: other.name,
                  peerPhotoUrl: other.photoUrl,
                )
              : AudioCallScreen(
                  callId: callId,
                  callingService: _callingService,
                  isCaller: true,
                  peerName: other.name,
                  peerPhotoUrl: other.photoUrl,
                ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start call: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {}, // handled by bottom nav Profile tab
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search people...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: uid == null
                ? const SizedBox()
                : StreamBuilder<List<UserModel>>(
                    stream: _userService.contactsStream(uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Failed to load contacts.\n${snapshot.error}',
                              textAlign: TextAlign.center),
                        );
                      }
                      final all = snapshot.data ?? [];
                      final users = _userService.filter(all, _query);

                      if (users.isEmpty) {
                        return Center(
                          child: Text(
                            all.isEmpty
                                ? 'No other users yet. Invite someone to join!'
                                : 'No results for "$_query"',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, i) {
                          final user = users[i];
                          return UserTile(
                            user: user,
                            onAudioCall: () => _startCall(user, CallType.audio),
                            onVideoCall: () => _startCall(user, CallType.video),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
