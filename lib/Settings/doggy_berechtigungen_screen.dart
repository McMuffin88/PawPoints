import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mydoggys_screen.dart';

class DoggyBerechtigungenScreen extends StatefulWidget {
  const DoggyBerechtigungenScreen({super.key});

  @override
  State<DoggyBerechtigungenScreen> createState() => _DoggyBerechtigungenScreenState();
}

class _DoggyBerechtigungenScreenState extends State<DoggyBerechtigungenScreen> {
  List<Map<String, dynamic>> _doggys = [];
  String _inviteCode = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDoggyAssignments();
  }

  Future<void> _loadDoggyAssignments() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = userDoc.data();

    if (data != null && data.containsKey('inviteCode')) {
      _inviteCode = data['inviteCode'];
    }

    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('assignedHerrchen')
        .get();

    _doggys = querySnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

    setState(() {
      _isLoading = false;
    });
  }

  Widget _buildNoDoggysView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pets, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Du bist aktuell mit keinem Doggy verbunden.',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Bitte verwende deinen Einladungs- oder QR Code, um die Verbindung herzustellen.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyDoggysScreen(inviteCode: _inviteCode, doggys: [])

                  ),
                );
              },
              icon: const Icon(Icons.qr_code),
              label: const Text('Zu Meine Doggys'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoggyList() {
    return ListView.builder(
      itemCount: _doggys.length,
      itemBuilder: (context, index) {
        final doggy = _doggys[index];
        return ListTile(
          leading: const Icon(Icons.person),
          title: Text(doggy['name'] ?? 'Unbenannt'),
          subtitle: Text('Status: ${doggy['status'] ?? 'aktiv'}'),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Berechtigungen'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _doggys.isEmpty
              ? _buildNoDoggysView()
              : _buildDoggyList(),
    );
  }
}
