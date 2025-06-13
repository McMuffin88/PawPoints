import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'mydoggys_screen.dart';

class DoggyBerechtigungenScreen extends StatelessWidget {
  const DoggyBerechtigungenScreen({super.key});

  Future<String> _loadInviteCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    return userDoc.data()?['inviteCode'] ?? '';
  }

  Widget _buildNoDoggysView(BuildContext context, String inviteCode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Du bist aktuell mit keinem Doggy verbunden.',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Bitte verwende deinen Einladungs- oder QR-Code, um die Verbindung herzustellen.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyDoggysScreen(inviteCode: inviteCode),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code),
              label: const Text('Zu Meine Doggys'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoggyList(QuerySnapshot snapshot, String herrchenId) {
    final doggys = snapshot.docs;
    if (doggys.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      itemCount: doggys.length,
      itemBuilder: (context, index) {
        final doc = doggys[index];
        final doggyId = doc.id;
        final data = doc.data() as Map<String, dynamic>;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(doggyId)
              .collection('assignedHerrchen')
              .doc(herrchenId)
              .get(),
          builder: (context, permissionSnapshot) {
            if (!permissionSnapshot.hasData) return const SizedBox.shrink();
            final permissions = permissionSnapshot.data!.data() as Map<String, dynamic>? ?? {};

            return Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: data['profileImageUrl'] != null
                            ? NetworkImage(data['profileImageUrl'])
                            : null,
                        child: data['profileImageUrl'] == null ? const Icon(Icons.pets) : null,
                      ),
                      title: Text(data['name'] ?? 'Unbenannt'),
                      subtitle: Text('Status: ${permissions['status'] ?? 'aktiv'}'),
                    ),
                    const Divider(),
                    _buildSwitch(
                      context,
                      doggyId,
                      herrchenId,
                      'tasksAddAllowed',
                      permissions['tasksAddAllowed'] ?? false,
                      'Darf Aufgaben, Belohnungen & Bestrafungen hinzufügen',
                    ),
                    _buildSwitch(
                      context,
                      doggyId,
                      herrchenId,
                      'tasksEditAllowed',
                      permissions['tasksEditAllowed'] ?? false,
                      'Darf Aufgaben, Belohnungen & Bestrafungen bearbeiten/löschen',
                    ),
                    _buildSwitch(
                      context,
                      doggyId,
                      herrchenId,
                      'rulesEditAllowed',
                      permissions['rulesEditAllowed'] ?? false,
                      'Darf Regeln ändern',
                    ),
                    _buildSwitch(
                      context,
                      doggyId,
                      herrchenId,
                      'notesEditAllowed',
                      permissions['notesEditAllowed'] ?? false,
                      'Darf Ideen, Notizen oder Wünsche ändern',
                    ),
                    _buildSwitch(
                      context,
                      doggyId,
                      herrchenId,
                      'historyEditAllowed',
                      permissions['historyEditAllowed'] ?? false,
                      'Darf Aufgabenverlauf ändern',
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSwitch(BuildContext context, String doggyId, String herrchenId,
      String fieldName, bool currentValue, String label) {
    return SwitchListTile(
      title: Text(label),
      value: currentValue,
      onChanged: (val) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(doggyId)
            .collection('assignedHerrchen')
            .doc(herrchenId)
            .update({fieldName: val});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Nicht eingeloggt')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Berechtigungen')),
      body: FutureBuilder<String>(
        future: _loadInviteCode(),
        builder: (context, inviteSnapshot) {
          if (!inviteSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final inviteCode = inviteSnapshot.data!;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('doggys')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.data!.docs.isEmpty) {
                return _buildNoDoggysView(context, inviteCode);
              }

              return _buildDoggyList(snapshot.data!, user.uid);
            },
          );
        },
      ),
    );
  }
}
