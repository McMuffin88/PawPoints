// lib/doggy_shop_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'doggy_drawer.dart'; // Pfad ggf. anpassen

class DoggyShopScreen extends StatelessWidget {
  const DoggyShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Nicht angemeldet.')),
      );
    }

    // Stream für das User-Dokument (Name, Punkte, Profilbild)
    final userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots();

    // Stream für *alle* Rewards in der Subcollection, nur active==true
final rewardsStream = FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .collection('rewards')
    .where('visibleToDoggy', isEqualTo: true)  // ← hier filtern
    .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doggy-Shop'),
        actions: [
          Builder(
            builder: (ctx) => StreamBuilder<DocumentSnapshot>(
              stream: userDocStream,
              builder: (ctx, userSnap) {
                if (!userSnap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final data = userSnap.data!.data() as Map<String, dynamic>? ?? {};
                final imageUrl = data['profileImageUrl'] as String?;
                if (imageUrl != null && imageUrl.startsWith('http')) {
                  return IconButton(
                    icon: CircleAvatar(backgroundImage: NetworkImage(imageUrl)),
                    onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                  );
                }
                final name = (data['name'] as String?) ?? 'D';
                return IconButton(
                  icon: CircleAvatar(child: Text(name[0].toUpperCase())),
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                );
              },
            ),
          )
        ],
      ),
      endDrawer: buildDoggyDrawer(context),
      body: StreamBuilder<DocumentSnapshot>(
        stream: userDocStream,
        builder: (ctx, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
          final doggyName = userData['name'] as String? ?? 'Doggy';
          final points = userData['points'] as int? ?? 0;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Punkteanzeige
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stars, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Text(
                      'Punkte: $points',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Belohnungen-Liste
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: rewardsStream,
                    builder: (ctx, rewardsSnap) {
                      if (rewardsSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = rewardsSnap.data?.docs ?? [];
                      // Debug-Log in Konsole:
                      debugPrint('Rewards geladen: ${docs.length}');
                      if (docs.isEmpty) {
                        return const Center(child: Text('Keine Belohnungen verfügbar.'));
                      }
                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (ctx, i) {
                        final r = docs[i].data() as Map<String, dynamic>;
                        final visible = r['visibleToDoggy'] as bool? ?? false;
                        final title = r['title'] as String? ?? '';
                        final desc = r['description'] as String? ?? '';
                        final cost = r['points'] as int? ?? 0;
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('$desc\nKosten: $cost Punkte'),
                              isThreeLine: true,
trailing: ElevatedButton(
  onPressed: points >= cost
    ? () async {
        final uid = user.uid;
        final rewardId = docs[i].id;
        print('Versuche, Reward $rewardId für User $uid zu markieren…');

        try {
// 1) Punkte abziehen
await FirebaseFirestore.instance
  .collection('users')
  .doc(uid)
  .update({'points': FieldValue.increment(-cost)});

// 2) Purchase-Historie anlegen
await FirebaseFirestore.instance
  .collection('users')
  .doc(uid)
  .collection('rewards')
  .doc(rewardId)                    // Reward-Dokument
  .collection('purchases')         // ← hier einhängen
  .add({                            // ... und dann add()
    'timestamp': FieldValue.serverTimestamp(),
    'cost': cost,
  });
          
          print('assignedAsReward erfolgreich gesetzt für $rewardId');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('„$title“ eingelöst!')),
          );
        } catch (e, st) {
          print('Fehler beim Markieren von $rewardId: $e');
          print(st);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fehler: $e')),
          );
        }
      }
    : null,
  child: const Text('Einlösen'),
),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

