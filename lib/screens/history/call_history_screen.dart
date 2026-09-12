import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/call_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/call_history_service.dart';

class CallHistoryScreen extends StatelessWidget {
  const CallHistoryScreen({super.key});

  String _formatWhen(DateTime dt) {
    final now = DateTime.now();
    final isToday =
        dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day;

    final time = DateFormat('h:mm a').format(dt);
    if (isToday) return 'Today, $time';
    if (isYesterday) return 'Yesterday, $time';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid;
    final service = CallHistoryService();

    return Scaffold(
      appBar: AppBar(title: const Text('Call History')),
      body: uid == null
          ? const SizedBox()
          : StreamBuilder<List<CallModel>>(
              stream: service.historyStream(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                        'Failed to load call history.\n${snapshot.error}',
                        textAlign: TextAlign.center),
                  );
                }
                final calls = snapshot.data ?? [];
                if (calls.isEmpty) {
                  return const Center(child: Text('No calls yet.'));
                }

                return ListView.separated(
                  itemCount: calls.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final call = calls[i];
                    final outgoing = call.isOutgoing(uid);
                    final peerName =
                        outgoing ? call.calleeName : call.callerName;
                    final peerPhoto =
                        outgoing ? call.calleePhotoUrl : call.callerPhotoUrl;
                    final missed = call.isMissed && !outgoing;
                    final videoCall = call.type == CallType.video;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.15),
                        backgroundImage:
                            peerPhoto != null ? NetworkImage(peerPhoto) : null,
                        child: peerPhoto == null
                            ? Text(peerName.isNotEmpty
                                ? peerName[0].toUpperCase()
                                : '?')
                            : null,
                      ),
                      title: Text(peerName,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: missed ? AppColors.danger : null)),
                      subtitle: Row(
                        children: [
                          Icon(
                            outgoing
                                ? Icons.call_made
                                : missed
                                    ? Icons.call_missed
                                    : Icons.call_received,
                            size: 14,
                            color: missed ? AppColors.danger : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(_formatWhen(call.createdAt)),
                        ],
                      ),
                      trailing: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(videoCall ? Icons.videocam : Icons.call,
                              size: 18, color: AppColors.primary),
                          const SizedBox(height: 4),
                          Text(
                            call.isMissed
                                ? 'Missed'
                                : _formatDuration(call.durationSeconds),
                            style: TextStyle(
                                fontSize: 12,
                                color: missed ? AppColors.danger : Colors.grey),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
