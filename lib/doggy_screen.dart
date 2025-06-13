// Vollständige und bereinigte doggy_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'Settings/doggy_profile_screen.dart';
import 'doggy_drawer.dart';

class DoggyScreen extends StatefulWidget {
  const DoggyScreen({super.key});

  @override
  State<DoggyScreen> createState() => _DoggyScreenState();
}

class _DoggyScreenState extends State<DoggyScreen> {
  String? _webImagePath;
  String _doggyName = 'Doggy';
  int _points = 0;

  @override
  void initState() {
    super.initState();
    _loadDoggyFirebaseData();
  }

  Future<void> _loadDoggyFirebaseData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data == null) return;

    setState(() {
      _doggyName = data['name'] ?? 'Doggy';
      _points = data['points'] ?? 0;
      final imageUrl = data['profileImageUrl'];
      if (imageUrl != null) {
        _webImagePath = imageUrl;
      }
    });
  }

  Widget _buildProfileIcon() {
    if (_webImagePath != null && _webImagePath!.startsWith('http')) {
      return CircleAvatar(backgroundImage: NetworkImage(_webImagePath!));
    } else {
      return const CircleAvatar(child: Icon(Icons.account_circle));
    }
  }

  Future<void> _confirmAndCompleteTask(DocumentSnapshot taskDoc, DateTime instanceDate) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aufgabe abschließen?'),
        content: const Text('Bist du sicher, dass du diese Aufgabe erledigt hast?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ja')),
        ],
      ),
    );

    if (confirmed == true) {
      await _completeTask(taskDoc, instanceDate);
    }
  }

  Future<void> _completeTask(DocumentSnapshot taskDoc, DateTime instanceDate) async {
    final task = taskDoc.data() as Map<String, dynamic>;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = taskDoc.reference;
    final int earnedPoints = task['points'] ?? 0;

    await docRef.collection('completions').add({
      'timestamp': Timestamp.now(),
      'instanceDate': instanceDate.toIso8601String(),
    });

    setState(() {
      _points += earnedPoints;
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'points': FieldValue.increment(earnedPoints)});
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final dateFormat = DateFormat.yMMMMd('de_DE');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doggy-Aufgaben'),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: _buildProfileIcon(),
              tooltip: 'Menü',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: buildDoggyDrawer(context),
      body: user == null
          ? const Center(child: Text('Nicht angemeldet.'))
          : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('tasks')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Keine offenen Aufgaben.'));
          }

          final taskDocs = snapshot.data!.docs;
          final now = DateTime.now();
          final startOfDay = DateTime(now.year, now.month, now.day);
          final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

          final List<Map<String, dynamic>> instances = [];
          final List<DocumentReference> toDelete = [];

          for (final doc in taskDocs) {
            final task = doc.data() as Map<String, dynamic>;
            final repeat = task['repeat'];
            final due = DateTime.tryParse(task['due'] ?? '');
            if (due == null) continue;

            if (repeat == null) {
              instances.add({ 'doc': doc, 'date': due });
            } else {
              DateTime current = due;
              while (current.isBefore(endOfDay.add(const Duration(days: 30)))) {
                final isTooOld = current.isBefore(now.subtract(const Duration(days: 15)));
                if (isTooOld) {
                  toDelete.add(doc.reference);
                  break;
                }
                if (current.isAfter(startOfDay.subtract(const Duration(days: 1)))) {
                  instances.add({ 'doc': doc, 'date': current });
                }
                if (repeat == 'weekly') current = current.add(const Duration(days: 7));
                else if (repeat == 'monthly') current = DateTime(current.year, current.month + 1, current.day);
                else if (repeat.startsWith('every_')) {
                  final days = int.tryParse(repeat.replaceFirst('every_', '')) ?? 1;
                  current = current.add(Duration(days: days));
                } else {
                  break;
                }
              }
            }
          }

          instances.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

// Alte Aufgaben löschen
          for (final ref in toDelete) {
            FirebaseFirestore.instance.runTransaction((txn) async {
              txn.delete(ref);
            });
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stars, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Text(
                      'Punkte: $_points',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: instances.length,
                  itemBuilder: (context, index) {
                    final doc = instances[index]['doc'] as DocumentSnapshot;
                    final instanceDate = instances[index]['date'] as DateTime;
                    final task = doc.data() as Map<String, dynamic>;

                    final dateFormatted = DateFormat('dd.MM.yyyy').format(instanceDate);
                    final repeat = task['repeat'];
                    final repeatText =
                    repeat == 'weekly' ? 'wöchentlich' :
                    repeat == 'monthly' ? 'monatlich' :
                    repeat?.startsWith('every_') == true ? 'alle ${repeat!.split('_')[1]} Tage' :
                    'einmalig';
                    final limit = int.tryParse(task['limitValue']?.toString() ?? '') ?? 0;
                    final type = task['frequencyLimit'];
                    final frequencyText = (type == 'mindestens')
                        ? 'Mindestens $limit×'
                        : (type == 'höchstens')
                        ? 'Höchstens $limit×'
                        : null;
                    final iconData = task['icon'] != null
                        ? IconData(task['icon'], fontFamily: task['iconFontFamily'], fontPackage: task['iconFontPackage'])
                        : Icons.pets;

                    return FutureBuilder<QuerySnapshot>(
                      future: doc.reference
                          .collection('completions')
                          .where('instanceDate', isEqualTo: instanceDate.toIso8601String())
                          .get(),
                      builder: (context, snap) {
                        final count = snap.data?.docs.length ?? 0;
                        final progress = (limit > 0) ? (count / limit).clamp(0.0, 1.0) : 0.0;
                        final isMaxReached = type == 'höchstens' && count >= limit;
                        final isExpired = instanceDate.isBefore(DateTime(now.year, now.month, now.day));

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.brown.shade100,
                              child: Icon(iconData, color: Colors.brown.shade800),
                            ),
                            title: Text(task['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Fällig: $dateFormatted – Typ: $repeatText${frequencyText != null ? ' – $frequencyText' : ''}'),
                                if (type != null && type != 'beliebig' && limit > 0) ...[
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: LinearProgressIndicator(value: progress),
                                  ),
                                  Text('Heute: $count/$limit×'),
                                  if (isExpired && count == 0)
                                    const Text('Frist abgelaufen', style: TextStyle(color: Colors.red)),
                                ],
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.check_circle_outline),
                              tooltip: 'Aufgabe erledigt',
                              onPressed: (isMaxReached || isExpired) ? null : () => _confirmAndCompleteTask(doc, instanceDate),
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
      ),
    );
  }
}
