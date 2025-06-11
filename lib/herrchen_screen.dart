import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'doggy_screen.dart';
import 'herrchen_drawer.dart';

class HerrchenScreen extends StatefulWidget {
  const HerrchenScreen({super.key});

  @override
  State<HerrchenScreen> createState() => _HerrchenScreenState();
}

class _HerrchenScreenState extends State<HerrchenScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _tasks = [];
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadProfileImageFromFirestore();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString('doggy_tasks');
    if (tasksJson != null) {
      final List<dynamic> decoded = jsonDecode(tasksJson);
      setState(() {
        _tasks = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_tasks);
    await prefs.setString('doggy_tasks', jsonString);
  }

  Future<void> _loadProfileImageFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data != null && data['profileImageUrl'] != null) {
      setState(() {
        _profileImageUrl = data['profileImageUrl'];
      });
      print('[DEBUG] Geladene Bild-URL: $_profileImageUrl');
    }
  }

  Widget _buildProfileIcon() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(_profileImageUrl!),
        onBackgroundImageError: (_, __) {
          print('[WARN] Bild konnte nicht geladen werden.');
        },
      );
    } else {
      return const CircleAvatar(
        radius: 20,
        child: Icon(Icons.account_circle),
      );
    }
  }

  void _addTask() {
    showDialog(
      context: context,
      builder: (ctx) {
        final titleController = TextEditingController();
        final pointsController = TextEditingController();
        final repeatDaysController = TextEditingController();
        DateTime? selectedDate;
        String repeatType = 'einmalig';

        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text('Neue Aufgabe'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Titel'),
                  ),
                  TextField(
                    controller: pointsController,
                    decoration: const InputDecoration(labelText: 'Punkte'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedDate == null
                              ? 'Kein Datum gewählt'
                              : 'Fällig: ${DateFormat('dd.MM.yyyy').format(selectedDate!)}',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            locale: const Locale('de', 'DE'),
                          );
                          if (picked != null) {
                            dialogSetState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    value: repeatType,
                    onChanged: (value) {
                      dialogSetState(() {
                        repeatType = value!;
                      });
                    },
                    items: const [
                      DropdownMenuItem(value: 'einmalig', child: Text('Einmalig')),
                      DropdownMenuItem(value: 'weekly', child: Text('Wöchentlich')),
                      DropdownMenuItem(value: 'monthly', child: Text('Monatlich')),
                      DropdownMenuItem(value: 'every_x', child: Text('Alle X Tage')),
                    ],
                  ),
                  if (repeatType == 'every_x')
                    TextField(
                      controller: repeatDaysController,
                      decoration: const InputDecoration(labelText: 'Alle wie viele Tage?'),
                      keyboardType: TextInputType.number,
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final title = titleController.text.trim();
                    final points = int.tryParse(pointsController.text) ?? 0;
                    String? repeat;
                    if (repeatType == 'weekly') repeat = 'weekly';
                    if (repeatType == 'monthly') repeat = 'monthly';
                    if (repeatType == 'every_x') {
                      final days = int.tryParse(repeatDaysController.text);
                      if (days != null && days > 0) {
                        repeat = 'every_$days';
                      }
                    }

                    if (title.isNotEmpty && selectedDate != null) {
                      setState(() {
                        _tasks.add({
                          'title': title,
                          'points': points,
                          'due': selectedDate!.toIso8601String(),
                          if (repeat != null) 'repeat': repeat
                        });
                      });
                      _saveTasks();
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Hinzufügen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _goToDoggyScreen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', 'doggy');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DoggyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: buildHerrchenDrawer(context, _loadProfileImageFromFirestore),
      appBar: AppBar(
        title: const Text('Herrchen Aufgabenübersicht'),
        actions: [
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _buildProfileIcon(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          const Text('Doggy bekommt diese Aufgaben:', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Expanded(
            child: _tasks.isEmpty
                ? const Center(child: Text('Noch keine Aufgaben hinzugefügt.'))
                : ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (_, index) {
                      final task = _tasks[index];
                      final dueDate = DateTime.tryParse(task['due'] ?? '');
                      final dueFormatted = dueDate != null
                          ? DateFormat('dd.MM.yyyy').format(dueDate)
                          : task['due'].toString();

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.task),
                          title: Text(task['title']),
                          subtitle: Text('Punkte: ${task['points']} – Fällig: $dueFormatted'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              setState(() {
                                _tasks.removeAt(index);
                              });
                              _saveTasks();
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _goToDoggyScreen,
            icon: const Icon(Icons.pets),
            label: const Text('Zum Doggy-Bereich'),
          ),
          const SizedBox(height: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        child: const Icon(Icons.add),
        tooltip: 'Aufgabe hinzufügen',
      ),
    );
  }
}
