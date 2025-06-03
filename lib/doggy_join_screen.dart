import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // für StartupScreen
import 'doggy_profile_screen.dart'; // für Weiterleitung nach Codeeingabe

class DoggyJoinScreen extends StatefulWidget {
  const DoggyJoinScreen({super.key});

  @override
  State<DoggyJoinScreen> createState() => _DoggyJoinScreenState();
}

class _DoggyJoinScreenState extends State<DoggyJoinScreen> {
  final _codeController = TextEditingController();

  void _submit() {
    final code = _codeController.text.trim();

    // Dummyprüfung – später mit echtem Abgleich oder Firestore
    if (code.length == 8) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DoggyProfileScreen(inviteCode: code),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gültigen Einladungscode eingeben.')),
      );
    }
  }

  Future<void> _goBackToStartup() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_role');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const StartupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einladungscode eingeben'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackToStartup,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Einladungscode vom Herrchen eingeben:',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: 'Einladungscode'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Beitreten'),
            ),
          ],
        ),
      ),
    );
  }
}
