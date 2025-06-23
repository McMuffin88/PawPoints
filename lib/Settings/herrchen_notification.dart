import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HerrchenNotifications extends StatelessWidget {
  const HerrchenNotifications({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Nicht angemeldet.'));
    }

    // Stream aller Notifications für dieses Herrchen
    final notificationsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Benachrichtigungen'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Keine Benachrichtigungen.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final type = data['type'] as String? ?? 'info';
              final title = data['title'] as String? ?? '';
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              final timeString = TimeOfDay.fromDateTime(timestamp).format(context);
              return ListTile(
                leading: Icon(
                  type == 'task' ? Icons.check_circle : Icons.shopping_bag,
                  color: type == 'task' ? Colors.green : Colors.blue,
                ),
                title: Text(title),
                subtitle: Text(timeString),
              );
            },
          );
        },
      ),
    );
  }
}
