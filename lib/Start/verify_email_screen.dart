import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'profile_setup_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String username;
  final String email;

  const VerifyEmailScreen({
    super.key,
    required this.username,
    required this.email,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _isChecking = false;
  bool _isSending = false;

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload(); // Status neu laden

      if (user != null && user.emailVerified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-Mail ist noch nicht bestätigt')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Überprüfen der E-Mail')),
      );
    } finally {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _isSending = true);

    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-Mail erneut gesendet')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fehler beim Senden der E-Mail')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('E-Mail bestätigen')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              Text(
                "Hallo ${widget.username},\nbitte bestätige deine E-Mail-Adresse:",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text(
                widget.email,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isChecking ? null : _checkVerification,
                child: _isChecking
                    ? const CircularProgressIndicator()
                    : const Text('Ich habe bestätigt'),
              ),
              TextButton(
                onPressed: _isSending ? null : _resendEmail,
                child: _isSending
                    ? const CircularProgressIndicator()
                    : const Text('E-Mail erneut senden'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
