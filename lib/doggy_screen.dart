import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '/Drawer_Doggy/doggy_drawer.dart';
import '/Start/update.dart';
import 'dart:async';

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

  Future<void> _loadDoggyFirebaseData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return;
    setState(() {
      _doggyName = data['benutzername'] as String? ?? 'Doggy';
    });
  }

  void _listenToPointChanges() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      final newPoints = data['points'] as int? ?? 0;
      final timestamp = DateTime.now();
      final timeStr = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
      print('🛠️ [DEBUG][$timeStr] Neuer Punkte-Stand: $newPoints');
    });
  }

  void _setupFirebaseMessaging() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    FirebaseMessaging.instance.getToken().then((token) {
      if (token != null) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).collection('fcmTokens').doc(token).set({'createdAt': FieldValue.serverTimestamp()});
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

Future<void> _confirmAndCompleteTask(DocumentSnapshot taskDoc, DateTime instanceDate) async {
  final scaffold = ScaffoldMessenger.of(context);
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Aufgabe abschließen?'),
      content: const Text('Bist du sicher, dass du diese Aufgabe erledigt hast?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ja')),
      ],
    ),
  );
  if (confirmed != true) return;

  scaffold.hideCurrentSnackBar();
  scaffold.showSnackBar(
    const SnackBar(content: Text('Aufgabe wird abgeschlossen...')),
  );

  await taskDoc.reference.collection('completions').add({
    'timestamp': Timestamp.now(),
    'instanceDate': instanceDate.toIso8601String(),
  });

  // Warte bis Punkte aktualisiert wurden oder Timeout
  final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  final userSnap = await userRef.get();
  final initialPoints = (userSnap.data()?['points'] ?? 0) as int;

  bool pointsChanged = false;
  try {
    await userRef.snapshots()
      .firstWhere((snap) {
        final newPoints = snap.data()?['points'] ?? 0;
        return newPoints > initialPoints;
      }).timeout(const Duration(seconds: 5));
    pointsChanged = true;
  } on TimeoutException {
    pointsChanged = false;
  }

  scaffold.hideCurrentSnackBar();

  if (pointsChanged) {
    scaffold.showSnackBar(
      const SnackBar(content: Text('Aufgabe erfolgreich abgeschlossen!')),
    );
  } else {
    scaffold.showSnackBar(
      const SnackBar(content: Text('Aufgabe abgeschlossen, aber Punkte noch nicht aktualisiert.')),
    );
  }
}



  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Nicht angemeldet.')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (ctx, userSnap) {
        if (!userSnap.hasData || userSnap.data?.data() == null) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final userData = userSnap.data!.data()! as Map<String, dynamic>;
        final points = userData['points'] as int? ?? 0;
        final String? favoriteColorName = userData['favoriteColor'];
        final Color favoriteColor = (favoriteColorName != null && colorMap.containsKey(favoriteColorName))
            ? colorMap[favoriteColorName]!
            : Colors.brown;
        final doggyId = user.uid;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(doggyId).collection('assignedHerrchen').snapshots(),
          builder: (ctx, herrchenSnap) {
            if (!herrchenSnap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (herrchenSnap.data!.docs.isEmpty) {
              return Scaffold(
                appBar: AppBar(
                  title: const Text('Dein persönlicher Newsfeed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  centerTitle: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Chip(
                        avatar: const Icon(Icons.stars, color: Colors.white, size: 20),
                        label: Text('${userData['points'] ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        backgroundColor: favoriteColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    Builder(
                      builder: (context) => IconButton(
                        icon: _buildProfileIcon(userData, ctx),
                        onPressed: () {
                          widget.onProfileTap?.call();
                        },
                      ),
                    ),
                  ],
                ),
                drawer: buildDoggyDrawer(context),
                endDrawer: buildDoggyDrawer(context),
                body: const Center(child: Text('Kein Herrchen zugeordnet.')),
              );
            }
            final herrchenDoc = herrchenSnap.data!.docs.first;
            final herrchenId = herrchenDoc.id;

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(herrchenId).collection('doggys').doc(doggyId).snapshots(),
              builder: (context, permSnap) {
                if (!permSnap.hasData || !permSnap.data!.exists) {
                  return const Center(child: CircularProgressIndicator());
                }
                final dataMap = permSnap.data!.data() as Map<String, dynamic>? ?? {};
                final canCompleteTasks = dataMap['canCompleteTasks'] == true;

                return Scaffold(
                  appBar: AppBar(
                    title: const Text('Dein persönlicher Newsfeed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    centerTitle: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Chip(
                          avatar: const Icon(Icons.stars, color: Colors.white, size: 20),
                          label: Text('${userData['points'] ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          backgroundColor: favoriteColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                      Builder(
                        builder: (context) => IconButton(
                          icon: _buildProfileIcon(userData, ctx),
                          onPressed: () {
                            widget.onProfileTap?.call();
                          },
                        ),
                      ),
                    ],
                  ),
                  drawer: buildDoggyDrawer(context),
                  endDrawer: buildDoggyDrawer(context),
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildNotificationsSection(doggyId),
                      const Divider(height: 30, thickness: 2),
                      Expanded(child: _buildTaskList(points, canCompleteTasks, favoriteColor)),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationsSection(String doggyId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(doggyId).collection('notifications').orderBy('timestamp', descending: true).snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                "Keine Benachrichtigungen.",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.withOpacity(0.6),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final system = <QueryDocumentSnapshot>[];
        final user = <QueryDocumentSnapshot>[];
        final punishments = <QueryDocumentSnapshot>[];
        final other = <QueryDocumentSnapshot>[];

        for (var doc in snap.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          switch (data['type']) {
            case 'system':
              system.add(doc);
              break;
            case 'user':
              user.add(doc);
              break;
            case 'punishment':
              punishments.add(doc);
              break;
            default:
              other.add(doc);
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Benachrichtigungen", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (system.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, bottom: 2),
                  child: Text("Systemnachrichten:", style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                ...system.map((doc) => _buildNotificationTile(doc)),
              ],
              if (user.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, bottom: 2),
                  child: Text("Von Nutzern:", style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                ...user.map((doc) => _buildNotificationTile(doc)),
              ],
              if (punishments.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, bottom: 2),
                  child: Text("Bestrafungen:", style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
                ),
                ...punishments.map((doc) => _buildNotificationTile(doc)),
              ],
              if (other.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, bottom: 2),
                  child: Text("Weitere:", style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                ...other.map((doc) => _buildNotificationTile(doc)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNotificationTile(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ListTile(
      leading: Icon(Icons.notifications, color: Colors.blue.shade400),
      title: Text(data['title'] ?? 'Benachrichtigung'),
      subtitle: Text(data['message'] ?? ''),
      dense: true,
      trailing: data['timestamp'] != null ? Text(DateFormat('dd.MM.yyyy HH:mm').format((data['timestamp'] as Timestamp).toDate())) : null,
    );
  }

  Widget _buildTaskList(int points, bool canCompleteTasks, Color favoriteColor) {
    final user = FirebaseAuth.instance.currentUser!;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final cutoffDate = startOfDay.subtract(const Duration(days: 1));
    final endBoundary = startOfDay.add(const Duration(days: 30));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('tasks').orderBy('createdAt', descending: true).snapshots(),
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
                fullDateTime = DateTime(dueDate.year, dueDate.month, dueDate.day, hour, minute);
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
            if (fullDateTime.isAfter(cutoffDate)) instances.add({'doc': doc, 'date': fullDateTime});
          } else {
            var current = fullDateTime;
            while (current.isBefore(endBoundary)) {
              if (current.isBefore(cutoffDate)) break;
              if (current.isAfter(cutoffDate)) instances.add({'doc': doc, 'date': current});
              if (repeat == 'weekly') {
                current = current.add(const Duration(days: 7));
              } else if (repeat == 'monthly') {
                current = DateTime(current.year, current.month + 1, current.day);
              } else if (repeat.startsWith('every_')) {
                final days = int.tryParse(repeat.replaceFirst('every_', '')) ?? 1;
                current = current.add(Duration(days: days));
              } else {
                break;
              }
            }
          }
        }

        instances.sort((a, b) => (a['date'] as DateTime).compareTo(a['date'] as DateTime));
        return ListView.builder(
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
            final limit = int.tryParse(data['limitValue']?.toString() ?? '') ?? 0;
            final type = data['frequencyLimit'];
            final freqText = type == 'mindestens'
                ? 'Mindestens $limit×'
                : type == 'höchstens'
                    ? 'Höchstens $limit×'
                    : null;

            final String? iconKey = data['icon'];
            final IconData icon = iconKey != null && iconMap.containsKey(iconKey) ? iconMap[iconKey]! : Icons.pets;

            return FutureBuilder<QuerySnapshot>(
              future: doc.reference.collection('completions').where('instanceDate', isEqualTo: date.toIso8601String()).get(),
              builder: (ctx, s) {
                final done = s.data?.docs.length ?? 0;
                final expired = date.isBefore(startOfDay);

                return Card(
                  elevation: 6,
                  color: Colors.grey.shade900,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: Icon(icon, color: Colors.blue, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: favoriteColor,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Text('zu erledigen bis: $dateStr, $timeStr',
                                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ),
                                  const SizedBox(width: 7),
                                  if (repeatText.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: favoriteColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(repeatText,
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                    ),
                                  if (freqText != null) ...[
                                    const SizedBox(width: 7),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: favoriteColor,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(freqText,
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),

                        Row(
                          children: [
                            if (limit > 0 && type != 'beliebig')
                              Row(
                                children: List.generate(
                                  limit,
                                  (index) => Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: CircleAvatar(
                                      radius: 11,
                                      backgroundColor: index < done ? Colors.white : Colors.grey.shade300,
                                      child: Icon(
                                        Icons.pets,
                                        size: 16,
                                        color: index < done ? favoriteColor : Colors.grey.shade400,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (type == 'beliebig')
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: CircleAvatar(
                                  radius: 11,
                                  backgroundColor: done > 0 ? favoriteColor : Colors.grey.shade300,
                                  child: const Icon(
                                    Icons.pets,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.check_circle_outline),
                              color: (!canCompleteTasks || expired || (type == 'höchstens' && done >= limit))
                                  ? Colors.grey
                                  : done > 0
                                      ? Colors.green
                                      : Colors.amber,
                              iconSize: 32,
                              tooltip: !canCompleteTasks
                                  ? 'Du darfst Aufgaben nicht selbst abschließen.'
                                  : expired
                                      ? 'Frist abgelaufen'
                                      : (type == 'höchstens' && done >= limit)
                                          ? 'Limit erreicht'
                                          : 'Abschließen',
                              onPressed: () {
                                if (!canCompleteTasks) {
                                  showDialog(
                                    context: ctx,
                                    builder: (_) => AlertDialog(
                                      title: const Text('Nicht erlaubt'),
                                      content: const Text('Du darfst Aufgaben nicht selbst abschließen. Dein Herrchen hat das deaktiviert.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('OK'),
                                        ),
                                      ],
                                    ),
                                  );
                                  return;
                                }
                                if (expired || (type == 'höchstens' && done >= limit)) {
                                  return;
                                }
                                _confirmAndCompleteTask(doc, date);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
