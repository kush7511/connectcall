import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../widgets/common_button.dart';
import '../auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _userService = UserService();

  Future<void> _editProfile(UserModel current) async {
    final nameCtrl = TextEditingController(text: current.name);
    final phoneCtrl = TextEditingController(text: current.phoneNumber ?? '');
    final statusCtrl =
        TextEditingController(text: current.statusMessage ?? 'Available');
    final formKey = GlobalKey<FormState>();

    final updated = await showDialog<_ProfileEditResult>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.call_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: statusCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  prefixIcon: Icon(Icons.info_outline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  context,
                  _ProfileEditResult(
                    name: nameCtrl.text.trim(),
                    phoneNumber: phoneCtrl.text.trim(),
                    statusMessage: statusCtrl.text.trim(),
                  ),
                );
              },
              child: const Text('Save')),
        ],
      ),
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
    statusCtrl.dispose();

    if (updated == null) return;
    try {
      await _userService.updateProfile(
        uid: current.uid,
        name: updated.name,
        phoneNumber: updated.phoneNumber,
        statusMessage:
            updated.statusMessage.isEmpty ? 'Available' : updated.statusMessage,
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update profile: $e')),
      );
    }
  }

  Future<void> _logout() async {
    final auth = context.read<AuthProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log out')),
        ],
      ),
    );
    if (confirm != true) return;
    await auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    if (uid == null) return const SizedBox();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<UserModel?>(
        future: _userService.getUser(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text('Profile not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              fontSize: 32,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(user.name,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(user.email,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              if (user.statusMessage != null &&
                  user.statusMessage!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    user.statusMessage!,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          color: AppColors.online, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    const Text('Online',
                        style: TextStyle(color: AppColors.online)),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Card(
                elevation: 0,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.call_outlined),
                      title: const Text('Phone number'),
                      subtitle: Text(
                        user.phoneNumber == null || user.phoneNumber!.isEmpty
                            ? 'Not added'
                            : user.phoneNumber!,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('Email'),
                      subtitle: Text(user.email),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('User ID'),
                      subtitle: Text(user.uid),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              CommonButton(
                label: 'Edit Profile',
                icon: Icons.edit_outlined,
                onPressed: () => _editProfile(user),
              ),
              const SizedBox(height: 12),
              CommonButton(
                label: 'Logout',
                icon: Icons.logout,
                color: AppColors.danger,
                onPressed: _logout,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileEditResult {
  final String name;
  final String phoneNumber;
  final String statusMessage;

  const _ProfileEditResult({
    required this.name,
    required this.phoneNumber,
    required this.statusMessage,
  });
}
