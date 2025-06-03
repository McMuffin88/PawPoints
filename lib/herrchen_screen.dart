import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'doggy_screen.dart';

class HerrchenScreen extends StatefulWidget {
  const HerrchenScreen({super.key});

  @override
  State<HerrchenScreen> createState() => _HerrchenScreenState();
}

class _HerrchenScreenState extends State<HerrchenScreen> {
  final List<Map<String, dynamic>> _tasks = [];
  final _titleController = TextEditingController();
  final _pointsController = TextEditingController();
  DateTime? _selectedDate;

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_tasks);
    await prefs.setString('doggy_tasks', jsonString);
  }

  void _addTask() async {
    if (_titleController.text.isEmpty ||
        _pointsController.text.isEmpty ||
        _selectedDate == null) return;

    setState(() {
      _tasks.add({
        'title': _titleController.text,
        'points': int.tryParse(_pointsController.text) ?? 0,
        'due': _selectedDate!.toIso8601String(),
      });
      _titleController.clear();
      _pointsController.clear();
      _selectedDate = null;
    });

    await _saveTasks();
    Navigator.of(context).pop();
  }

  void _openAddTaskDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Neue Aufgabe erstellen'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Aufgabentitel'),
                ),
                TextField(
                  controller: _pointsController,
                  decoration: const InputDecoration(labelText: 'Punkte'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Fälligkeitsdatum wählen'),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = date;
                      });
                    }
                  },
                ),
                if (_selectedDate != null)
                  Text('Fällig am: ${_selectedDate!.toLocal().toString().split(' ')[0]}'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: _addTask,
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );
  }

  void _deleteTask(int index) async {
    setState(() {
      _tasks.removeAt(index);
    });
    await _saveTasks();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Herrchen-Bereich'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Neue Aufgabe',
            onPressed: _openAddTaskDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _tasks.isEmpty
                ? const Center(child: Text('Noch keine Aufgaben erstellt.'))
                : ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (_, index) {
                      final task = _tasks[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.assignment),
                          title: Text(task['title']),
                          subtitle: Text(
                            'Punkte: ${task['points']} – Fällig: ${task['due'].toString().split("T")[0]}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteTask(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DoggyScreen()),
                );
              },
              icon: const Icon(Icons.pets),
              label: const Text('Zum Doggy-Bereich wechseln'),
            ),
          ),
        ],
      ),
    );
  }
}
