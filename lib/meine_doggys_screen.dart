import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MeineDoggysScreen extends StatefulWidget {
  const MeineDoggysScreen({super.key});

  @override
  State<MeineDoggysScreen> createState() => _MeineDoggysScreenState();
}

class _MeineDoggysScreenState extends State<MeineDoggysScreen> {
  List<Map<String, dynamic>> _doggys = [];
  String _inviteCode = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
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
      _doggys = List<Map<String, dynamic>>.from(jsonDecode(doggyList));
    }

    _inviteCode = prefs.getString('invite_code') ?? _generateInviteCode();
    if (!prefs.containsKey('invite_code')) {
      await prefs.setString('invite_code', _inviteCode);
    }

    setState(() {});
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now().millisecondsSinceEpoch;
    return List.generate(8, (i) => chars[(now + i) % chars.length]).join();
  }

  Future<void> _removeDoggy(int index) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _doggys.removeAt(index));
    await prefs.setString('doggys', jsonEncode(_doggys));
  }

  void _copyInviteCode() {
    Clipboard.setData(ClipboardData(text: _inviteCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Einladungscode kopiert')),
    );
  }

  Widget _buildDoggyList() {
    return ListView.builder(
      itemCount: _doggys.length,
      itemBuilder: (context, index) {
        final doggy = _doggys[index];
        final name = doggy['name'] ?? 'Doggy';
        final imagePath = doggy['image'];
        Widget avatar = const CircleAvatar(child: Icon(Icons.pets));
        if (imagePath != null) {
          if (kIsWeb) {
            avatar = CircleAvatar(backgroundImage: NetworkImage(imagePath));
          } else if (File(imagePath).existsSync()) {
            avatar = CircleAvatar(backgroundImage: FileImage(File(imagePath)));
          }
        }

        return ListTile(
          leading: avatar,
          title: Text(name),
          trailing: IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _removeDoggy(index),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meine Doggys')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(child: _buildDoggyList()),
            const SizedBox(height: 16),
            Text('Einladungscode: $_inviteCode', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _copyInviteCode,
              icon: const Icon(Icons.copy),
              label: const Text('In Zwischenablage kopieren'),
            ),
          ],
        ),
      ),
    );
  }
}
