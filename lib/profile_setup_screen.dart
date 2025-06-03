import 'package:flutter/material.dart';
import 'invite_doggy_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Später kannst du hier Profilinformationen speichern
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
      ), // 👈 Das war bei dir offen!
    );
  }
}
