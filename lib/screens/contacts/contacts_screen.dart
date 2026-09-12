import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/call_launcher.dart';
import '../../services/user_service.dart';
import '../../widgets/user_tile.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _userService = UserService();
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _startCall(UserModel other, String type) async {
    await CallLauncher.call(context, other: other, type: type);
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
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                              'Failed to load contacts.\n${snapshot.error}',
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
                            onTap: () =>
                                CallLauncher.showQuickCallSheet(context, user),
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
