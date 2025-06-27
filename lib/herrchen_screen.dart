import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pawpoints/Drawer_herrchen/Herrchen_drawer.dart';

class HerrchenScreen extends StatefulWidget {
  // 1. Parameter für den Callback bleibt erhalten
  final VoidCallback? onProfileTap;

  const HerrchenScreen({super.key, this.onProfileTap});

  @override
  State<HerrchenScreen> createState() => _HerrchenScreenState();
}

class _HerrchenScreenState extends State<HerrchenScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Die alten State-Variablen für Tasks und Doggys wurden entfernt.
  String? _profileImageUrl;
  
  // Die Liste für Doggys wird hier leer initialisiert, 
  // da sie noch an den Drawer übergeben wird. Später kann sie aus Firestore geladen werden.
  final List<Map<String, dynamic>> _doggys = [];

  @override
  void initState() {
    super.initState();
    // Die Aufrufe zum Laden von lokalen Daten wurden entfernt.
    _loadProfileImageFromFirestore();
  }

  // Die Funktion zum Laden des Profilbilds bleibt, da sie Firestore verwendet.
  Future<void> _loadProfileImageFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data();
    if (data != null && data['profileImageUrl'] != null) {
      if (mounted) {
        setState(() {
          _profileImageUrl = data['profileImageUrl'];
        });
      }
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
      drawer: buildHerrchenDrawer(context, _loadProfileImageFromFirestore, _doggys),
      appBar: AppBar(
        title: const Text('Meine Aufgaben'),
        actions: [
          GestureDetector(
            onTap: widget.onProfileTap,
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _buildProfileIcon(),
            ),
          ),
        ],
      ),
      // Der Body zeigt nun einen Platzhalter, da die lokale Ladelogik entfernt wurde.
      body: const Center(
        child: Text(
          'Aufgaben werden hier angezeigt.',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}