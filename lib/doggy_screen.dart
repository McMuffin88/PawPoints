import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/Drawer_Doggy/doggy_drawer.dart';
import '/Start/update.dart';

// ICON-MAP HINZUFÜGEN
final Map<String, IconData> iconMap = {
  'star': Icons.star,
  'favorite': Icons.favorite,
  'home': Icons.home,
  'pets': Icons.pets,
  'check': Icons.check,
  'shopping_cart': Icons.shopping_cart,
  'reward': Icons.card_giftcard,
  // beliebig erweitern!
};

class DoggyScreen extends StatefulWidget {
  // NEU: Callback-Funktion, um den Tab zu wechseln
  final VoidCallback? onProfileTap;

  const DoggyScreen({super.key, this.onProfileTap});

  @override
  State<DoggyScreen> createState() => _DoggyScreenState();
}

class _DoggyScreenState extends State<DoggyScreen> {
  String _doggyName = 'Doggy';

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      InitService.runOncePerAppStart();
    });

    _loadDoggyFirebaseData();
    _listenToPointChanges();
    _setupFirebaseMessaging();
  }

  /// 1) Einmaliges Laden von Name, Bild und Punkten
  Future<void> _loadDoggyFirebaseData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    if (data == null) return;
    setState(() {
      _doggyName = data['benutzername'] as String? ?? 'Doggy';
    });
  }

  void _listenToPointChanges() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      final newPoints = data['points'] as int? ?? 0;
      final timestamp = DateTime.now();
      final timeStr =
          '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
      print('🛠️ [DEBUG][$timeStr] Neuer Punkte-Stand: $newPoints');
    });
  }

  void _setupFirebaseMessaging() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseMessaging.instance.getToken().then((token) {
      if (token != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('fcmTokens')
            .doc(token)
            .set({'createdAt': FieldValue.serverTimestamp()});
        print('🔑 [DEBUG] FCM-Token gespeichert: $token');
      }
    });

    FirebaseMessaging.onMessage.listen((msg) {
      final t = msg.notification?.title ?? 'Info';
      final b = msg.notification?.body ?? '';
      print('🔔 [FCM] $t — $b');
    });
  }

  Widget _buildProfileIcon(Map<String, dynamic> userData, BuildContext ctx) {
    final imageUrl = userData['profileImageUrl'] as String?;
    if (imageUrl != null && imageUrl.startsWith('http')) {
      return CircleAvatar(backgroundImage: NetworkImage(imageUrl));
    } else {
      final name = (userData['benutzername'] as String?) ?? 'D';
      return CircleAvatar(child: Text(name[0].toUpperCase()));
    }
  }

  Future<void> _confirmAndCompleteTask(
    DocumentSnapshot taskDoc,
    DateTime instanceDate,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aufgabe abschließen?'),
        content:
            const Text('Bist du sicher, dass du diese Aufgabe erledigt hast?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Abbrechen')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ja')),
        ],
      ),
    );
    if (confirmed != true) return;

    await taskDoc.reference.collection('completions').add({
      'timestamp': Timestamp.now(),
      'instanceDate': instanceDate.toIso8601String(),
    });
    print('✅ [DEBUG] Completion angelegt für Aufgabe ${taskDoc.id}');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Nicht angemeldet.')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (ctx, userSnap) {
        if (!userSnap.hasData || userSnap.data?.data() == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final userData = userSnap.data!.data()! as Map<String, dynamic>;
        final points = userData['points'] as int? ?? 0;

        return Scaffold(
          appBar: AppBar(
            title: Text('Doggy-Aufgaben ($_doggyName)'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu), // Burger-Menü Icon
                onPressed: () => Scaffold.of(context).openDrawer(), // Öffnet den Start-Drawer
              ),
            ),
            actions: [
              Builder(
                builder: (context) => IconButton(
                  icon: _buildProfileIcon(userData, ctx),
                  onPressed: () {
                    print('🐾 DoggyScreen: Profil-Icon geklickt!'); // Debug-Ausgabe
                    widget.onProfileTap?.call();
                  },
                ),
              )
            ],
          ),
          drawer: buildDoggyDrawer(context), // Dies ist der "Start"-Drawer
          endDrawer: buildDoggyDrawer(context), // Dies ist der "End"-Drawer (optional, wenn gewünscht)
          body: _buildTaskList(points),
        );
      },
    );
  }

  /// 6) Komplette Task-Liste mit allen alten Features
  Widget _buildTaskList(int points) {
    final user = FirebaseAuth.instance.currentUser!;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final cutoffDate = startOfDay.subtract(const Duration(days: 1));
    final endBoundary = startOfDay.add(const Duration(days: 30));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text('Keine offenen Aufgaben.'));
        }
        final docs = snap.data!.docs;
        final instances = <Map<String, dynamic>>[];

        for (var doc in docs) {
          final data = doc.data()! as Map<String, dynamic>;
          final dueDate = DateTime.tryParse(data['due'] ?? '');
          final dueTimeStr = data['dueTime'] as String?;

          DateTime? fullDateTime;
          if (dueDate != null) {
            if (dueTimeStr != null) {
              final timeParts = dueTimeStr.split(':');
              if (timeParts.length == 2) {
                final hour = int.tryParse(timeParts[0]) ?? 0;
                final minute = int.tryParse(timeParts[1]) ?? 0;
                fullDateTime = DateTime(
                  dueDate.year,
                  dueDate.month,
                  dueDate.day,
                  hour,
                  minute,
                );
              } else {
                fullDateTime = dueDate;
              }
            } else {
              fullDateTime = dueDate;
            }
          }
          if (fullDateTime == null) continue;

          final repeat = data['repeat'];
          if (repeat == null) {
            if (fullDateTime.isAfter(cutoffDate))
              instances.add({'doc': doc, 'date': fullDateTime});
          } else {
            var current = fullDateTime;
            while (current.isBefore(endBoundary)) {
              if (current.isBefore(cutoffDate)) {
                break;
              }
              if (current.isAfter(cutoffDate))
                instances.add({'doc': doc, 'date': current});
              if (repeat == 'weekly') {
                current = current.add(const Duration(days: 7));
              } else if (repeat == 'monthly')
                current = DateTime(current.year, current.month + 1, current.day);
              else if (repeat.startsWith('every_')) {
                final days =
                    int.tryParse(repeat.replaceFirst('every_', '')) ?? 1;
                current = current.add(Duration(days: days));
              } else
                break;
            }
          }
        }

        instances
            .sort((a, b) => (a['date'] as DateTime).compareTo(a['date'] as DateTime));
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stars, color: Colors.amber.shade800),
                  const SizedBox(width: 8),
                  Text('Punkte: $points',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: instances.length,
                itemBuilder: (ctx, i) {
                  final doc = instances[i]['doc'] as DocumentSnapshot;
                  final date = instances[i]['date'] as DateTime;
                  final data = doc.data()! as Map<String, dynamic>;
                  final dateStr = DateFormat('dd.MM.yyyy').format(date);
                  final timeStr = DateFormat('HH:mm').format(date);
                  final repeat = data['repeat'];
                  final repeatText = repeat == null
                      ? 'einmalig'
                      : repeat == 'weekly'
                          ? 'wöchentlich'
                          : repeat == 'monthly'
                              ? 'monatlich'
                              : repeat.startsWith('every_')
                                  ? 'alle ${repeat.split('_')[1]} Tage'
                                  : 'einmalig';
                  final limit =
                      int.tryParse(data['limitValue']?.toString() ?? '') ?? 0;
                  final type = data['frequencyLimit'];
                  final freqText = type == 'mindestens'
                      ? 'Mindestens $limit×'
                      : type == 'höchstens'
                          ? 'Höchstens $limit×'
                          : null;

                  final String? iconKey = data['icon'];
                  final IconData icon =
                      iconKey != null && iconMap.containsKey(iconKey)
                          ? iconMap[iconKey]!
                          : Icons.pets;

                  return FutureBuilder<QuerySnapshot>(
                    future: doc.reference
                        .collection('completions')
                        .where('instanceDate', isEqualTo: date.toIso8601String())
                        .get(),
                    builder: (ctx, s) {
                      final done = s.data?.docs.length ?? 0;
                      final progress =
                          limit > 0 ? (done / limit).clamp(0.0, 1.0) : 0.0;
                      final expired = date.isBefore(startOfDay);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.brown.shade100,
                            child: Icon(icon, color: Colors.brown.shade800),
                          ),
                          title: Text(data['title'] ?? '',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  'Fällig: $dateStr – $timeStr – $repeatText${freqText != null ? ' – $freqText' : ''}'),
                              if (limit > 0 && type != 'beliebig') ...[
                                Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    child:
                                        LinearProgressIndicator(value: progress)),
                                Text('Heute: $done/$limit×'),
                              ],
                              if (expired && done == 0)
                                const Text('Frist abgelaufen',
                                    style: TextStyle(color: Colors.red)),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: (expired ||
                                    (type == 'höchstens' && done >= limit))
                                ? null
                                : () => _confirmAndCompleteTask(doc, date),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
