import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DoggyScreen extends StatefulWidget {
  const DoggyScreen({super.key});

  @override
  State<DoggyScreen> createState() => _DoggyScreenState();
}

class _DoggyScreenState extends State<DoggyScreen> {
  List<Map<String, dynamic>> _tasks = [];
  int _points = 0;

  @override
  void initState() {
    super.initState();
    _loadTasks();
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

  void _completeTask(int index) async {
    final int earnedPoints = _tasks[index]['points'] ?? 0;

    setState(() {
      _points += earnedPoints;
      _tasks.removeAt(index);
    });

    await _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doggy-Aufgaben'),
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
            child: _tasks.isEmpty
                ? const Center(child: Text('Keine offenen Aufgaben.'))
                : ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (_, index) {
                      final task = _tasks[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.pets),
                          title: Text(task['title']),
                          subtitle: Text(
                            'Punkte: ${task['points']} – Fällig: ${task['due'].toString().split("T")[0]}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            onPressed: () => _completeTask(index),
                            tooltip: 'Aufgabe erledigt',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
