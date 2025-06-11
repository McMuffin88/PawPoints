import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'verify_email_screen.dart';
import 'login_screen.dart';
import '../doggy_screen.dart';
import '../main.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final auth = FirebaseAuth.instance;

        // Registrierung durchführen
        await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        // Verifizierungs-Mail senden
        await auth.currentUser?.sendEmailVerification();

        // Lokale Speicherung
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('herrchen_email', _emailController.text);
        await prefs.setString('user_role', 'herrchen');

        // Weiterleitung zur Verifizierungsseite
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyEmailScreen(
              username: _usernameController.text,
              email: _emailController.text,
            ),
          ),
        );
      } on FirebaseAuthException catch (e) {
        String message = 'Unbekannter Fehler ist aufgetreten';

        if (e.code == 'email-already-in-use') {
          message = 'Diese E-Mail wird bereits verwendet';
        } else if (e.code == 'invalid-email') {
          message = 'Ungültige E-Mail-Adresse';
        } else if (e.code == 'weak-password') {
          message = 'Das Passwort ist zu schwach (min. 6 Zeichen)';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } finally {
        setState(() => _isLoading = false);
      }
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
        title: const Text('Herrchen Registrierung'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _goBackToStartup,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 20),
              Center(
                child: Image.asset(
                  'assets/logo.png',
                  height: 100,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.image_not_supported,
                        size: 60, color: Colors.grey);
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Erstelle dein Herrchen-Konto",
                style: TextStyle(fontSize: 20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Benutzername'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Bitte angeben' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'E-Mail'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value == null || !value.contains('@')
                    ? 'Gültige E-Mail eingeben'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Passwort'),
                obscureText: true,
                validator: (value) =>
                    value == null || value.length < 6
                        ? 'Mind. 6 Zeichen'
                        : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Registrieren'),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Schon ein Konto?"),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text("Jetzt einloggen"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DoggyScreen()),
                  );
                },
                child: const Text('Zum Doggy-Bereich (Test)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
