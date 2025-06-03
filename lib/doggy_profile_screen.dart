import 'package:flutter/material.dart';
import 'doggy_screen.dart';

class DoggyProfileScreen extends StatefulWidget {
  final String inviteCode;

  const DoggyProfileScreen({super.key, required this.inviteCode});

  @override
  State<DoggyProfileScreen> createState() => _DoggyProfileScreenState();
}

class _DoggyProfileScreenState extends State<DoggyProfileScreen> {
  final _nameController = TextEditingController();

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    // Später kannst du hier Daten speichern (Profil + Einladungscode)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DoggyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doggy-Profil erstellen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Du trittst dem Herrchen mit Code ${widget.inviteCode} bei.'),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Dein Name'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Weiter zu deinen Aufgaben'),
            ),
          ],
        ),
      ),
    );
  }
}
