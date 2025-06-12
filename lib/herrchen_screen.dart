import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pawpoints/Herrchen_drawer.dart';

class HerrchenScreen extends StatefulWidget {
  const HerrchenScreen({super.key});

  @override
  State<HerrchenScreen> createState() => _HerrchenScreenState();
}

class _HerrchenScreenState extends State<HerrchenScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _doggys = [];
  String? _profileImageUrl;
  String _inviteCode = '';

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadProfileImageFromFirestore();
    _loadInviteCodeAndDoggys();
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

  Future<void> _loadInviteCodeAndDoggys() async {
    final prefs = await SharedPreferences.getInstance();
    final doggyList = prefs.getString('doggys');
    final inviteCode = prefs.getString('invite_code');
    if (doggyList != null) {
      setState(() {
        _doggys = List<Map<String, dynamic>>.from(jsonDecode(doggyList));
      });
    }
    if (inviteCode != null) {
      setState(() {
        _inviteCode = inviteCode;
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

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null && data['profileImageUrl'] != null) {
      setState(() {
        _profileImageUrl = data['profileImageUrl'];
      });
    }
  }

  Widget _buildProfileIcon() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(_profileImageUrl!),
        onBackgroundImageError: (_, __) {
          debugPrint('[WARN] Bild konnte nicht geladen werden.');
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
                            dialogSetState(() => selectedDate = picked);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    value: repeatType,
                    onChanged: (value) => dialogSetState(() => repeatType = value!),
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
                      if (days != null) repeat = 'every_$days';
                    }
                    final task = {
                      'title': title,
                      'points': points,
                      'due': selectedDate?.toIso8601String(),
                      'repeat': repeat,
                    };
                    setState(() => _tasks.add(task));
                    _saveTasks();
                    Navigator.pop(ctx);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: buildHerrchenDrawer(context, _loadProfileImageFromFirestore, _doggys),
      appBar: AppBar(
        title: const Text('Meine Aufgaben'),
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
      body: ListView.builder(
        itemCount: _tasks.length,
        itemBuilder: (_, index) {
          final task = _tasks[index];
          return ListTile(
            title: Text(task['title'] ?? 'Aufgabe'),
            subtitle: Text('Punkte: ${task['points'] ?? 0}'),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addTask,
        child: const Icon(Icons.add),
      ),
    );
  }
}