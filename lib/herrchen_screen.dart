import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'doggy_screen.dart';
import 'herrchen_profile_screen.dart';

class HerrchenScreen extends StatefulWidget {
  const HerrchenScreen({super.key});

  @override
  State<HerrchenScreen> createState() => _HerrchenScreenState();
}

class _HerrchenScreenState extends State<HerrchenScreen> {
  List<Map<String, dynamic>> _tasks = [];
  File? _profileImage;
  String? _webImagePath;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadProfileImage();
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

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('herrchen_image');

    if (imagePath != null) {
      if (kIsWeb) {
        setState(() {
          _webImagePath = imagePath;
        });
      } else if (File(imagePath).existsSync()) {
        setState(() {
          _profileImage = File(imagePath);
        });
      }
    }
  }

  Widget _buildProfileIcon() {
    if (kIsWeb && _webImagePath != null) {
      return CircleAvatar(backgroundImage: NetworkImage(_webImagePath!));
    } else if (_profileImage != null) {
      return CircleAvatar(backgroundImage: FileImage(_profileImage!));
    } else {
      return const CircleAvatar(child: Icon(Icons.account_circle));
    }
  }

  void _addTask() {
    showDialog(
      context: context,
      builder: (ctx) {
        final titleController = TextEditingController();
        final pointsController = TextEditingController();
        DateTime? selectedDate;

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
                              : 'Fällig: ${selectedDate!.day}.${selectedDate!.month}.${selectedDate!.year}',
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

                    if (title.isNotEmpty && selectedDate != null) {
                      setState(() {
                        _tasks.add({
                          'title': title,
                          'points': points,
                          'due': selectedDate!.toIso8601String(),
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
      appBar: AppBar(
        title: const Text('Herrchen Aufgabenübersicht'),
        actions: [
          IconButton(
            icon: _buildProfileIcon(),
            tooltip: 'Profil',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HerrchenProfileScreen()),
              );
              _loadProfileImage(); // Reload image after profile edit
            },
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
                          ? '${dueDate.day}.${dueDate.month}.${dueDate.year}'
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
