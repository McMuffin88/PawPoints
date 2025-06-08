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
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.email, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              Text(
                "Hallo $username,\nbitte bestätige deine E-Mail-Adresse:",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                email,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
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
      ),
    );
  }
}