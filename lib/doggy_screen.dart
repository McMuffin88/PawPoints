import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'doggy_profile_screen.dart';

class DoggyScreen extends StatefulWidget {
  const DoggyScreen({super.key});

  @override
  State<DoggyScreen> createState() => _DoggyScreenState();
}

class _DoggyScreenState extends State<DoggyScreen> {
  List<Map<String, dynamic>> _tasks = [];
  int _points = 0;
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
    final savedPoints = prefs.getInt('doggy_points') ?? 0;

    if (tasksJson != null) {
      final List<dynamic> decoded = jsonDecode(tasksJson);
      setState(() {
        _tasks = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
        _points = savedPoints;
      });
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_tasks);
    await prefs.setString('doggy_tasks', jsonString);
    await prefs.setInt('doggy_points', _points);
  }

  Future<void> _loadProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('doggy_image');

    if (imagePath != null) {
      if (kIsWeb) {
        setState(() => _webImagePath = imagePath);
      } else if (File(imagePath).existsSync()) {
        setState(() => _profileImage = File(imagePath));
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

  void _completeTask(int index) async {
    final task = _tasks[index];
    final int earnedPoints = task['points'] ?? 0;
    final String? repeat = task['repeat'];
    DateTime? due = DateTime.tryParse(task['due'] ?? '');

    if (repeat != null && due != null) {
      if (repeat == 'weekly') {
        task['due'] = due.add(const Duration(days: 7)).toIso8601String();
      } else if (repeat == 'monthly') {
        task['due'] = DateTime(due.year, due.month + 1, due.day).toIso8601String();
      } else if (repeat.startsWith('every_')) {
        final days = int.tryParse(repeat.replaceFirst('every_', '')) ?? 0;
        task['due'] = due.add(Duration(days: days)).toIso8601String();
      } else {
        _tasks.removeAt(index);
      }
    } else {
      _tasks.removeAt(index);
    }

    setState(() {
      _points += earnedPoints;
    });

    await _saveTasks();
  }

  Map<String, List<Map<String, dynamic>>> _groupTasksByWeek() {
    final now = DateTime.now();
    final weekMap = <String, List<Map<String, dynamic>>>{};

    for (var i = 0; i <= 4; i++) {
      final start = now.add(Duration(days: i * 7 - now.weekday + 1));
      final end = start.add(const Duration(days: 6));

      final key = i == 0
          ? 'Diese Woche'
          : i == 1
              ? 'Nächste Woche'
              : 'In $i Wochen';

      weekMap[key] = [];

      for (var task in _tasks) {
        final due = DateTime.tryParse(task['due'] ?? '');
        final repeat = task['repeat'];
        if (due == null) continue;

        if (repeat == null) {
          // einmalige Aufgabe
          if (due.isAfter(start.subtract(const Duration(seconds: 1))) && due.isBefore(end.add(const Duration(days: 1)))) {
            weekMap[key]!.add(task);
          }
        } else {
          DateTime next = due;
          while (next.isBefore(end)) {
            if (next.isAfter(start.subtract(const Duration(seconds: 1))) && next.isBefore(end.add(const Duration(days: 1)))) {
              final clone = Map<String, dynamic>.from(task);
              clone['due'] = next.toIso8601String();
              weekMap[key]!.add(clone);
            }

            if (repeat == 'weekly') {
              next = next.add(const Duration(days: 7));
            } else if (repeat == 'monthly') {
              next = DateTime(next.year, next.month + 1, next.day);
            } else if (repeat.startsWith('every_')) {
              final days = int.tryParse(repeat.replaceFirst('every_', '')) ?? 0;
              next = next.add(Duration(days: days));
            } else {
              break;
            }
          }
        }
      }
    }

    return weekMap;
  }

  @override
  Widget build(BuildContext context) {
    final groupedTasks = _groupTasksByWeek();
    final dateFormat = DateFormat.yMMMMd('de_DE');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doggy-Aufgaben'),
        actions: [
          IconButton(
            icon: _buildProfileIcon(),
            tooltip: 'Profil',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DoggyProfileScreen(inviteCode: 'dummy')),
              );
              _loadProfileImage();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.brown.shade100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars, color: Colors.brown),
                const SizedBox(width: 8),
                Text('Punkte: $_points', style: const TextStyle(fontSize: 18)),
              ],
            ),
          ),
          Expanded(
            child: groupedTasks.entries.every((e) => e.value.isEmpty)
                ? const Center(child: Text('Keine offenen Aufgaben.'))
                : ListView(
                    children: groupedTasks.entries.map((entry) {
                      if (entry.value.isEmpty) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Text(entry.key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          ...entry.value.map((task) {
                            final index = _tasks.indexWhere((t) => t['title'] == task['title'] && t['due'] == task['due']);
                            final dueDate = DateTime.tryParse(task['due'] ?? '');
                            final dueFormatted = dueDate != null ? dateFormat.format(dueDate) : '–';
                            final repeatText = task['repeat'] == null
                                ? 'Einmalig'
                                : task['repeat'] == 'weekly'
                                    ? 'Wöchentlich'
                                    : task['repeat'] == 'monthly'
                                        ? 'Monatlich'
                                        : task['repeat'].toString().startsWith('every_')
                                            ? 'Alle ${task['repeat'].toString().split('_')[1]} Tage'
                                            : 'Einmalig';

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: const Icon(Icons.pets),
                                title: Text(task['title'] ?? ''),
                                subtitle: Text('Punkte: ${task['points']} – Fällig: $dueFormatted\nTyp: $repeatText'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.check_circle_outline),
                                  onPressed: index != -1 ? () => _completeTask(index) : null,
                                  tooltip: 'Aufgabe erledigt',
                                ),
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
