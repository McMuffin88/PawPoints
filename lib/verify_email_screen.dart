import 'package:flutter/material.dart';
import 'profile_setup_screen.dart';

class VerifyEmailScreen extends StatelessWidget {
  final String username;
  final String email;

  const VerifyEmailScreen({
    super.key,
    required this.username,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E-Mail bestätigen')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Bestätige deine E-Mail-Adresse:", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(email),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
                );
              },
              child: const Text('E-Mail als bestätigt markieren'),
            ),
          ],
        ),
      ),
    );
  }
}
