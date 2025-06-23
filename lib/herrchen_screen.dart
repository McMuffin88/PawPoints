import 'dart:convert';
import 'package:flutter/material.dart';
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
    );
  }
}
