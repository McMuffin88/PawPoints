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
      await prefs.setString('herrchen_displayname', _displayNameController.text);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const InviteDoggyScreen()),
      );
    }
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
              const Text('Dein öffentlich sichtbarer Name', style: TextStyle(fontSize: 18)),
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
