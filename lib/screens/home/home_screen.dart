import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../services/calling_service.dart';
import '../contacts/contacts_screen.dart';
import '../history/call_history_screen.dart';
import '../profile/profile_screen.dart';
import '../call/incoming_call_screen.dart';
import 'home_dashboard_screen.dart';

/// Root authenticated screen: bottom nav across Home/Contacts/
/// Calls/Profile, plus a single global listener for incoming calls
/// so a ringing call can interrupt whichever tab the user is on.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final _callingService = CallingService();
  String? _handledCallId;

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;

    return StreamBuilder(
      stream: uid == null ? null : _callingService.incomingCallStream(uid),
      builder: (context, snapshot) {
        final call = snapshot.data;
        if (call != null && call.callId != _handledCallId) {
          _handledCallId = call.callId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context, rootNavigator: true)
                .push(
                  MaterialPageRoute(
                    builder: (_) => IncomingCallScreen(call: call),
                    fullscreenDialog: true,
                  ),
                )
                .then((_) => _handledCallId = null);
          });
        }

        return Scaffold(
          body: IndexedStack(
            index: _index,
            children: [
              HomeDashboardScreen(
                  onOpenContacts: () => setState(() => _index = 1)),
              const ContactsScreen(),
              const CallHistoryScreen(),
              const ProfileScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.dialpad_outlined),
                  selectedIcon: Icon(Icons.dialpad),
                  label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.contacts_outlined),
                  selectedIcon: Icon(Icons.contacts),
                  label: 'Contacts'),
              NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: 'Calls'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Profile'),
            ],
          ),
        );
      },
    );
  }
}

/// Kept for reference to the assignment's suggested nav labels
/// (Home / Contacts / Calls / Profile) - Contacts doubles as the
/// Home tab here since it already carries search + recents.
class HomeNavLabels {
  static const items = [AppConstants.appName, 'Contacts', 'Calls', 'Profile'];
}
