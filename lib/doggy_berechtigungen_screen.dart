import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DoggyBerechtigungenScreen extends StatefulWidget {
  const DoggyBerechtigungenScreen({super.key});

  @override
  State<DoggyBerechtigungenScreen> createState() => _DoggyBerechtigungenScreenState();
}

class _DoggyBerechtigungenScreenState extends State<DoggyBerechtigungenScreen> {
  List<Map<String, dynamic>> _doggys = [];

  @override
  void initState() {
    super.initState();
    _loadDoggys();
  }

  Future<void> _loadDoggys() async {
    final prefs = await SharedPreferences.getInstance();
    final doggyList = prefs.getString('doggys');

    if (doggyList == null) {
      _doggys = [
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
      await prefs.setString('doggys', jsonEncode(_doggys));
    } else {
      try {
        final decoded = jsonDecode(doggyList);
        if (decoded is List) {
          _doggys = decoded.whereType<Map<String, dynamic>>().toList();
        }
      } catch (e) {
        debugPrint('Fehler beim Parsen von doggys: $e');
      }
    }

    setState(() {});
  }

  Future<void> _savePermissions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('doggys', jsonEncode(_doggys));
  }

  Widget _buildDoggyPermissions() {
    return ListView.builder(
      itemCount: _doggys.length,
      itemBuilder: (context, index) {
        final doggy = _doggys[index];
        final name = doggy['name'] ?? 'Doggy';
        final image = doggy['image'];
        final raw = doggy['berechtigungen'];
        final permissions = raw is Map<String, dynamic> ? raw : {};

        Widget avatar = const CircleAvatar(child: Icon(Icons.pets));
        if (image != null) {
          if (kIsWeb) {
            avatar = CircleAvatar(backgroundImage: NetworkImage(image));
          } else if (File(image).existsSync()) {
            avatar = CircleAvatar(backgroundImage: FileImage(File(image)));
          }
        }

        return Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [avatar, const SizedBox(width: 12), Text(name, style: const TextStyle(fontSize: 18))]),
                const SizedBox(height: 8),
                ...[
                  {'key': 'aufgabenHinzufuegen', 'label': 'Aufgaben, Belohnungen und Strafen hinzufügen'},
                  {'key': 'aufgabenBearbeiten', 'label': 'Aufgaben, Belohnungen und Strafen bearbeiten/löschen'},
                  {'key': 'regelnBearbeiten', 'label': 'Regeln bearbeiten'},
                  {'key': 'notizenBearbeiten', 'label': 'Notizen bearbeiten'},
                  {'key': 'historieBearbeiten', 'label': 'Aufgabenhistorie bearbeiten'},
                ].map((perm) => SwitchListTile(
                      title: Text(perm['label']!),
                      value: permissions[perm['key']] ?? false,
                      onChanged: (val) {
                        setState(() => _doggys[index]['berechtigungen'][perm['key']] = val);
                        _savePermissions();
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Berechtigungen')),
      body: _doggys.isEmpty
          ? const Center(child: Text('Keine Doggys vorhanden.'))
          : _buildDoggyPermissions(),
    );
  }
}
