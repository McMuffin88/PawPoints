// Erweiterter HerrchenShopScreen mit Übersicht, Doggy-Auswahl, Punkteanzeige und Formular getrennt

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HerrchenShopScreen extends StatefulWidget {
  const HerrchenShopScreen({super.key});

  @override
  State<HerrchenShopScreen> createState() => _HerrchenShopScreenState();
}

class _HerrchenShopScreenState extends State<HerrchenShopScreen> {
  List<Map<String, dynamic>> _doggys = [];
  Map<String, int> _points = {};
  String? _selectedDoggy;
  List<Map<String, dynamic>> _rewards = [];
  bool _showForm = false;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _pointsController = TextEditingController();
  String _rewardDoggy = 'Alle';
  bool _active = true;
  bool _escalating = false;
  final _escalateEveryXController = TextEditingController();
  final _increaseByController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ensureDoggyDefaults().then((_) => _loadData());
  }

  Future<void> _ensureDoggyDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    final doggyList = prefs.getString('doggys');

    if (doggyList == null || jsonDecode(doggyList).isEmpty) {
      final defaultDoggys = [
        {
          'name': 'Bello',
          'image': null,
          'berechtigungen': {
            'aufgabenHinzufuegen': true,
            'aufgabenBearbeiten': false,
            'regelnBearbeiten': false,
            'notizenBearbeiten': false,
            'historieBearbeiten': false
          }
        },
        {
          'name': 'Luna',
          'image': null,
          'berechtigungen': {
            'aufgabenHinzufuegen': true,
            'aufgabenBearbeiten': true,
            'regelnBearbeiten': true,
            'notizenBearbeiten': true,
            'historieBearbeiten': true
          }
        },
      ];
      await prefs.setString('doggys', jsonEncode(defaultDoggys));
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final doggyList = prefs.getString('doggys');
    final rewardList = prefs.getString('shop_items');

    if (doggyList != null) {
      _doggys = List<Map<String, dynamic>>.from(jsonDecode(doggyList));
      if (_doggys.isNotEmpty) {
        _selectedDoggy = _doggys[0]['name'];
        for (final doggy in _doggys) {
          final p = prefs.getInt('points_${doggy['name']}') ?? 0;
          _points[doggy['name']] = p;
        }
      }
    }

    if (rewardList != null) {
      _rewards = List<Map<String, dynamic>>.from(jsonDecode(rewardList));
    }

    setState(() {});
  }

  Future<void> _saveRewards() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shop_items', jsonEncode(_rewards));
  }

  void _addReward() {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final points = int.tryParse(_pointsController.text.trim());

    if (title.isEmpty || points == null || _rewardDoggy.isEmpty) return;

    final reward = {
      'title': title,
      'description': desc,
      'points': points,
      'active': _active,
      'doggy': _rewardDoggy,
      'escalating': _escalating,
      'every_x': int.tryParse(_escalateEveryXController.text.trim()) ?? 0,
      'increase_by': int.tryParse(_increaseByController.text.trim()) ?? 0
    };

    setState(() {
      _rewards.add(reward);
      _titleController.clear();
      _descController.clear();
      _pointsController.clear();
      _escalating = false;
      _escalateEveryXController.clear();
      _increaseByController.clear();
      _rewardDoggy = 'Alle';
      _showForm = false;
    });
    _saveRewards();
  }

  void _toggleReward(int index) {
    setState(() => _rewards[index]['active'] = !_rewards[index]['active']);
    _saveRewards();
  }

  void _removeReward(int index) {
    setState(() => _rewards.removeAt(index));
    _saveRewards();
  }

  @override
  Widget build(BuildContext context) {
    final filteredRewards = _rewards.where((r) => r['doggy'] == _selectedDoggy || r['doggy'] == 'Alle').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Shop-Verwaltung')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_doggys.isNotEmpty)
              DropdownButton<String>(
                value: _selectedDoggy,
                onChanged: (value) => setState(() => _selectedDoggy = value),
                items: _doggys.map<DropdownMenuItem<String>>((d) => DropdownMenuItem<String>(value: d['name'], child: Text('${d['name']} (${_points[d['name']] ?? 0} Punkte)'))).toList(),
              ),
            const SizedBox(height: 12),
            if (!_showForm)
              ElevatedButton(
                onPressed: () => setState(() => _showForm = true),
                child: const Text('Neue Belohnung hinzufügen'),
              ),
            if (_showForm)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Titel')),
                  TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Beschreibung')),
                  TextField(controller: _pointsController, decoration: const InputDecoration(labelText: 'Kosten (Punkte)'), keyboardType: TextInputType.number),
                  DropdownButton<String>(
                    value: _rewardDoggy,
                    onChanged: (val) => setState(() => _rewardDoggy = val ?? 'Alle'),
                    items: [const DropdownMenuItem(value: 'Alle', child: Text('Alle')),
                      ..._doggys.map((d) => DropdownMenuItem(value: d['name'], child: Text(d['name'])))],
                  ),
                  Row(children: [const Text('Aktiv?'), Switch(value: _active, onChanged: (val) => setState(() => _active = val))]),
                  Row(
                    children: [
                      const Text('Steigend?'),
                      Switch(value: _escalating, onChanged: (val) => setState(() => _escalating = val)),
                      if (_escalating) ...[
                        Expanded(
                          child: TextField(
                            controller: _escalateEveryXController,
                            decoration: const InputDecoration(labelText: 'Jede X. Nutzung'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _increaseByController,
                            decoration: const InputDecoration(labelText: 'Erhöhung (Punkte)'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ]
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton(onPressed: _addReward, child: const Text('Speichern')),
                      const SizedBox(width: 12),
                      TextButton(onPressed: () => setState(() => _showForm = false), child: const Text('Abbrechen')),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            const Text('Belohnungen:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: filteredRewards.isEmpty
                  ? const Text('Keine Belohnungen gefunden.')
                  : ListView.builder(
                      itemCount: filteredRewards.length,
                      itemBuilder: (context, index) {
                        final reward = filteredRewards[index];
                        return ListTile(
                          title: Text(reward['title']),
                          subtitle: Text('${reward['description']}\nKosten: ${reward['points']} Punkte'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch(
                                value: reward['active'] ?? true,
                                onChanged: (_) => _toggleReward(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _removeReward(index),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
