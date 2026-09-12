import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/direct_contact_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/call_launcher.dart';
import '../../services/direct_contact_service.dart';
import '../../services/user_service.dart';

class HomeDashboardScreen extends StatefulWidget {
  final VoidCallback onOpenContacts;

  const HomeDashboardScreen({
    super.key,
    required this.onOpenContacts,
  });

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final _dialCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _userService = UserService();
  final _directContactService = DirectContactService();
  String _query = '';

  @override
  void dispose() {
    _dialCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _showContactDialog({
    DirectContactModel? contact,
    String? initialPhoneNumber,
  }) async {
    final nameCtrl = TextEditingController(text: contact?.name ?? '');
    final phoneCtrl = TextEditingController(
      text: contact?.phoneNumber ?? initialPhoneNumber ?? '',
    );
    final noteCtrl = TextEditingController(text: contact?.note ?? '');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<_ContactFormResult>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(contact == null ? 'Add Contact' : 'Edit Contact'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a name'
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
                validator: (value) {
                  final cleaned = CallLauncher.cleanPhoneNumber(value ?? '');
                  return cleaned.length < 3 ? 'Enter a valid number' : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Label',
                  prefixIcon: Icon(Icons.label_outline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(
                context,
                _ContactFormResult(
                  name: nameCtrl.text.trim(),
                  phoneNumber: phoneCtrl.text.trim(),
                  note: noteCtrl.text.trim(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    nameCtrl.dispose();
    phoneCtrl.dispose();
    noteCtrl.dispose();

    if (!mounted) return;
    final uid = context.read<AuthProvider>().user?.uid;
    if (result == null || uid == null) return;

    try {
      if (contact == null) {
        await _directContactService.addContact(
          uid: uid,
          name: result.name,
          phoneNumber: result.phoneNumber,
          note: result.note,
        );
      } else {
        await _directContactService.updateContact(
          uid: uid,
          contactId: contact.id,
          name: result.name,
          phoneNumber: result.phoneNumber,
          note: result.note,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save contact: $e')),
      );
    }
  }

  Future<void> _deleteContact(DirectContactModel contact) async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Remove ${contact.name} from your contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _directContactService.deleteContact(
        uid: uid,
        contactId: contact.id,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete contact: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = context.watch<AuthProvider>().user;
    final uid = authUser?.uid;
    final firstName = authUser?.displayName?.trim().split(' ').first;

    return Scaffold(
      appBar: AppBar(
        title: Text(firstName == null || firstName.isEmpty
            ? AppConstants.appName
            : 'Hi, $firstName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'Add contact',
            onPressed: () => _showContactDialog(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showContactDialog(),
        tooltip: 'Add contact',
        child: const Icon(Icons.add_call),
      ),
      body: uid == null
          ? const SizedBox()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                _DialPadCard(
                  controller: _dialCtrl,
                  onCall: () => CallLauncher.callPhoneNumber(
                    context,
                    phoneNumber: _dialCtrl.text,
                  ),
                  onSave: () {
                    final number = _dialCtrl.text.trim();
                    if (number.isNotEmpty) {
                      _showContactDialog(initialPhoneNumber: number);
                    } else {
                      _showContactDialog();
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search contacts or numbers',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: 20),
                _SectionHeader(
                  title: 'Saved Contacts',
                  actionLabel: 'Add',
                  onAction: () => _showContactDialog(),
                ),
                StreamBuilder<List<DirectContactModel>>(
                  stream: _directContactService.contactsStream(uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const _LoadingTile();
                    }
                    if (snapshot.hasError) {
                      return const _MessageTile(
                        icon: Icons.error_outline,
                        text: 'Could not load saved contacts.',
                        color: AppColors.danger,
                      );
                    }
                    final contacts = _directContactService.filter(
                        snapshot.data ?? [], _query);
                    if (contacts.isEmpty) {
                      return const _MessageTile(
                        icon: Icons.contact_phone_outlined,
                        text: 'No saved phone contacts yet.',
                      );
                    }
                    return Column(
                      children: contacts
                          .map(
                            (contact) => _DirectContactTile(
                              contact: contact,
                              onCall: () => CallLauncher.callPhoneNumber(
                                context,
                                phoneNumber: contact.phoneNumber,
                              ),
                              onEdit: () =>
                                  _showContactDialog(contact: contact),
                              onDelete: () => _deleteContact(contact),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
                _SectionHeader(
                  title: 'ConnectCall Users',
                  actionLabel: 'All',
                  onAction: widget.onOpenContacts,
                ),
                StreamBuilder<List<UserModel>>(
                  stream: _userService.contactsStream(uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const _LoadingTile();
                    }
                    if (snapshot.hasError) {
                      return const _MessageTile(
                        icon: Icons.error_outline,
                        text: 'Could not load app users.',
                        color: AppColors.danger,
                      );
                    }
                    final users =
                        _userService.filter(snapshot.data ?? [], _query);
                    if (users.isEmpty) {
                      return const _MessageTile(
                        icon: Icons.people_outline,
                        text: 'No matching app users.',
                      );
                    }
                    final preview =
                        users.length > 4 ? users.sublist(0, 4) : users;
                    return Column(
                      children: preview
                          .map(
                            (user) => _AppUserQuickTile(
                              user: user,
                              onTap: () => CallLauncher.showQuickCallSheet(
                                  context, user),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _DialPadCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onCall;
  final VoidCallback onSave;

  const _DialPadCard({
    required this.controller,
    required this.onCall,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                hintText: 'Enter phone number',
                prefixIcon: Icon(Icons.dialpad),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onCall,
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

class _DirectContactTile extends StatelessWidget {
  final DirectContactModel contact;
  final VoidCallback onCall;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DirectContactTile({
    required this.contact,
    required this.onCall,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.accent.withValues(alpha: 0.16),
          child: Text(
            contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '#',
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          contact.name.isEmpty ? contact.phoneNumber : contact.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          contact.note == null || contact.note!.isEmpty
              ? contact.phoneNumber
              : '${contact.phoneNumber} • ${contact.note}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.call, color: AppColors.accent),
              tooltip: 'Call',
              onPressed: onCall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppUserQuickTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const _AppUserQuickTile({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          backgroundImage:
              user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
          child: user.photoUrl == null
              ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?')
              : null,
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(user.isOnline ? 'Online' : 'Offline'),
        trailing: IconButton(
          icon: const Icon(Icons.call_outlined, color: AppColors.primary),
          tooltip: 'Call',
          onPressed: onTap,
        ),
      ),
    );
  }
}

class _LoadingTile extends StatelessWidget {
  const _LoadingTile();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _MessageTile({
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.outline;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, color: effectiveColor),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        ),
      ),
    );
  }
}

class _ContactFormResult {
  final String name;
  final String phoneNumber;
  final String? note;

  const _ContactFormResult({
    required this.name,
    required this.phoneNumber,
    this.note,
  });
}
