import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'invite_doggy_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();

      final displayName = _displayNameController.text.trim();
      await prefs.setString('herrchen_displayname', displayName);

      // Einladungscode nur erzeugen, wenn er noch nicht existiert
      String? code = prefs.getString('invite_code');
      if (code == null || code.isEmpty) {
        code = _generateInviteCode();
        await prefs.setString('invite_code', code);
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const InviteDoggyScreen()),
      );
    }
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now().millisecondsSinceEpoch;
    return List.generate(8, (i) => chars[(now + i) % chars.length]).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil erstellen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text(
                'Dein öffentlich sichtbarer Name',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Profilname',
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Bitte gib einen Namen ein' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Weiter'),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
